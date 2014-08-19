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
#import "TDMisc.h"

#import "CDTDocumentRevision.h"
#import "CDTDocumentBody.h"
#import "CDTAttachment.h"

#include <CommonCrypto/CommonDigest.h>

@implementation CDTDatastore (Attachments)

#pragma mark SQL statements

const NSString *SQL_ATTACHMENTS_SELECT = 
    @"SELECT sequence, filename, key, type, encoding, length, encoded_length revpos "
    @"FROM attachments WHERE filename = :filename AND sequence = :sequence";

const NSString *SQL_ATTACHMENTS_SELECT_ALL = 
    @"SELECT sequence, filename, key, type, encoding, length, encoded_length revpos "
    @"FROM attachments WHERE sequence = :sequence";

const NSString *SQL_DELETE_ATTACHMENT_ROW = 
    @"DELETE FROM attachments WHERE filename = :filename AND sequence = :sequence";

const NSString *SQL_INSERT_ATTACHMENT_ROW = @"INSERT INTO attachments "
    @"(sequence, filename, key, type, encoding, length, encoded_length, revpos) "
    @"VALUES (:sequence, :filename, :key, :type, :encoding, :length, :encoded_length, :revpos)";

static NSString* const CDTAttachmentsErrorDomain = @"CDTAttachmentsErrorDomain";

#pragma mark Getting attachments

/**
 Returns the names of attachments for a document revision.

 @return NSArray of CDTAttachment
 */
-(NSArray*) attachmentsForRev:(CDTDocumentRevision*)rev
                        error:(NSError * __autoreleasing *)error;
{
    FMDatabaseQueue *db_queue = self.database.fmdbQueue;
    
    __block NSArray *attachments;
    
    __weak CDTDatastore *weakSelf = self;
    
    [db_queue inDatabase:^(FMDatabase *db) {
        
        CDTDatastore *strongSelf = weakSelf;
        attachments = [strongSelf attachmentsForRev:rev inTransaction:db error:error ];
        
    }];
    
    return attachments;
}

-(NSArray*) attachmentsForRev:(CDTDocumentRevision*)rev
                inTransaction:(FMDatabase *)db
                        error:(NSError * __autoreleasing *)error
{
    
    NSMutableArray *attachments = [NSMutableArray array];

    // Get all attachments for this revision using the revision's
    // sequence number
    
    NSDictionary *params = @{@"sequence": @(rev.sequence)};
    FMResultSet *r = [db executeQuery:[SQL_ATTACHMENTS_SELECT_ALL copy]
              withParameterDictionary:params];
    
    @try {
        while ([r next]) {
            
            CDTSavedAttachment *attachment = [self attachmentFromDbRow:r];
            
            if (attachment != nil) {
                [attachments addObject:attachment];
            } else {
                LogTo(CDTDatastore,
                      @"Error reading an attachment row for attachments on doc <%@, %@>"
                      @"Closed connection during read?",
                      rev.docId,
                      rev.revId);
            }
        }
    }
    @finally {
        [r close];
    }
    
    
    return attachments;
}

/**
 Returns attachment `name` for the revision.

 @return CDTAttachment or nil no attachment with that name.
 */
