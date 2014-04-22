//
//  CDTDatastore+Attachments.m
//  
//
//  Created by Michael Rhodes on 24/03/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTDatastore+Attachments.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"

#import "TD_Database.h"
#import "TD_Database+Attachments.h"
#import "TDBlobStore.h"
#import "TDInternal.h"

#import "CDTDocumentRevision.h"
#import "CDTDocumentBody.h"
#import "CDTAttachment.h"

#include <CommonCrypto/CommonDigest.h>

@implementation CDTDatastore (Attachments)

#pragma mark SQL statements

const NSString *SQL_ATTACHMENTS_SELECT = @"SELECT sequence, filename, key, type, encoding, length, encoded_length revpos FROM attachments WHERE filename = :filename AND sequence = :sequence";

const NSString *SQL_ATTACHMENTS_SELECT_ALL = @"SELECT sequence, filename, key, type, encoding, length, encoded_length revpos FROM attachments WHERE sequence = :sequence";

const NSString *SQL_DELETE_ATTACHMENT_ROW = @"DELETE FROM attachments WHERE filename = :filename AND sequence = :sequence";

const NSString *SQL_INSERT_ATTACHMENT_ROW = @"INSERT INTO attachments (sequence, filename, key, type, encoding, length, encoded_length, revpos) VALUES (:sequence, :filename, :key, :type, :encoding, :length, :encoded_length, :revpos)";

#pragma mark Getting attachments

/**
 Returns the names of attachments for a document revision.

 @return NSArray of CDTAttachment
 */
-(NSArray*) attachmentsForRev:(CDTDocumentRevision*)rev;
{
    
    FMDatabaseQueue *db_queue = self.database.fmdbQueue;
    
    NSMutableArray *attachments = [NSMutableArray array];
    
    __weak CDTDatastore *weakSelf = self;
    
    [db_queue inDatabase:^(FMDatabase *db) {
        
        CDTDatastore *strongSelf = weakSelf;
        
        // Get all attachments for this revision using the revision's
        // sequence number
        
        NSDictionary *params = @{@"sequence": @(rev.sequence)};
        FMResultSet *r = [db executeQuery:[SQL_ATTACHMENTS_SELECT_ALL copy] 
                  withParameterDictionary:params];
        
        @try {
            while ([r next]) {
                
                CDTSavedAttachment *attachment = [strongSelf attachmentFromDbRow:r];
                
                if (attachment != nil) {                
                    [attachments addObject:attachment];
                }
            }
        }
        @finally {
            [r close];
        }
    }];
    
    return attachments;
}

/**
 Returns attachment `name` for the revision.

 @return CDTAttachment or nil no attachment with that name.
 */
-(CDTAttachment*) attachmentNamed:(NSString*)name
                           forRev:(CDTDocumentRevision*)rev
{
    // pretty simple stuff:
    // pull the row from the attachments table for this
    // name and seq, build the CDTAttachment
    
    FMDatabaseQueue *db_queue = self.database.fmdbQueue;
    
    __block CDTSavedAttachment *attachment;
    __weak CDTDatastore *weakSelf = self;
    
    [db_queue inDatabase:^(FMDatabase *db) {
        
        CDTDatastore *strongSelf = weakSelf;
        
        NSDictionary *params = @{@"filename": name, @"sequence": @(rev.sequence)};
        FMResultSet *r = [db executeQuery:[SQL_ATTACHMENTS_SELECT copy] 
                  withParameterDictionary:params];
        
        @try {
            // This query should return a single result
            while ([r next]) {
                attachment = [strongSelf attachmentFromDbRow:r];
            }
        }
        @finally {
            [r close];
        }
    }];
    
    return attachment;
}

