 //
//  CDTDatastore.m
//  CloudantSync
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTDatastore.h"
#import "CDTDocumentRevision.h"
#import "CDTDatastoreManager.h"
#import "CDTDocumentBody.h"
#import "CDTMutableDocumentRevision.h"

#import "TD_Database.h"
#import "TD_View.h"
#import "TD_Body.h"
#import "TD_Database+Insertion.h"
#import "TDInternal.h"
#import "TDMisc.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"


NSString* const CDTDatastoreChangeNotification = @"CDTDatastoreChangeNotification";


@interface CDTDatastore ()

- (void) TDdbChanged:(NSNotification*)n;
-(BOOL) validateBodyDictionary:(NSDictionary *)body error:(NSError * __autoreleasing *)error;

@end

@implementation CDTDatastore

@synthesize database = _database;

+(NSString*)versionString
{
    return @"0.1.0";
}


-(id)initWithDatabase:(TD_Database*)database
{
    self = [super init];
    if (self) {
        _database = database;
        if (![_database open]) {
            return nil;
        }
        
        NSString *dir = [[database path] stringByDeletingLastPathComponent];
        NSString *name = [database name];
        _extensionsDir = [dir stringByAppendingPathComponent: [NSString stringWithFormat:@"%@_extensions", name]];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(TDdbChanged:)
                                                     name: TD_DatabaseChangeNotification
                                                   object: _database];
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark Properties

-(TD_Database *)database {
    if (![self ensureDatabaseOpen]) {
        return nil;
    }
    return _database;
}

#pragma mark Observer methods

/*
 * Notified that a document has been created/modified/deleted in the
 * database we're wrapping. Wrap it up into a notification containing
 * CDT* classes and re-notify.
 *
 * All this wrapping is to prevent TD* types escaping.
 */
- (void) TDdbChanged:(NSNotification*)n {

    // Notification structure:

    /** NSNotification posted when a document is updated.
     UserInfo keys: 
      - @"rev": the new TD_Revision,
      - @"source": NSURL of remote db pulled from,
      - @"winner": new winning TD_Revision, _if_ it changed (often same as rev). 
    */

//    LogTo(CDTReplicatorLog, @"CDTReplicator: dbChanged");

    NSDictionary *nUserInfo = n.userInfo;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

    if (nil != nUserInfo[@"rev"]) {
        userInfo[@"rev"] = [[CDTDocumentRevision alloc]
                            initWithTDRevision:nUserInfo[@"rev"]];
    }

    if (nil != nUserInfo[@"winner"]) {
        userInfo[@"winner"] = [[CDTDocumentRevision alloc]
                            initWithTDRevision:nUserInfo[@"rev"]];
    }

    if (nil != nUserInfo[@"source"]) {
        userInfo[@"winner"] = nUserInfo[@"source"];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:CDTDatastoreChangeNotification
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark Datastore implementation

-(NSUInteger)documentCount {
    if (![self ensureDatabaseOpen]) {
        return -1;
    }
    return self.database.documentCount;
}

- (NSString*)name {
    return self.database.name;
}

-(CDTDocumentRevision *) createDocumentWithId:(NSString*)docId
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error
{
    if (![self validateBody:body error:error]) {
        return nil;
    }
    
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }


    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:NO];
    revision.body = body.td_body;

    TDStatus status;
    TD_Revision *new = [self.database putRevision:revision
                                   prevRevisionID:nil
                                    allowConflict:NO
                                           status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}


-(CDTDocumentRevision *) createDocumentWithBody:(CDTDocumentBody*)body
                                          error:(NSError * __autoreleasing *)error
{
    if (![self validateBody:body error:error]) {
        return nil;
    }

    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }

    TDStatus status;
    TD_Revision *new = [self.database putRevision:[body TD_RevisionValue]
                                   prevRevisionID:nil
                                    allowConflict:NO
                                           status:&status];

    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}


-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                     error:(NSError * __autoreleasing *)error
{
    return [self getDocumentWithId:docId rev:nil error: error];
}


-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                       rev:(NSString*)revId
                                     error:(NSError * __autoreleasing *)error
{
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }

    TDStatus status;
    TD_Revision *rev = [self.database getDocumentWithID:docId
                                             revisionID:revId
                                                options:0
                                                 status:&status];
    if (TDStatusIsError(status)) {
        if (error) {
            *error = TDStatusToNSError(status, nil);
        }
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:rev];
}