-(CDTAttachment*) attachmentNamed:(NSString*)name
                           forRev:(CDTDocumentRevision*)rev
                            error:(NSError * __autoreleasing *)error
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
        
        int nFound = 0;
        @try {
            // This query should return a single result
            while ([r next]) {
                attachment = [strongSelf attachmentFromDbRow:r];
                nFound++;
            }
        }
        @finally {
            [r close];
        }
        
        if (nFound < 1) {
            LogTo(CDTDatastore, 
                  @"Couldn't find attachment %@ on doc <%@, %@>",
                  name,
                  rev.docId,
                  rev.revId);
        }
        if (nFound > 1) {
            LogTo(CDTDatastore, 
                  @">1 attachment for %@ on doc <%@, %@>, indicates corrupted database",
                  name,
                  rev.docId,
                  rev.revId);
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
    
    NSString *type = [r stringForColumn:@"type"];
    NSInteger size = [r longForColumn:@"length"];
    NSInteger revpos = [r longForColumn:@"revpos"];
    TDAttachmentEncoding encoding = [r intForColumn:@"encoding"];
    CDTSavedAttachment *attachment = [[CDTSavedAttachment alloc] initWithPath:filePath
                                                                         name:name
                                                                         type:type
                                                                         size:size
                                                                       revpos:revpos
                                                                     sequence:sequence
                                                                          key:keyData
                                                                     encoding:encoding];
    
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
 
 @return New revision, or nil on error.
 */
-(CDTDocumentRevision*) updateAttachments:(NSArray*)attachments
                                   forRev:(CDTDocumentRevision*)rev
                                    error:(NSError * __autoreleasing *)error
{
    if ([attachments count] <= 0) {
        // nothing to do, return existing rev
        return rev;
    }
    
    // Attachments are downloaded into the blob store first so
    // we're not sitting in a db transaction when we are downloading
    // them.
    // If any attachments fail to download, we return nil to
    // indicate that we couldn't create a new revision. TouchDB's
    // -conpact function will tidy up old revs, attachments and
    // unused attachments for us (and a file could conceivably
    // be an attachment on more than one document as a given 
    // data blob is shared across all documents that use it
    // as an attachment).
    NSMutableArray *downloadedAttachments = [NSMutableArray array];
    for (CDTAttachment *attachment in attachments) {
        NSDictionary *attachmentData = [self streamAttachmentToBlobStore:attachment
                                                                   error:error];
        if (attachmentData != nil) {
            [downloadedAttachments addObject:attachmentData];
        } else {  // Error downloading the attachment, bail
            // error out variable set by -stream...
            LogTo(CDTDatastore, 
                  @"Error reading %@ from stream for doc <%@, %@>, rolling back",
                  attachment.name,
                  rev.docId,
                  rev.revId);
            return nil;
        }
    }
    
    // At present, we create a new rev, then update the attachments table.
    // This is fine as TouchDB dynamically generates the attachments
    // dictionary from the attachments table on request.
    
    __block CDTDocumentRevision *updated;
    
    [self.database.fmdbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        // The whole transaction fails if:
        //  - updating the document fails
        //  - adding any attachment to the attachments table fails
        // In this case, the db is left consistent.
        
        NSDictionary *doc = rev.documentAsDictionary;
        CDTDocumentBody *updatedBody = [[CDTDocumentBody alloc] initWithDictionary:doc];
        updated = [self updateDocumentWithId:rev.docId
                                     prevRev:rev.revId
                                        body:updatedBody
                               inTransaction:db
                                    rollback:rollback
                                       error:error];
        
        if (updated == nil) {
            LogTo(CDTDatastore, 
                  @"Error updating document ready for updating attachments <%@, %@>, rolling back",
                  rev.docId,
                  rev.revId);
            
            *rollback = YES;
            return;
        }
        
        BOOL success = YES;
        
        for (NSDictionary *attachmentData in downloadedAttachments) {
            success = success && [self addAttachment:attachmentData toRev:updated inDatabase:db];
            
            if (!success) { 
                CDTAttachment *a = attachmentData[@"attachment"];
                LogTo(CDTDatastore, 
                      @"Error adding attachment row to database for %@ for doc <%@, %@>",
                      a.name,
                      rev.docId,
                      rev.revId);
                break; 
            }
        }
        
        if (!success) {
            *rollback = YES;
            
            LogTo(CDTDatastore, 
                  @"Error adding attachment rows for doc <%@, %@>, rolling back",
                  rev.docId,
                  rev.revId);
            
            if (error) {
                NSString *description = NSLocalizedString(@"Problem updating attachments table.", 
                                                          nil);
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey: description};
                *error = [NSError errorWithDomain:CDTAttachmentsErrorDomain
                                             code:CDTAttachmentErrorSqlError
                                         userInfo:userInfo];
            }
        } else {
            *rollback = NO;
        }
    }];
    
    return updated;
}

/*
 Streams attachment data into a blob in the blob store.
 Returns nil if there was a problem, otherwise a dictionary
 with the sha and size of the file.
 */
-(NSDictionary*)streamAttachmentToBlobStore:(CDTAttachment*)attachment 
                                      error:(NSError * __autoreleasing *)error
{
    NSAssert(attachment != nil, @"Attachment object was nil");
    
    TDBlobKey outKey;
    
    NSData *attachmentContent = [attachment dataFromAttachmentContent];
    
    if (nil == attachmentContent) {
        Warn(@"CDTDatastore: attachment %@ had no data; failing.", attachment.name);
        
        if (error) {
            NSString *desc = NSLocalizedString(@"Attachment has no data.", 
                                               nil);
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: desc};
            *error = [NSError errorWithDomain:TDHTTPErrorDomain
                                         code:kTDStatusAttachmentStreamError
                                     userInfo:userInfo];
        }
        
        return nil;
    }
    
    BOOL success = [self.database.attachmentStore storeBlob:attachmentContent
                                                creatingKey:&outKey
                                                      error:error];
    
    if (!success) {
        // -storeBlob:creatingKey:error: will have filled in error
        
        Warn(@"CDTDatastore: Couldn't save attachment %@: %@", attachment.name, *error);
        return nil;
    }
    
    NSData* keyData = [NSData dataWithBytes:&outKey length:sizeof(TDBlobKey)];
    
    NSDictionary *attachmentData = @{@"attachment": attachment,
                                     @"keyData": keyData,
                                     @"fileLength": @(attachmentContent.length)};
    return attachmentData;
}

/*
 Add the row in the attachments table for a given attachment.
 The attachments dict should store the attachments CDTAttachment
 object, its length and its sha key.
 */