-(CDTSavedAttachment*) attachmentFromDbRow:(FMResultSet*)r
{
    // SELECT sequence, filename, key, type, encoding, length, encoded_length revpos ...
    SequenceNumber sequence = [r longForColumn:@"sequence"];
    NSString *name = [r stringForColumn:@"filename"];
    
    // Validate key data (required to get to the file) before
    // we construct the attachment instance.
    NSData* keyData = [r dataNoCopyForColumn: @"key"];
    if (keyData.length != sizeof(TDBlobKey)) {
        Warn(@"%@: Attachment %lld.'%@' has bogus key size %u",
             self, sequence, name, (unsigned)keyData.length);
        //*outStatus = kTDStatusCorruptError;
        return nil;
    }
    
    NSString *filePath = [self.database.attachmentStore pathForKey: *(TDBlobKey*)keyData.bytes];
    
    CDTSavedAttachment *attachment = [[CDTSavedAttachment alloc] initWithFilePath:filePath];
    attachment.name = name;
    attachment.type = [r stringForColumn:@"type"];
    attachment.size = [r longForColumn:@"length"];
    attachment.revpos = [r longForColumn:@"revpos"];
    attachment.sequence = [r longForColumn:@"sequence"];
    attachment.key = keyData;
    
    return attachment;
}

#pragma mark Updating attachments

/**
 Set the content of attachments on a document, creating a
 new revision of the document.
 
 Existing attachments with the same name will be replaced,
 new attachments will be created, and attachments already
 existing on the document which are not included in
 `attachments` will remain as attachments on the document.
 
 @return New revision.
 */
-(CDTDocumentRevision*) updateAttachments:(NSArray*)attachments
                                   forRev:(CDTDocumentRevision*)rev
{
    if ([attachments count] <= 0) {
        // nothing to do, return existing rev
        return rev;
    }
    
    NSError *error;
    
    // At present, we create a new rev, then update the attachments behind
    // its back. This is fine at TouchDB dynamically generates the attachments
    // dictionary from the attachments table on request.
    // TODO put in a single transaction
    CDTDocumentBody *updatedBody = [[CDTDocumentBody alloc] initWithDictionary:rev.documentAsDictionary];
    CDTDocumentRevision *updated = [self updateDocumentWithId:rev.docId
                                                      prevRev:rev.revId
                                                         body:updatedBody
                                                        error:&error];
    
    for (CDTAttachment *attachment in attachments) {
        [self addAttachment:attachment rev:updated];
    }
    
    return updated;
}

-(bool) addAttachment:(CDTAttachment*)attachment rev:(CDTDocumentRevision*)revision
{
    // do it this way to only go thru inputstream once
    // * write to temp location using copyinputstreamtofile
    // * get sha1
    // * stick it into database
    // * move file using sha1 as name
    
    __block BOOL success;
    
    // Pull the file in from the attachment object into a temp dir
    NSString *path = [self pathForTemporaryFileWithPrefix:attachment.name];
    NSInputStream *is = [attachment getInputStream];
    [is open];
    NSInteger fileLength = [self writeStream:is toPath:path];
    [is close];
    
    success = (fileLength > 0);
    if (!success) {  // i.e., we couldn't read the stream
        // TODO Log
        return NO;
    }
    
    // Move the file from a temp file to the blob store
    // TODO we could do this more efficiently, without loading the file again
    NSData  *fileData = [NSData dataWithContentsOfFile:path];
    TDBlobKey outKey;
    success = [self.database.attachmentStore storeBlob:fileData creatingKey:&outKey];
    
    // TODO delete the file regardless as we don't need to keep it around
    NSLog(@"path to tmp attachment: %@", path);
    
    if (!success) {
        // TODO Log
        return NO;
    }
    
    // Insert rows for the new attachment into the attachments database
    SequenceNumber sequence = revision.sequence;
    NSString *filename = attachment.name;
    NSString *type = attachment.type;
    TDAttachmentEncoding encoding = kTDAttachmentEncodingNone; // from a raw input stream
    unsigned generation = [TD_Revision generationFromRevID:revision.revId];
        
    [self.database.fmdbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        // TODO Log failures
        
        NSDictionary *params;
        
        // delete any existing entry for this file and sequence combo
        params = @{@"filename": filename, @"sequence": @(sequence)};
        success = [db executeUpdate:[SQL_DELETE_ATTACHMENT_ROW copy] withParameterDictionary:params];
        
        if (!success) {
            *rollback = YES;
            return;
        }
        
        NSData* keyData = [NSData dataWithBytes:&outKey length: sizeof(TDBlobKey)];
        
        params = @{@"sequence": @(sequence),
                   @"filename": filename,
                   @"key": keyData,  // how TDDatabase+Attachments does it
                   @"type": type,
                   @"encoding": @(encoding),
                   @"length": @(fileLength),
                   @"encoded_length": @(fileLength),  // we don't zip, so same as length, see TDDatabase+Atts
                   @"revpos": @(generation),
                   };
        
        // insert new record
        success = [db executeUpdate:[SQL_INSERT_ATTACHMENT_ROW copy] withParameterDictionary:params];
        
        *rollback = !success;
    }];
    
    // We don't remove the blob from the store on !success because
    // it could be referenced from another attachment (as files are
    // only stored once per sha1 of file data).
    
    return success;
}

