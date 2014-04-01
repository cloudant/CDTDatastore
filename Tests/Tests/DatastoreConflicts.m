//
//  DatastoreConflicts.m
//  CloudantSync
//
//  Created by Adam Cox on 2014/02/27.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <SenTestingKit/SenTestingKit.h>
#import <Foundation/Foundation.h>

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore+Conflicts.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"
#import "CDTConflictResolver.h"

#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "TDJSON.h"
#import "FMResultSet.h"
#import "TD_Database+Insertion.h"
#import "TD_Revision.h"

#import "TD_Body.h"
#import "CollectionUtils.h"
#import "DBQueryUtils.h"

@interface DatastoreConflicts : CloudantSyncTests
@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) DBQueryUtils *dbutil;
@end


//@interface MyBiggestRevResolver  : NSObject<CDTConflictResolver>
//@end
//@implementation MyBiggestRevResolver
//
//-(NSInteger)getRevPrefix:(NSString *)revString
//{
//    return [[revString componentsSeparatedByString:@"-"][0] integerValue];
//}
//
//-(CDTDocumentRevision *)resolve:(NSString*)docId
//                      conflicts:(NSArray*)conflicts
//{
//    NSInteger biggestRev = 0;
//    NSInteger biggestRevIndex = 0;
//    for(int i = 0; i < conflicts.count; i++){
//        
//        CDTDocumentRevision *aRev = conflicts[i];
//        //pick the biggest rev number.
//        if([self getRevPrefix:aRev.revId] > biggestRev)
//            biggestRevIndex = i;
//    }
//    
//    return conflicts[biggestRevIndex];
//}
//@end
//
//@interface CDTAnnihilator  : NSObject<CDTConflictResolver>
//@end
//@implementation CDTAnnihilator
//
//-(CDTDocumentRevision *)resolve:(NSString*)docId
//                      conflicts:(NSArray*)conflicts
//{
//    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
//                                                         revID:nil
//                                                       deleted:YES];
//    return [[CDTDocumentRevision alloc] initWithTDRevision:revision];
//}
//@end

@implementation DatastoreConflicts

- (void)setUp
{
    [super setUp];
    
    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"conflicttests" error:&error];
    self.dbutil = [[DBQueryUtils alloc] initWithDbPath:[self pathForDBName:self.datastore.name]];
    
    STAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.
    
    self.datastore = nil;
    
    [super tearDown];
}

-(void) addConflictingDocumentWithId:(NSString *)anId
                         toDatastore:(CDTDatastore*)datastore
{
    //creates the following document tree
    //
    //    ----- 2-c (seq 5, deleted = 1)
    //  /
    // 1-a (seq 1) --- 2-a (seq 2) --- 3-a (seq 3)
    //   \
    //     ---- 2-b (seq 4)

    STAssertNotNil(anId, @"ID string is nil");
    
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"foo1.a":@"bar1.a"}];
    CDTDocumentRevision *rev1;
    rev1 = [datastore createDocumentWithId:anId
                                      body:body
                                     error:&error];
    
    
    error = nil;
    body = [[CDTDocumentBody alloc] initWithDictionary:@{@"foo2.a":@"bar2.a"}];
    CDTDocumentRevision *rev2a = [datastore updateDocumentWithId:rev1.docId
                                                         prevRev:rev1.revId
                                                            body:body
                                                           error:&error];
    
    error = nil;
    body = [[CDTDocumentBody alloc] initWithDictionary:@{@"foo3.a":@"bar3.a"}];
    [datastore updateDocumentWithId:rev2a.docId
                            prevRev:rev2a.revId
                               body:body
                              error:&error];
    
    error = nil;
    TD_Body *tdbody = [[TD_Body alloc] initWithProperties:@{@"foo2.b":@"bar2.b"}];
    TD_Database *tdstore = datastore.database;
    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:rev1.docId
                                                         revID:nil
                                                       deleted:NO];
    revision.body = tdbody;
    
    TDStatus status;
    TD_Revision *td_rev = [tdstore putRevision:revision
                                prevRevisionID:rev1.revId
                                 allowConflict:YES
                                        status:&status];
    if (TDStatusIsError(status)) {
        error = TDStatusToNSError(status, nil);
    }
    STAssertNil(error, @"Error creating conflict %@", error);
    CDTDocumentRevision *rev2b = [[CDTDocumentRevision alloc] initWithTDRevision:td_rev];
    STAssertNotNil(rev2b, @"CDTDocumentRevision object was nil");
    
    error = nil;
    tdbody = [[TD_Body alloc] initWithProperties:@{@"foo2.c":@"bar2.c"}];
    revision = [[TD_Revision alloc] initWithDocID:rev1.docId
                                            revID:nil
                                          deleted:YES];
    revision.body = tdbody;
    
    td_rev = [tdstore putRevision:revision
                   prevRevisionID:rev1.revId
                    allowConflict:YES
                           status:&status];
    if (TDStatusIsError(status)) {
        error = TDStatusToNSError(status, nil);
    }
    STAssertNil(error, @"Error creating conflict %@", error);
    CDTDocumentRevision *rev2c = [[CDTDocumentRevision alloc] initWithTDRevision:td_rev];
    STAssertNotNil(rev2c, @"CDTDocumentRevision object was nil");
    
    TDStatus statusResults = [tdstore compact];
    STAssertTrue(statusResults == kTDStatusOK, @"TDStatusAsNSError: %@",
                 TDStatusToNSError( statusResults, nil));
    
}