-(BOOL) addAttachment:(NSDictionary*)attachmentData 
                toRev:(CDTDocumentRevision*)revision
           inDatabase:(FMDatabase*)db
{
    if (attachmentData == nil) {
        return NO;
    }
    
    NSData *keyData = attachmentData[@"keyData"];
    NSNumber *fileLength = attachmentData[@"fileLength"];
    CDTAttachment *attachment = attachmentData[@"attachment"];
    
    __block BOOL success;
    
    //
    // Create appropriate rows in the attachments table
    //
    
    // Insert rows for the new attachment into the attachments database
    SequenceNumber sequence = revision.sequence;
    NSString *filename = attachment.name;
    NSString *type = attachment.type;
    TDAttachmentEncoding encoding = kTDAttachmentEncodingNone; // from a raw input stream
    unsigned generation = [TD_Revision generationFromRevID:revision.revId];
    
    NSDictionary *params;
    
    // delete any existing entry for this file and sequence combo
    params = @{@"filename": filename, @"sequence": @(sequence)};
    success = [db executeUpdate:[SQL_DELETE_ATTACHMENT_ROW copy] withParameterDictionary:params];
    
    if (!success) {
        return NO;
    }
    
    params = @{@"sequence": @(sequence),
               @"filename": filename,
               @"key": keyData,  // how TDDatabase+Attachments does it
               @"type": type,
               @"encoding": @(encoding),
               @"length": fileLength,
               @"encoded_length": fileLength,  // we don't zip, so same as length, see TDDatabase+Atts
               @"revpos": @(generation),
               };
    
    // insert new record
    success = [db executeUpdate:[SQL_INSERT_ATTACHMENT_ROW copy] withParameterDictionary:params];
    
    // We don't remove the blob from the store on !success because
    // it could be referenced from another attachment (as files are
    // only stored once per sha1 of file data).
    
    return success;
}

#pragma mark Deleting attachments

/**
 Remove attachments `names` from a document, creating a new revision.

 @param rev rev to update.
 @param names NSArray of NSStrings, each being an attachment name
 to remove
 @return New revision, or nil if we failed to remove attachments.
 */
-(CDTDocumentRevision*) removeAttachments:(NSArray*)attachmentNames
                                  fromRev:(CDTDocumentRevision*)rev
                                    error:(NSError * __autoreleasing *)error
{
    if ([attachmentNames count] <= 0) {
        // nothing to do, return existing rev
        return rev;
    }
    
    // At present, we create a new rev, then update the attachments table.
    // This is fine as TouchDB dynamically generates the attachments
    // dictionary from the attachments table on request.

    __block CDTDocumentRevision *updated;
    
    [self.database.fmdbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        // The whole transaction fails if:
        //  - updating the document fails
        //  - adding any attachment to the attachments table fails
        // In this case, the db is left consistent.
        
        NSDictionary *doc = rev.documentAsDictionary;
        CDTDocumentBody *updatedBody = [[CDTDocumentBody alloc] initWithDictionary:doc];
        updated = [self updateDocumentWithId:rev.docId
                                     prevRev:rev.revId
                                        body:updatedBody
                               inTransaction:db
                                    rollback:rollback
                                       error:error];
        
        if (updated == nil) {
            // error set by -updateDocumentWithId:...
            LogTo(CDTDatastore, 
                  @"Error updating document ready for removing attachments <%@, %@>, rolling back",
                  rev.docId,
                  rev.revId);
            *rollback = YES;
            return;
        }
        
        BOOL success = YES;
        
        for (NSString *attachmentName in attachmentNames) {
            // Delete attachment that will have been copied over when
            // the new rev was created.
            
            // We don't remove the blob from the store on !success because
            // it could be referenced from another attachment (as files are
            // only stored once per sha1 of file data).
            
            NSDictionary *params;
            
            // delete attachment row for this attachment
            params = @{@"filename": attachmentName, @"sequence": @(updated.sequence)};
            success = success && [db executeUpdate:[SQL_DELETE_ATTACHMENT_ROW copy] 
                           withParameterDictionary:params];
            
            // break and rollback the transaction on a single failure.
            if (!success) {
                LogTo(CDTDatastore, 
                      @"Unable to remove attachment %@ from doc <%@, %@>",
                      attachmentName,
                      rev.docId,
                      rev.revId);
                break; 
            }
        }
        
        if (!success) {
            *rollback = YES;
            
            if (error) {
                LogTo(CDTDatastore, 
                      @"Error removing attachments from <%@, %@>, rolling back",
                      rev.docId,
                      rev.revId);
                
                NSString *description = NSLocalizedString(@"Problem updating attachments table.", 
                                                          nil);
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey: description};
                *error = [NSError errorWithDomain:CDTAttachmentsErrorDomain
                                             code:CDTAttachmentErrorSqlError
                                         userInfo:userInfo];
            }
        } else {
            *rollback = NO;
        }
        
    }];
    
    return updated;
}

@end