-(NSArray*) getAllDocuments
{
    if (![self ensureDatabaseOpen]) {
        return nil;
    }

    NSArray *result = [NSArray array];
    TDContentOptions contentOptions = kTDIncludeLocalSeq;
    struct TDQueryOptions query = {
        .limit = (unsigned int)self.database.documentCount,
        .inclusiveEnd = YES,
        .skip = 0,
        .descending = NO,
        .includeDocs = YES,
        .content = contentOptions
    };

    // This method must loop to get around the fact that conflicted documents
    // contribute more than one row in the query -getDocsWithIDs:options: uses,
    // so in the face of conflicted documents, the initial query above will
    // only return the winning revisions of a subset of the documents.
    BOOL done = NO;
    do {

        NSMutableArray *batch = [NSMutableArray array];

        NSDictionary *dictResults = [self.database getDocsWithIDs:nil options:&query];

        for (NSDictionary *row in dictResults[@"rows"]) {
            NSString *docId = row[@"id"];
            NSString *revId = row[@"value"][@"rev"];

            TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                                 revID:revId
                                                               deleted:NO];
            revision.body = [[TD_Body alloc] initWithProperties:row[@"doc"]];
            revision.sequence = [row[@"doc"][@"_local_seq"] longLongValue];

            CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:revision];
            [batch addObject:ob];
        }
        
        result = [result arrayByAddingObjectsFromArray:batch];

        done = ((NSArray*)dictResults[@"rows"]).count == 0;

        query.skip = query.skip + query.limit;

    } while (!done);

    return result;
}

-(NSArray*) getAllDocumentsOffset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                       descending:(BOOL)descending
{
    struct TDQueryOptions query = {
        .limit = (unsigned)limit,
        .inclusiveEnd = YES,
        .skip = (unsigned)offset,
        .descending = descending,
        .includeDocs = YES
    };
    return [self allDocsQuery:nil options:&query];
}


-(NSArray*) getDocumentsWithIds:(NSArray*)docIds
{
    struct TDQueryOptions query = {
        .limit = UINT_MAX,
        .inclusiveEnd = YES,
        .includeDocs = YES
    };
    return [self allDocsQuery:docIds options:&query];
}

/* docIds can be null for getting all documents */
-(NSArray*)allDocsQuery:(NSArray*)docIds options:(TDQueryOptions*)queryOptions
{
    if (![self ensureDatabaseOpen]) {
        return nil;
    }

    NSMutableArray *result = [NSMutableArray array];

    NSDictionary *dictResults = [self.database getDocsWithIDs:docIds options:queryOptions];

    for (NSDictionary *row in dictResults[@"rows"]) {
        //            NSLog(@"%@", row);
        NSString *docId = row[@"id"];
        NSString *revId = row[@"value"][@"rev"];

        // deleted field only present in deleted documents, but to be safe we use
        // the fact that (BOOL)[nil -boolValue] is false
        BOOL deleted = (BOOL)[row[@"value"][@"deleted"] boolValue];

        TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                             revID:revId
                                                           deleted:deleted];

        // Deleted documents won't have a `doc` field
        if (!deleted) {
            revision.body = [[TD_Body alloc] initWithProperties:row[@"doc"]];
        }

        CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:revision];
        [result addObject:ob];
    }
    
    return result;
}