- (CDTDocumentRevision*)addNonConflictingDocumentWithBody:(NSDictionary*)body
                                              toDatastore:(CDTDatastore*)datastore
{
    NSError *error;
    CDTDocumentBody *docBody = [[CDTDocumentBody alloc] initWithDictionary:body];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:docBody error:&error];
    
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(rev, @"CDTDocumentRevision object was nil");
    
    return rev;
}

-(void)testCreateConflict
{
    [self addConflictingDocumentWithId:@"doc0" toDatastore:self.datastore];
}

-(void)testFindAllConflicts
{
    [self addConflictingDocumentWithId:@"doc0" toDatastore:self.datastore];
    NSArray *revsArray = [self.datastore conflictsForDocumentId:@"doc0"];
    STAssertTrue(revsArray.count == 3, @"found %lu conflicts", (unsigned long)revsArray.count);
}


-(void)testCreateMultipleConflictingDocuments
{
    //add a non-conflicting document
    CDTDocumentRevision *rev = [self addNonConflictingDocumentWithBody:@{@"conflict":@"no way!"}
                                                           toDatastore:self.datastore];
    
    NSSet *setOfConflictedDocIds = [NSSet setWithArray:@[@"doc0", @"doc1", @"doc2", @"doc3"]];
    for (NSString *docId in setOfConflictedDocIds) {
        [self addConflictingDocumentWithId:docId toDatastore:self.datastore];
    }
    
    //add another non-conflicting document
    CDTDocumentRevision *rev2 = [self addNonConflictingDocumentWithBody:@{@"conflict":@"no way!"}
                                                            toDatastore:self.datastore];

    
    NSSet *foundConflictedDocIds = [NSSet setWithArray:[self.datastore getConflictedDocumentIds]];
    STAssertTrue([foundConflictedDocIds isEqualToSet:setOfConflictedDocIds],
                 @"foundSet: %@", foundConflictedDocIds);
    
    STAssertFalse([foundConflictedDocIds containsObject:rev.docId],
                  @"conflicts set (%@) contained non-conflicting doc %@",
                  foundConflictedDocIds, rev.docId );
    STAssertFalse([foundConflictedDocIds containsObject:rev2.docId],
                  @"conflicts set (%@) contained non-conflicting doc %@",
                  foundConflictedDocIds, rev2.docId );
    
}