/**
 Write a stream to a file.
 
 @param is the input stream to read file content from
 @param outputPath file to write to. It will be overwritten.
 
 @return the number of bytes read from the input stream
 */
- (NSInteger) writeStream:(NSInputStream*)is toPath:(NSString*)outputPath {
    uint8_t buf[4096];
    int bufSize = 4096;
    NSInteger len, totalLength = 0;
    
    NSOutputStream *oStream = [[NSOutputStream alloc] initToFileAtPath:outputPath append:NO];
    [oStream open];
    
    while ([is hasBytesAvailable]) {
        if ([oStream hasSpaceAvailable]) {
            len = [is read:buf maxLength:bufSize];
            if (len > 0) {
                [oStream write:buf maxLength:len];
                totalLength += len;
            }
        }
    }
    
    [oStream close];
    
    return totalLength;
}

- (NSString *) pathForTemporaryFileWithPrefix:(NSString *)prefix
{
    NSString *  result;
    CFUUIDRef   uuid;
    CFStringRef uuidStr;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
    
    NSString *filename = [NSString stringWithFormat:@"%@-%@", prefix, uuidStr];
    result = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    assert(result != nil);
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

#pragma mark Deleting attachments

/**
 Remove attachments `names` from a document, creating a new revision.

 @param rev rev to update.
 @param names NSArray of NSStrings, each being an attachment name
 to remove
 @return New revision.
 */
-(CDTDocumentRevision*) removeAttachments:(NSArray*)attachmentNames
                                  fromRev:(CDTDocumentRevision*)rev
{
    if ([attachmentNames count] <= 0) {
        // nothing to do, return existing rev
        return rev;
    }
    
    NSError *error;
    
    // At present, we create a new rev, then update the attachments behind
    // its back. This is fine at TouchDB dynamically generates the attachments
    // dictionary from the attachments table on request.
    // TODO put in a single transaction
    CDTDocumentBody *updatedBody = [[CDTDocumentBody alloc] initWithDictionary:rev.documentAsDictionary];
    CDTDocumentRevision *updated = [self updateDocumentWithId:rev.docId
                                                      prevRev:rev.revId
                                                         body:updatedBody
                                                        error:&error];
    
    __block BOOL success = YES;
    
    [self.database.fmdbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSString *attachmentName in attachmentNames) {
            // Delete attachment that will have been copied over when
            // the new rev was created.
            
            // We don't remove the blob from the store on !success because
            // it could be referenced from another attachment (as files are
            // only stored once per sha1 of file data).
            
            // TODO Log failures
            
            NSDictionary *params;
            
            // delete any existing entry for this file and sequence combo
            params = @{@"filename": attachmentName, @"sequence": @(updated.sequence)};
            
            // insert new record
            success = success && [db executeUpdate:[SQL_DELETE_ATTACHMENT_ROW copy] withParameterDictionary:params];
            
            // break and rollback the transaction on a single failure.
            if (!success) { break; }
        }
        
        *rollback = !success;
        
    }];
    
    return updated;
}

@end