-(NSArray*) getRevisionHistory:(CDTDocumentRevision*)revision
{
    if (![self ensureDatabaseOpen]) {
        return nil;
    }

    NSMutableArray *result = [NSMutableArray array];

    // Array of TD_Revision
    NSArray *td_revs = [self.database getRevisionHistory:revision.td_rev];

    for (TD_Revision *td_rev in td_revs) {
        CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:td_rev];
        [result addObject:ob];
    }
    
    return result;
}



-(BOOL) validateBody:(CDTDocumentBody*)body
               error:(NSError * __autoreleasing *)error
{
    NSDictionary *bodyDict = body.td_body.asObject;
    return [self validateBodyDictionary:bodyDict error:error];
}

-(BOOL) validateBodyDictionary:(NSDictionary *)body error:(NSError * __autoreleasing *)error{
    // Check user hasn't provided _fields, which should be provided
    // as metadata in the CDTDocumentRevision object rather than
    // via _fields in the body dictionary.
    for (NSString *key in [body keyEnumerator]) {
        if ([key hasPrefix:@"_"]) {
            if (error) {
                NSInteger code = 400;
                NSString *reason = @"Bodies may not contain _ prefixed fields. "
                "Use CDTDocumentRevision properties.";
                NSString *description = [NSString stringWithFormat:@"%li %@", (long)code, reason];
                NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: reason,
                                           NSLocalizedDescriptionKey: description
                                           };
                *error = [NSError errorWithDomain:TDHTTPErrorDomain
                                             code:code
                                         userInfo:userInfo];
            }
            
            return NO;
        }
    }
    
    return YES;

    
}


-(CDTDocumentRevision *) updateDocumentWithId:(NSString*)docId
                                      prevRev:(NSString*)prevRev
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error
{
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }
    
    __block CDTDocumentRevision *result;
    
    [self.database.fmdbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        result = [self updateDocumentWithId:docId
                                    prevRev:prevRev
                                       body:body
                              inTransaction:db
                                   rollback:rollback
                                      error:error];
    }];
    
    if (result) {
        
        NSDictionary* userInfo = $dict({@"rev", result},
                                       {@"winner", result});
        [[NSNotificationCenter defaultCenter] postNotificationName:CDTDatastoreChangeNotification
                                                            object:self
                                                          userInfo:userInfo];
    }

    return result;
}

-(CDTDocumentRevision *) updateDocumentWithId:(NSString*)docId
                                      prevRev:(NSString*)prevRev
                                         body:(CDTDocumentBody*)body
                                inTransaction:(FMDatabase*)db
                                     rollback:(BOOL*)rollback
                                        error:(NSError * __autoreleasing *)error
{
    if (![self validateBody:body error:error]) {
        return nil;
    }
    
    return [self updateDocumentFromTDRevision:body.TD_RevisionValue
                                        docId:docId
                                      prevRev:prevRev
                                inTransaction:db
                                     rollback:rollback
                                        error:error];
    

}


-(CDTDocumentRevision*) deleteDocumentWithId:(NSString*)docId
                                         rev:(NSString*)rev
                                       error:(NSError * __autoreleasing *)error
{
    
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return NO;
    }

    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:YES];
    TDStatus status;
    TD_Revision *new = [self.database putRevision:revision
                                   prevRevisionID:rev
                                    allowConflict:NO
                                           status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}

-(NSString*) extensionDataFolder:(NSString*)extensionName
{
    return [NSString pathWithComponents:@[_extensionsDir, extensionName]];
}

#pragma mark Helper methods

-(BOOL)ensureDatabaseOpen
{
    return [_database open];
}

#pragma mark fromRevision API methods