-(void) testEnumerateConflicts
{
    //add a non-conflicting document
    [self addNonConflictingDocumentWithBody:@{@"conflict":@"no way!"} toDatastore:self.datastore];
    
    NSMutableSet *setOfConflictedDocIds = [[NSMutableSet alloc] init];
    for (unsigned int i = 0; i < 100; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc%i", i];
        [setOfConflictedDocIds addObject:docId];
        [self addConflictingDocumentWithId:docId toDatastore:self.datastore];
    }
    
    //add another non-conflicting document
    [self addNonConflictingDocumentWithBody:@{@"conflict":@"no way!"} toDatastore:self.datastore];
    
    NSSet *foundConflictedDocIds = [NSSet setWithArray:[self.datastore getConflictedDocumentIds]];

    STAssertTrue([foundConflictedDocIds isEqualToSet:setOfConflictedDocIds],
                 @"foundSet: %@", foundConflictedDocIds);
    
    //add another set of conflicted docs to test
    for (unsigned int i = 100; i < 200; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc%i", i];
        [setOfConflictedDocIds addObject:docId];
        [self addConflictingDocumentWithId:docId toDatastore:self.datastore];
    }
    
    foundConflictedDocIds = [NSSet setWithArray:[self.datastore getConflictedDocumentIds]];
    
    STAssertTrue([foundConflictedDocIds isEqualToSet:setOfConflictedDocIds],
                 @"foundSet: %@", foundConflictedDocIds);
}

//- (void) testResolveConflictWithBiggestRev
//{
//    //add a non-conflicting document
//    NSError *error;
//    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"conflict":@"no way!"}];
//    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:body error:&error];
//    STAssertNil(error, @"Error creating document");
//    STAssertNotNil(rev, @"CDTDocumentRevision object was nil");
//    
//    NSArray *myConflictDocs = @[@"doc0", @"doc1", @"doc3", @"doc4"];
//    for (NSString *adoc in myConflictDocs)
//        [self createConflictingDocument:adoc];
//    
//    //add another non-conflicting document
//    error = nil;
//    body = [[CDTDocumentBody alloc] initWithDictionary:@{@"conflict":@"no way!"}];
//    CDTDocumentRevision *rev2 = [self.datastore createDocumentWithBody:body error:&error];
//    STAssertNil(error, @"Error creating document");
//    STAssertNotNil(rev2, @"CDTDocumentRevision object was nil");
//
//    MyBiggestRevResolver *myResolver = [[MyBiggestRevResolver alloc] init];
//
//    [self.dbutil printDocsAndRevs];
//    
//    [self.datastore enumerateConflictsUsingBlock:^(NSString *documentId, NSUInteger idx, BOOL *stop) {
//        NSLog(@"%lu. %@", (unsigned long)idx, documentId);
//        NSError *error;
//        [self.datastore resolveConflictsForDocument:documentId resolver:myResolver error:&error];
//        STAssertNil(error, @"Error resolving document. %@", error);
//        
//        if(error)
//            *stop = YES;
//    }];
//    
//    //make sure there are no more conflicting documents
//    NSArray *conflictedDocs = [self.datastore getConflictedDocumentIds];
//    STAssertTrue(conflictedDocs.count == 0, @"Found %@ conflicted docs", conflictedDocs.count);
//    
//    //make sure that doc0, doc1, doc2 and doc3 all have the proper rev and content
//    //They should have rev prefixes of 4- and should have content of {foo3.a:bar3.a}
//    for(NSString *adocid in myConflictDocs){
//        NSLog(adocid);
//
//        error = nil;
//        rev = [self.datastore getDocumentWithId:adocid error:&error];
//        STAssertNil(error, @"Error getting document");
//        STAssertNotNil(rev, @"CDTDocumentRevision object was nil");
//        STAssertTrue([self getRevPrefix:rev.revId] == 4, @"Unexpected RevId prefix: %@", rev.revId);
//        STAssertEqualObjects([rev documentAsDictionary], @{@"foo3.a":@"foo3.b"},
//                             @"Unexpected document: %@", [rev documentAsDictionary]);
//    }
//}

//- (void) testResolveByDeletingAllConflicts
//{
//    
//}


@end
