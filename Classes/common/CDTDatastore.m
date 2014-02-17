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

#import "TD_Database.h"
#import "TD_View.h"
#import "TD_Body.h"
#import "TD_Database+Insertion.h"


NSString* const CDTDatastoreChangeNotification = @"CDTDatastoreChangeNotification";


@interface CDTDatastore ()

- (void) TDdbChanged:(NSNotification*)n;

@end

@implementation CDTDatastore

+(NSString*)versionString
{
    return @"0.1.0";
}


-(id)initWithDatabase:(TD_Database*)database
{
    self = [super init];
    if (self) {
        _database = database;
        NSString *dir = [[database path] stringByDeletingLastPathComponent];
        _extensionsDir = [dir stringByAppendingPathComponent: @"extensions"];

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
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:rev];
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

        TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                             revID:revId
                                                           deleted:NO];
        revision.body = [[TD_Body alloc] initWithProperties:row[@"doc"]];

        CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:revision];
        [result addObject:ob];
    }
    
    return result;
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

    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:NO];
    revision.body = body.td_body;

    TDStatus status;
    TD_Revision *new = [self.database putRevision:revision
                                   prevRevisionID:prevRev
                                    allowConflict:NO
                                           status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}


-(BOOL) deleteDocumentWithId:(NSString*)docId
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
    [self.database putRevision:revision
                prevRevisionID:rev
                 allowConflict:NO
                        status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return NO;
    }

    return YES;
}

-(NSString*) extensionDataFolder:(NSString*)extensionName
{
    return [NSString pathWithComponents:@[_extensionsDir, extensionName]];
}

#pragma mark Helper methods

-(BOOL)ensureDatabaseOpen
{
    return [self.database open];
}


@end