-(CDTDocumentRevision*)createDocumentFromRevision:(CDTMutableDocumentRevision *)revision
                                            error:(NSError * __autoreleasing *)error
{
    //first lets check to see if we can save the document
    if(!revision.body){
        return nil;
    }
    
    //so the body is valid we need to create the document we are going to attempt to save I guess
    if (![self validateBodyDictionary:revision.body error:error]) {
        return nil;
    }
    
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }
    
    
    //convert CDTMutableDocument to TD_Revision
    
    //we know it shouldn't have a TD_revision behind it, since its a create
    
    TD_Revision *converted = [[TD_Revision alloc]initWithDocID:revision.docId
                                                         revID:nil
                                                       deleted:false];
    converted.body = [[TD_Body alloc]initWithProperties:revision.body];
    
    TDStatus status;
    TD_Revision *new = [self.database putRevision:converted
                                   prevRevisionID:nil
                                    allowConflict:NO
                                           status:&status];
    
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }
    
    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
    
}

-(CDTDocumentRevision*)updateDocumentFromRevision:(CDTMutableDocumentRevision *)revision
                                            error:(NSError * __autoreleasing *)error
{
    
    if(!revision.body) {
        TDStatus status = kTDStatusBadRequest;
        *error = TDStatusToNSError(status, nil);
        return nil;
    }
    
    if(![self validateBodyDictionary:revision.body error:error]) {
        return nil;
    }
    
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }
    
    __block CDTDocumentRevision *result;
    
    [self.database.fmdbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        result = [self updateDocumentFromTDRevision:revision.td_rev
                                              docId:revision.docId
                                            prevRev:revision.sourceRevId
                                      inTransaction:db
                                           rollback:rollback error:error];
    }];
    
    if (result) {
        
        NSDictionary* userInfo = $dict({@"rev", result},
                                       {@"winner", result});
        [[NSNotificationCenter defaultCenter] postNotificationName:CDTDatastoreChangeNotification
                                                            object:self
                                                          userInfo:userInfo];
    }
    
    return result;
}

-(CDTDocumentRevision *) updateDocumentFromTDRevision:(TD_Revision*)td_rev
                                                docId:(NSString*)docId
                                              prevRev:(NSString *) prevRev
                                        inTransaction:(FMDatabase *)db
                                             rollback:(BOOL*)rollback
                                                error:(NSError * __autoreleasing *)error
{

    
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }
    
    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:NO];
    revision.body = td_rev.body;
    
    TDStatus status;
    TD_Revision *new = [self.database putRevision:revision
                                   prevRevisionID:prevRev
                                    allowConflict:NO
                                           status:&status
                                         database:db];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        *rollback = YES;
        return nil;
    }
    
    // Copy over the existing attachments, as this API's contract
    // is that updating a document maintains attachments. putRevision:...
    // only carries over attachments in the _attachments dict of the
    // body, which we don't fill up as it'd be wasteful.
    if (prevRev != nil) {  // there is a previous revision to copy from
        
        // Three database calls here, but safer to use TouchDB's
        // functions for now.
        
        SInt64 docNumericId = [self.database getDocNumericID:docId
                                                    database:db];
        SequenceNumber fromSequence = [self.database getSequenceOfDocument:docNumericId
                                                                  revision:prevRev
                                                               onlyCurrent:NO
                                                                  database:db];
        TDStatus status = [self.database copyAttachmentsFromSequence:fromSequence
                                                          toSequence:new.sequence
                                                          inDatabase:db];
        
        if (TDStatusIsError(status)) {
            *error = TDStatusToNSError(status, nil);
            *rollback = YES;
            return nil;
        }
    }
    
    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}

-(CDTDocumentRevision*)deleteDocumentFromRevision:(CDTDocumentRevision *)revision
                                            error:(NSError * __autoreleasing *)error
{
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }

    TD_Revision *td_revision = [[TD_Revision alloc] initWithDocID:revision.docId
                                                         revID:nil
                                                       deleted:YES];
    TDStatus status;
    TD_Revision *new = [self.database putRevision:td_revision
                                   prevRevisionID:revision.revId
                                    allowConflict:NO
                                           status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }
    
    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
    
    
}


@end
