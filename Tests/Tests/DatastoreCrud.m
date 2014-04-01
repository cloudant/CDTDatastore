//
//  DatastoreCrud.m
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
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
#import <MRDatabaseContentChecker.h>

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"
#import "TD_Revision.h"

#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "TDJSON.h"
#import "FMResultSet.h"

#import "TD_Body.h"
#import "CollectionUtils.h"
#import "TD_Database+Insertion.h"
#import "TDStatus.h"
#import "DBQueryUtils.h"

@interface DatastoreCrud : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) DBQueryUtils *dbutil;
@end


@implementation DatastoreCrud

- (void)setUp
{
    [super setUp];

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    self.dbutil =[[DBQueryUtils alloc] initWithDbPath:[self pathForDBName:self.datastore.name]];
    
    STAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.
    
    self.datastore = nil;
    self.dbutil = nil;
    
    [super tearDown];
}

#pragma mark - helper methods


-(CDTDocumentBody *)createNilDocument
{
    NSDictionary *myDoc = @{@"hello": [NSSet setWithArray:@[@"world"]]};
    
    //require that myDoc is not JSON serializable
    STAssertFalse([TDJSON isValidJSONObject:myDoc],
                  @"My Non-serializable dictionary turned out to be serializable!");
    
    //require that CDTDocumentBody fails
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:myDoc];
    STAssertNil(body, @"Able to instantiate CDTDocument Body with non-serializable NSDictionary");
    return body;
}

-(NSArray*)generateDocuments:(int)count
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSDictionary *dict = @{[NSString stringWithFormat:@"hello-%i", i]: @"world"};
        CDTDocumentBody *documentBody = [[CDTDocumentBody alloc] initWithDictionary:dict];
        [result addObject:documentBody];
    }
    return result;
}


#pragma mark - CREATE tests


-(void)testCreateOneDocumentSQLEntries
{
    NSError *error;
    NSString *key = @"hello";
    NSString *value = @"world";
    NSString *testDocId = @"document_id_for_CreateOneDocumentSQLEntries";
    
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.

    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key: value}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithId:testDocId
                                                              body:body
                                                             error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @1};
    
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    
    
    // now test the content of docs/revs
    MRDatabaseContentChecker *dc =[[MRDatabaseContentChecker alloc] init];
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSArray *expectedRows = @[
                                  @[@"docId"],
                                  @[testDocId]
                                  ];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
    
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSString *revId = @"1-1f7588ca02054efe626a6e440a431861";
        NSData *json = [TDJSON dataWithJSONObject:@{key: value} 
                                          options:0 
                                            error:nil];
        NSArray *expectedRows = @[
            @[@"doc_id", @"sequence", @"revid", @"current", @"deleted", @"json"],
            @[@(1),      @1,          revId,    @YES,       @NO,        json]
        ];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

-(void)testCannotCreateInvalidDocument
{
    [self createNilDocument];
}

-(void)testCannotInsertNil
{
    NSError *error;
    NSString *testDocId = @"document_id_for_cannotInsertNil";

    CDTDocumentBody *body = [self createNilDocument];
    STAssertNil(body, @"CDTDocumentBody was not nil");

    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentWithId:testDocId
                                                              body:body
                                                             error:&error];
    STAssertNotNil(error, @"No Error creating document!");
    STAssertTrue(error.code == 400, @"Error was not a 400. Found %ld", error.code);
    STAssertNil(ob, @"CDTDocumentRevision object was not nil");
    
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];

}

-(void)testCannotCreateNewDocWithoutUniqueID
{
    NSError *error;
    NSString *key = @"hello";
    NSString *value = @"world";
    NSString *testDocId = @"document_id_for_CannotCreateNewDocWithoutUniqueID";
        
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key: value}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithId:testDocId
                                                              body:body
                                                             error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    body = [[CDTDocumentBody alloc] initWithDictionary:@{key: value}];
    ob = [self.datastore createDocumentWithId:testDocId
                                         body:body
                                        error:&error];
    STAssertNotNil(error, @"Error was nil when creating second doc with same doc_id");
    STAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", error.code);
    STAssertNil(ob, @"CDTDocumentRevision object was not nil when creating second doc with same doc_id");
}

-(void)testAddDocument
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
}

-(void)testCreateDocumentWithId
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithId:@"document_id_for_test"
                                                              body:body
                                                             error:&error];
    
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    STAssertEqualObjects(@"document_id_for_test", ob.docId, @"Document ID was not as set in test");
    
    error = nil;
    NSString *docId = ob.docId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId error:&error];
    
    STAssertNil(error, @"Error retrieving document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    const NSUInteger expected_count = 1;
    STAssertEquals(ob.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(ob.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testCannotCreateConflict
{
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key1:value1}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNil(error, @"Error updating document");
    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    //now create a conflict
    error = nil;
    NSString *key3 = @"hi";
    NSString *value3 = @"adam";
    CDTDocumentBody *body3 = [[CDTDocumentBody alloc] initWithDictionary:@{key3:value3}];
    CDTDocumentRevision *ob3 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body3
                                                              error:&error];
    STAssertTrue(error.code == 409, @"Incorrect error code: %@", error);
    STAssertNil(ob3, @"CDTDocumentRevision object was not nil");
    
}

#pragma mark - READ tests

-(void)testGetDocument
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    NSString *docId = ob.docId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId error:&error];
    
    STAssertNil(error, @"Error retrieving document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    const NSUInteger expected_count = 1;
    STAssertEquals(ob.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(ob.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testGetDocumentWithIdAndRev
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    
    error = nil;
    NSString *docId = ob.docId;
    NSString *revId = ob.revId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId rev:revId error:&error];
    STAssertNil(error, @"Error retrieving document");
    
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    const NSUInteger expected_count = 1;
    STAssertEquals(ob.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(ob.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testGetDocumentsWithIds
{
    NSError *error;
    NSMutableArray *docIds = [NSMutableArray arrayWithCapacity:20];
    
    for (int i = 0; i < 200; i++) {
        error = nil;
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world", @"index": [NSNumber numberWithInt:i]}];
        CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
        STAssertNil(error, @"Error creating document");
        
        NSString *docId = ob.docId;
        [docIds addObject:docId];
    }
    
    NSArray *retrivedDocIds = @[docIds[5], docIds[7], docIds[12], docIds[170]];
    NSArray *obs = [self.datastore getDocumentsWithIds:retrivedDocIds];
    STAssertNotNil(obs, @"Error getting documents");
    
    int ob_index = 0;
    for (NSNumber *index in @[@5, @7, @12, @170]) {
        NSString *docId = [docIds objectAtIndex:[index intValue]];
        CDTDocumentRevision *retrieved = [obs objectAtIndex:ob_index];
        
        STAssertNotNil(retrieved, @"retrieved object was nil");
        STAssertEqualObjects(retrieved.docId, docId, @"Object retrieved from database has wrong docid");
        const NSUInteger expected_count = 2;
        STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 2 keys");
        STAssertEqualObjects(retrieved.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
        STAssertEqualObjects(retrieved.documentAsDictionary[@"index"], index, @"Object from database has wrong data");
        
        ob_index++;
    }
}

-(void)testGetNonExistingDocument
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    
    error = nil;
    NSString *docId = @"i_do_not_exist";
    NSString *revId = ob.revId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId rev:revId error:&error];
    STAssertNotNil(error, @"Error should not be nil.");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(retrieved, @"retrieved object was nil");
    
}



-(void)testGetCompactedDocumentRev
{
    [self.datastore documentCount]; //necessary to ensure the database is populated
    NSDictionary *initialRowCounts = [self.dbutil getAllTablesRowCount];
    
    NSArray *ids = @[@"compactrevtest_doc_1", @"compactrevtest_doc_2",
                     @"compactrevtest_doc_3", @"compactrevtest_doc_4"];
    NSError *error;
    //dictionary to store last json document and number of updates for each doc id
    NSMutableDictionary *lastDocForId = [[NSMutableDictionary alloc] init];

    for(id anid in ids){
        lastDocForId[anid] = [NSMutableDictionary dictionaryWithDictionary:@{@"numUpdates":[NSNumber numberWithUnsignedInt:0], @"json":@{}, @"lastrev":@""}];
    }
    
    int totalUpdates = 2014;
    CDTDocumentRevision *cdt_rev;
    for (int i = 0; i < totalUpdates; i++) {
        //generate docutment body for a random doc id.
        NSString* randomId = [ids objectAtIndex:arc4random_uniform((u_int32_t)ids.count)];
        NSDictionary *dict = @{@"hello":[NSString stringWithFormat:@"world-%i", i]};
        CDTDocumentBody *documentBody = [[CDTDocumentBody alloc] initWithDictionary:dict ];

        error = nil;
        if([lastDocForId[randomId][@"numUpdates"] intValue] == 0) {
            cdt_rev = [self.datastore createDocumentWithId:randomId
                                                      body:documentBody
                                                     error:&error];
            STAssertNil(error, @"Error creating document. %@", error);
            STAssertNotNil(cdt_rev, @"CDTDocumentRevision was nil");
        }
        else{
            cdt_rev = [self.datastore getDocumentWithId:randomId
                                                  error:&error];
            STAssertNil(error, @"Error getting document");
            STAssertNotNil(cdt_rev, @"retrieved CDTDocumentRevision was nil");
            error = nil;
            cdt_rev = [self.datastore updateDocumentWithId:randomId
                                                   prevRev:cdt_rev.revId
                                                      body:documentBody
                                                     error:&error];
            STAssertNil(error, @"Error updating document");
            STAssertNotNil(cdt_rev, @"updated CDTDocumentRevision was nil");
        }
        
        //update our dictionary that is recording the last "event" for each doc id
        unsigned int currentCount = [lastDocForId[randomId][@"numUpdates"] unsignedIntValue];
        lastDocForId[randomId][@"numUpdates"]  = [NSNumber numberWithUnsignedInt:currentCount + 1];
        lastDocForId[randomId][@"lastrev"] =  cdt_rev.revId;
        lastDocForId[randomId][@"json"] = dict;
        
        STAssertTrue([lastDocForId[randomId][@"numUpdates"] unsignedIntegerValue] == [TD_Revision generationFromRevID:cdt_rev.revId],
                       @"rev prefix value does not equal expected number of updates");
    }
    
    NSDictionary *modifiedCounts = @{@"docs":@4, @"revs":[NSNumber numberWithInt:totalUpdates]};
    [self.dbutil checkTableRowCount:initialRowCounts modifiedBy:modifiedCounts];
    
    //now compact and check that all old revs obtained via CDTDatastore contain empty JSON.
    //note: I have to #import "TD_Database+Insertion.h" in order to compact.
    TDStatus statusResults = [self.datastore.database compact];
    STAssertTrue([TDStatusToNSError( statusResults, nil) code] == 200,
                 @"TDStatusAsNSError: %@", TDStatusToNSError( statusResults, nil));
    
    //number of table rows shouldn't have changed by compaction as all tombstones should be present
    [self.dbutil checkTableRowCount:initialRowCounts modifiedBy:modifiedCounts];
    
    //check that the most recent revision for each document matches expectation
    for(NSString* aDocId in ids){
        error = nil;
        NSDictionary* lastRecordedJsonDoc = lastDocForId[aDocId][@"json"];
        NSString *lastRev = lastDocForId[aDocId][@"lastrev"];
        NSUInteger numUpdates = [lastDocForId[aDocId][@"numUpdates"] unsignedIntegerValue];
        if(numUpdates > 0){
            cdt_rev = [self.datastore getDocumentWithId:aDocId error:&error];
            STAssertNil(error, @"Error getting document");
            STAssertNotNil(cdt_rev, @"retrieved object was nil");
            STAssertEqualObjects(lastRev, cdt_rev.revId, @"Object retrieved from database has wrong revid");
            STAssertEqualObjects(cdt_rev.documentAsDictionary, lastRecordedJsonDoc, @"Object from database has wrong data");
            STAssertTrue(numUpdates == [TD_Revision generationFromRevID:cdt_rev.revId], @"rev prefix value does not equal expected number of updates");
        }
    }
    
    //check the database has empty JSON and correct revision tree
    for(id aDocId in ids){
        [self.dbutil.queue inDatabase:^(FMDatabase *db){
            //I changed doc_id to 'docnum' because I otherwise get confused.
            FMResultSet *result = [db executeQuery:@"select sequence, revs.doc_id as docnum, docs.docid as docid, revid, json, parent, deleted from revs, docs where revs.doc_id = docs.doc_id and docs.docid = (?) order by sequence", aDocId];
            
            NSInteger revPrefix = 0;
            int docNum = -1;
            bool foundJSON = NO;
            
            while([result next]){
                //NSLog(@"row: %@", [result resultDictionary]);
                STAssertEqualObjects([result stringForColumn:@"docid"], aDocId,
                                     @"Document ID mismatch: %@", [result stringForColumn:@"docid"]);
                
                NSString *revid = [result stringForColumn:@"revid"];
                STAssertTrue([TD_Revision generationFromRevID:revid] - 1 == revPrefix, @"revision out of order: Found Rev: %@ and previous prefix %@", revid, revPrefix);
                revPrefix = [TD_Revision generationFromRevID:revid];
                
                STAssertFalse([result boolForColumn:@"deleted"], @"deleted? %@", [result stringForColumn:@"deleted"]);
                
                //this should be the first row in the result
                if(docNum == -1){
                    docNum = [result intForColumn:@"docnum"]; //make sure docNum is always the same
                    STAssertEqualObjects([result objectForColumnName:@"parent"], [NSNull null], @"parent: %@", [result objectForColumnName:@"parent"]);
                }
                else{
                    STAssertTrue([result intForColumn:@"docnum"] == docNum, @"%@", [result stringForColumn:@"docnum"]);
                    STAssertTrue([result intForColumn:@"docnum"] <= ids.count, @"%@", [result stringForColumn:@"docnum"]);
                }
                
                //only the last rev should have valid JSON data
                //otherwise FMDB returns an empty NSData object.
                if([revid isEqualToString:lastDocForId[aDocId][@"lastrev"]]){
                    NSError *error;
                    NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                               options: TDJSONReadingMutableContainers
                                                                 error: &error];
                    STAssertTrue([jsonDoc isEqualToDictionary:lastDocForId[aDocId][@"json"]], @"Found: %@", jsonDoc);
                    if(jsonDoc)
                        foundJSON = YES;
                }
                else{
                    //This was slightly unexpected. When TD_Database deletes, the JSON becomes an empty NSData
                    //object. But when compacting, it sets it to null. See TD_Database+Insertion compact.
                    STAssertEqualObjects([result objectForColumnName:@"json"], [NSNull null],
                                         @"Expected revs.json to be empty NSData. Found %@", [result objectForColumnName:@"json"]);
                }
                
            }
            
            STAssertTrue(foundJSON, @"didn't find json");
            [result close];
        }];
    }
    
}

#pragma mark READ ALL tests

-(void)test_getAllDocumentsOffsetLimitDescending
{
    NSError *error;
    int objectCount = 100;
    NSArray *bodies = [self generateDocuments:objectCount];
    NSMutableArray *dbObjects = [NSMutableArray arrayWithCapacity:objectCount];
    for (int i = 0; i < objectCount; i++) {
        // Results will be ordered by docId, so give an orderable ID.
        error = nil;
        NSString *docId = [NSString stringWithFormat:@"hello-%010d", i];
        CDTDocumentRevision *ob = [self.datastore createDocumentWithId:docId body:bodies[i] error:&error];
        STAssertNil(error, @"Error creating document");
        [dbObjects addObject:ob];
    }
    //    NSArray* reversedObjects = [[dbObjects reverseObjectEnumerator] allObjects];
    
    // Test count and offsets for descending and ascending
    [self getAllDocuments_testCountAndOffset:objectCount expectedDbObjects:dbObjects descending:NO];
    //[self getAllDocuments_testCountAndOffset:objectCount expectedDbObjects:reversedObjects descending:YES];
}

-(void)assertIdAndRevisionAndShallowContentExpected:(CDTDocumentRevision *)expected actual:(CDTDocumentRevision *)actual
{
    STAssertEqualObjects([actual docId], [expected docId], @"docIDs don't match");
    STAssertEqualObjects([actual revId], [expected revId], @"revIDs don't match");
    
    NSDictionary *expectedDict = [expected documentAsDictionary];
    NSDictionary *actualDict = [actual documentAsDictionary];
    
    for (NSString *key in [expectedDict keyEnumerator]) {
        STAssertNotNil([actualDict objectForKey:key], @"Actual didn't contain key %s", key);
        STAssertEqualObjects([actualDict objectForKey:key], [expectedDict objectForKey:key], @"Actual value didn't match expected value");
    }
}

-(void)getAllDocuments_testCountAndOffset:(int)objectCount expectedDbObjects:(NSArray*)expectedDbObjects descending:(Boolean)descending
{
    
    int count;
    int offset = 0;
    NSArray *result;
    
    // Count
    count = 10;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:count
                                         offset:offset];
    
    count = 47;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:count
                                         offset:offset];
    
    count = objectCount;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:count
                                         offset:offset];
    
    count = objectCount * 12;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:objectCount
                                         offset:offset];
    
    
    // Offsets
    offset = 10; count = 10;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:count
                                         offset:offset];
    
    offset = 20; count = 30;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:count
                                         offset:offset];
    
    offset = objectCount - 3; count = 10;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:3
                                         offset:offset];
    
    offset = objectCount + 5; count = 10;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:count
                                        descending:descending];
    [self getAllDocuments_compareResultExpected:expectedDbObjects
                                         actual:result
                                          count:0
                                         offset:0];
    
    // Error cases
    //    try {
    //        offset = 0; count = -10;
    //        core.getAllDocuments(offset, count, descending);
    //        Assert.fail("IllegalArgumentException not thrown");
    //    } catch (IllegalArgumentException ex) {
    //        // All fine
    //    }
    //    try {
    //        offset = -10; count = 10;
    //        core.getAllDocuments(offset, count, descending);
    //        Assert.fail("IllegalArgumentException not thrown");
    //    } catch (IllegalArgumentException ex) {
    //        // All fine
    //    }
    //    try {
    //        offset = 50; count = -10;
    //        core.getAllDocuments(offset, count, descending);
    //        Assert.fail("IllegalArgumentException not thrown");
    //    } catch (IllegalArgumentException ex) {
    //        // All fine
    //    }
}

-(void)getAllDocuments_compareResultExpected:(NSArray*)expectedDbObjects actual:(NSArray*)result count:(int)count offset:(int)offset
{
    NSUInteger expected = (NSUInteger)count;
    STAssertEquals(result.count, expected, @"expectedDbObject count didn't match result count");
    for (int i = 0; i < result.count; i++) {
        CDTDocumentRevision *actual = result[i];
        CDTDocumentRevision *expected = expectedDbObjects[i + offset];
        [self assertIdAndRevisionAndShallowContentExpected:expected actual:actual];
    }
}


#pragma mark - UPDATE tests

-(void)testUpdateWithBadRev
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";
    
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key1:value1}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    NSString *badRev = @"2-abcdef1234567890abcdef9876543210";
    error = nil;
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];

    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:ob.docId
                                                            prevRev:badRev
                                                               body:body2
                                                              error:&error];
    STAssertNotNil(error, @"Error was nil");
    STAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", error.code);
    STAssertNil(ob2, @"CDTDocumentRevision object was not nil");
    error = nil;
    
    //expect the database to be unmodified
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];
    
    badRev = [ob.revId stringByAppendingString:@"a"];
    error = nil;
    body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    ob2 = [self.datastore updateDocumentWithId:ob.docId
                                       prevRev:badRev
                                          body:body2
                                         error:&error];
    STAssertNotNil(error, @"Error was nil");
    STAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", error.code);
    STAssertNil(ob2, @"CDTDocumentRevision object was not nil");
    error = nil;
    
    //expect the database to be unmodified
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];

    //now update the document with the proper ID
    //then try to update the document again with the rev 1-x.
    error = nil;
    body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    ob2 = [self.datastore updateDocumentWithId:ob.docId
                                       prevRev:ob.revId
                                          body:body2
                                         error:&error];
    
    STAssertNil(error, @"Error creating document. %@", error);
    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    NSDictionary *modifiedCount = @{@"revs": @1};  //expect just one additional entry in revs
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    
    initialRowCount = [self.dbutil getAllTablesRowCount];
    
    NSString *key3 = @"howdy";
    NSString *value3 = @"adam";
    error = nil;
    CDTDocumentBody *body3 = [[CDTDocumentBody alloc] initWithDictionary:@{key3:value3}];
    CDTDocumentRevision *ob3 = [self.datastore updateDocumentWithId:ob.docId
                                                            prevRev:ob.revId  //this is the bad revision
                                                               body:body3
                                                              error:&error];
    STAssertNotNil(error, @"No error when updating document with bad rev");
    STAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", error.code);
    STAssertNil(ob3, @"CDTDocumentRevision object was not nil after update with bad rev");
    
    //expect the database to be unmodified
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];

    
}

-(void)testUpdateBadDocId
{
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";
    
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key1:value1}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];

    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    error = nil;
    body = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:@"idonotexist"
                                                            prevRev:ob.revId
                                                               body:body
                                                              error:&error];
    
    STAssertNotNil(error, @"No error when updating document with bad id");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(ob2, @"CDTDocumentRevision object was not nil after update with bad rev");
    
    //expect the database to be unmodified
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];
    
}

-(void)testUpdatingSingleDocument
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";
    
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key1:value1}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    error = nil;
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNil(error, @"Error updating document");
    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    // Check new revision
    const NSUInteger expected_count = 1;
    CDTDocumentRevision *retrieved;
    error = nil;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    STAssertNil(error, @"Error getting document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[key2], value2, @"Object from database has wrong data");
    
    // Check we can get old revision
    error = nil;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
    STAssertNil(error, @"Error getting document using old rev");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[key1], value1, @"Object from database has wrong data");
    
    
    //now test the content of docs/revs tables explicitely.
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @2};
    [self.dbutil checkTableRowCount:initialRowCount 
                         modifiedBy:modifiedCount];

    MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
    NSNumber *expectedDoc_id = @1;
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        
        NSError *validationError;
        NSArray *expectedRows = @[
            @[@"doc_id",      @"docid"],
            @[expectedDoc_id, docId]
            ];
        STAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        
        NSString *revId1 = @"1-1f7588ca02054efe626a6e440a431861";
        NSData *json1 = [TDJSON dataWithJSONObject:@{key1: value1} 
                                          options:0 
                                             error:nil];
        
        NSString *revId2 = @"2-be2c05cd85b8468ce92b04e001b0e923";
        NSData *json2 = [TDJSON dataWithJSONObject:@{key2: value2} 
                                          options:0 
                                            error:nil];
        NSArray *expectedRows = @[
            @[@"doc_id",      @"sequence", @"revid", @"current", @"deleted", @"json"],
            @[expectedDoc_id, @1,          revId1,   @NO,        @NO,        json1],
            @[expectedDoc_id, @2,          revId2,   @YES,       @NO,        json2],
            ];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];

}

-(void)testUpdateWithNilDocumentBody
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello":@"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");

    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    NSString *docId = ob.docId;
    error = nil;
    CDTDocumentBody *body2 = [self createNilDocument];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNotNil(error, @"No Error updating document with nil CDTDocumentBody");
    STAssertTrue(error.code == 400, @"Error was not a 400. Found %ld", error.code);
    STAssertNil(ob2, @"CDTDocumentRevision object was not nil when updating with nil CDTDocumentBody");
    
    NSDictionary *modifiedCount = nil;
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
}

-(void)testMultipleUpdates
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSString *dbPath = [self pathForDBName:self.datastore.name];
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    STAssertNotNil(queue, @"FMDatabaseQueue was nil: %@", queue);
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];

    NSError *error;
    int numOfUpdates = 1001;

    NSArray *bodies = [self generateDocuments:numOfUpdates + 1];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:bodies[0] error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    for(int i = 0; i < numOfUpdates; i++){
        error = nil;
        ob = [self.datastore updateDocumentWithId:ob.docId
                                     prevRev:ob.revId
                                        body:bodies[i+1]
                                       error:&error];
        STAssertNil(error, @"Error creating document. Update Number %d", i);
        STAssertNotNil(ob, @"CDTDocumentRevision object was nil. Update Number %d", i);
    }
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": [[NSNumber alloc] initWithInt:numOfUpdates + 1]};
    NSLog(@"checking table counts");
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    NSLog(@"done checking table counts");
    
    NSLog(@"Checking revs and docs tables");
    MRDatabaseContentChecker *dc =[[MRDatabaseContentChecker alloc] init];
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSError *validationError;
        NSArray *expectedRows = @[
                                  @[@"docId"],
                                  @[ob.docId]
                                  ];
        STAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        
        NSMutableArray *expectedRows = [NSMutableArray array];
        [expectedRows addObject:@[@"doc_id", 
                                  @"sequence", 
                                  @"parent", 
                                  @"revid", 
                                  @"current",
                                  @"deleted",
                                  @"json"]];
        
        for (int counter = 1; counter <= numOfUpdates + 1; counter++) {
            
            NSInteger expectedSeq = counter;
            NSObject *expectedParent;
            if (expectedSeq == 1) {
                expectedParent = [NSNull null];
            } else {
                expectedParent = @(expectedSeq - 1);
            }
            
            NSString *revId = [NSString stringWithFormat:@"^%i-", counter];
            NSRegularExpression *revIdRegEx = [NSRegularExpression 
                                               regularExpressionWithPattern:revId                                                                            
                                               options:0                                                                                     
                                               error:nil];
            
            BOOL expectedCurrent = (counter == numOfUpdates +1);

            // This is the only zero based item we're checking
            // so counter starts at 1 and we minus one
            NSDictionary *expectedDict = [[bodies[counter-1] td_body] properties];
            NSData *json = [TDJSON dataWithJSONObject:expectedDict 
                                              options:0 
                                                error:nil];
            
            NSArray *row = @[@(1), 
                             @(expectedSeq), 
                             expectedParent, 
                             revIdRegEx, 
                             @(expectedCurrent), 
                             @NO, 
                             json];
            [expectedRows addObject:row];
        }
        
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);

    }];


}

//
// The following testUpdateDelete was to check the behavior when a "_deleted":true
// key-value pair was added to the JSON document. It is expected that when
// updateDocumentWithId is called, the document would be deleted from the DB.
// This is a method of deleting documents in Cloudant/CouchDB; it's the
// only way to delete documents in bulk. (We don't yet have a '_bulk_docs' call in CloudantSync,
// however, and not sure if we will...).
//
// In the code below, when "_deleted":true is added to the document and updateDocumentWithId
// is called, this key-value pair is simply thrown away and the document is inserted into
// the database as the next revision.
//
// This behavior should be different. Either we support _delete:true, or we return
// nil and report an NSError.
//
//-(void)testUpdateDelete
//{
//    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
//    //creates the tables in the sqlite db. otherwise, the database would be empty.
//    
//    NSString *dbPath = [self pathForDBName:self.datastore.name];
//    
//    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
//    STAssertNotNil(queue, @"FMDatabaseQueue was nil: %@", queue);
//    
//    NSMutableDictionary *initialRowCount = [self getAllTablesRowCountWithQueue:queue];
//    
//    NSError *error;
//    NSString *key1 = @"hello";
//    NSString *value1 = @"world";
//    
//    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key1:value1}];
//    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
//    STAssertNil(error, @"Error creating document");
//    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
//    
//    
//    NSString *docId = ob.docId;
//    NSString *delkey = @"_deleted";
//    NSNumber *delvalue= [NSNumber numberWithBool:YES];
//    NSString *key2 = @"hi";
//    NSString *value2 = @"adam";
//    //id value2 = $true;
//    NSDictionary *body2dict =@{key1:value1, key2:value2, delkey:delvalue};
//    
//    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:body2dict];
//    STAssertNotNil(body2, @"CDTDocumentBody with _deleted:true was nil. Dict: %@", body2dict);
//    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
//                                                            prevRev:ob.revId
//                                                               body:body2
//                                                              error:&error];
//
//    STAssertNil(error, @"Error deleting document with update");
//    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
//    
//    // Check new revision
//    const NSUInteger expected_count = 1;
//    CDTDocumentRevision *retrieved;
//    retrieved = [self.datastore getDocumentWithId:docId error:&error];
//    STAssertNotNil(error, @"No Error getting deleted document");
//    STAssertNil(retrieved, @"retrieved object was not nil");
//    
//    error = nil;
//    
//    // Check we can get old revision
//    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
//    STAssertNil(error, @"Error getting document using old rev");
//    STAssertNotNil(retrieved, @"retrieved object was nil");
//    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
//    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
//    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
//    STAssertEqualObjects(retrieved.documentAsDictionary[key1], value1, @"Object from database has wrong data");
//    
//    
//    //now test the content of docs/revs tables explicitely.
//    
//    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @2};
//    [self checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
//    
//    [self printAllRows:queue forTable:@"docs"];
//    [self printAllRows:queue forTable:@"revs"];
//    
////    NSString *sql = @"select * from docs";
////    __block int doc_id_inDocsTable;
////    [queue inDatabase:^(FMDatabase *db) {
////        FMResultSet *result = [db executeQuery:sql];
////        [result next];
////        NSLog(@"testing content of docs table");
////        
////        STAssertEqualObjects(docId, [result stringForColumn:@"docid"], @"doc id doesn't match. should be %@. found %@", docId,
////                             [result stringForColumn:@"docid"]);
////        
////        doc_id_inDocsTable = [result intForColumn:@"doc_id"];
////        
////        STAssertFalse([result next], @"There are too many rows in docs");
////        
////        [result close];
////    }];
////    
////    
////    sql = @"select * from revs";
////    [queue inDatabase:^(FMDatabase *db) {
////        FMResultSet *result = [db executeQuery:sql];
////        [result next];
////        
////        NSLog(@"testing content of revs table");
////        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"],
////                       @"doc_id in revs (%d) doesn't match doc_id in docs (%d).", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
////        
////        STAssertEquals(1, [result intForColumn:@"sequence"], @"sequence is not 1");
////        STAssertFalse([[result stringForColumn:@"revid"] isEqualToString:@""], @"revid string isEqual to empty string");
////        STAssertFalse([result boolForColumn:@"current"], @"document current should be NO");
////        STAssertTrue([result boolForColumn:@"deleted"], @"document deleted should be NO");
////        
////        NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
////                                                   options: TDJSONReadingMutableContainers
////                                                     error: NULL];
////        STAssertTrue([jsonDoc isEqualToDictionary:@{key1: value1}], @"JSON document from revs.json not equal to original key-value pair. Found %@. Expected %@", jsonDoc, @{key1: value1});
////        
////        //next row
////        STAssertTrue([result next], @"Didn't find the second row in the revs table");
////        
////        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"],
////                       @"doc_id in revs (%d) doesn't match doc_id in docs (%d).", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
////        
////        STAssertEquals(2, [result intForColumn:@"sequence"], @"sequence is not 1");
////        STAssertFalse([[result stringForColumn:@"revid"] isEqualToString:@""], @"revid string isEqual to empty string");
////        STAssertTrue([result boolForColumn:@"current"], @"document current should be YES");
////        STAssertFalse([result boolForColumn:@"deleted"], @"document deleted should be NO");
////        
////        jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
////                                     options: TDJSONReadingMutableContainers
////                                       error: NULL];
////        STAssertTrue([jsonDoc isEqualToDictionary:@{key2: value2}], @"JSON document from revs.json not equal to original key-value pair. Found %@. Expected %@", jsonDoc, @{key2: value2});
////        
////        
////        STAssertFalse([result next], @"There are too many rows in revs");
////        STAssertNil([result stringForColumn:@"doc_id"], @"after [result next], doc_id not nil");
////        STAssertNil([result stringForColumn:@"revid"], @"after [result next],  revid not nil");
////        
////        [result close];
////    }];
//    
//
//    
//}


#pragma mark - DELETE tests

- (void)testDeletedItem404
{
    NSError *error = nil;

    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Zambia", @"area": @(752614)}]
                                                                error:&error];

    [self.datastore deleteDocumentWithId:rev.docId
                                     rev:rev.revId
                                   error:&error];

    CDTDocumentRevision *tmp = [self.datastore getDocumentWithId:rev.docId
                                                           error:&error];

    STAssertNil(tmp, @"deleted doc returned");
    STAssertEquals((NSInteger)404, [error code], @"Wrong error code for deleted item.");
}

- (void)testDeletedFlagOnDocumentRevision
{
    NSError *error = nil;

    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Zambia", @"area": @(752614)}]
                                                                error:&error];

    rev = [self.datastore deleteDocumentWithId:rev.docId
                                           rev:rev.revId
                                         error:&error];

    CDTDocumentRevision *tmp = [self.datastore getDocumentWithId:rev.docId
                                        rev:rev.revId
                                      error:&error];

    STAssertNotNil(tmp, @"Deleted doc not returned when queried with rev ID");
    STAssertTrue(tmp.deleted, @"Deleted document was not flagged deleted");
}

-(void)testDeleteDocument
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.

    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    NSString *docId = ob.docId;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentWithId:docId
                                                       rev:ob.revId
                                                     error:&error];
    STAssertNil(error, @"Error deleting document: %@", error);
    STAssertNotNil(deleted, @"Error deleting document: %@", error);
    
    // Check new revision isn't found
    error = nil;
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    STAssertNotNil(error, @"No Error getting deleted document");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(retrieved, @"retrieved object was not nil");
    
    //Now try deleting it again.
    error = nil;
    deleted = [self.datastore deleteDocumentWithId:docId
                                               rev:ob.revId  //old revision, can't get deleted revision
                                             error:&error];
    STAssertNil(deleted, @"CDTRevsision was not nil on Error deleting document: %@", error);
    STAssertNotNil(error, @"No Error trying to delete already deleted document");
    //CouchDB/Cloudant returns 409, But CloudantSync returns a 404.
    //STAssertTrue(error.code == 409, @"Found %@", error);
    
    // Check we can get old revision
    error = nil;
    const NSUInteger expected_count = 1;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
    STAssertNil(error, @"Error getting document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
    
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @2};
    NSLog(@"checking table counts");
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    NSLog(@"done checking table count");
    
    //explicit check of docs/revs tables
    __block int doc_id_inDocsTable;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from docs"];
        [result next];
        NSLog(@"testing content of docs table");
        STAssertEqualObjects(docId, [result stringForColumn:@"docid"],@"%@ != %@", docId,[result stringForColumn:@"docid"]);
        doc_id_inDocsTable = [result intForColumn:@"doc_id"];
        STAssertFalse([result next], @"There are too many rows in docs");
        [result close];
    }];
    
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from revs"];
        [result next];
        
        NSLog(@"testing content of revs table");
        NSError *error;
        
        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        STAssertTrue([result intForColumn:@"sequence"] == 1, @"%d", [result intForColumn:@"sequence"]);
        STAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 1, @"rev: %@", [result stringForColumn:@"revid"] );
        STAssertFalse([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        STAssertFalse([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"current"]);
        STAssertEqualObjects([result objectForColumnName:@"parent"], [NSNull null], @"Found %@", [result objectForColumnName:@"parent"]);
        NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                   options: TDJSONReadingMutableContainers
                                                     error: &error];
        STAssertTrue([jsonDoc isEqualToDictionary:@{@"hello": @"world"}],@"JSON %@. NSError %@", jsonDoc, error);
        
        //next row
        STAssertTrue([result next], @"Didn't find the second row in the revs table");
        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        STAssertTrue([result intForColumn:@"sequence"] == 2, @"%d", [result intForColumn:@"sequence"]);
        STAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 2, @"rev: %@", [result stringForColumn:@"revid"] );
        STAssertTrue([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        STAssertTrue([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"current"]);
        STAssertTrue([result intForColumn:@"parent"] == 1, @"Found %@", [result intForColumn:@"parent"]);
        
        //TD_Database+Insertion inserts an empty NSData object instead of NSNull on delete
        STAssertEqualObjects([result objectForColumnName:@"json"], [NSData data], @"Found %@", [result objectForColumnName:@"json"]);
        error = nil;
        jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                     options: TDJSONReadingMutableContainers
                                       error: NULL];
        STAssertNil(jsonDoc, @"Expected revs.json to be nil: %@",jsonDoc);
        
        //shouldn't be any more rows.
        STAssertFalse([result next], @"There are too many rows in revs");
        STAssertNil([result stringForColumn:@"doc_id"], @"after [result next], doc_id is %@", [result stringForColumn:@"doc_id"]);
        STAssertNil([result stringForColumn:@"revid"], @"after [result next],  revid is %@", [result stringForColumn:@"revid"]);
        
        [result close];
    }];

}

-(void)testDeleteUpdateDocument
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    //create document
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    //update document
    error = nil;
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNil(error, @"Error updating document");
    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    //delete doc.
    error = nil;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentWithId:docId
                                                       rev:ob2.revId
                                                     error:&error];
    STAssertNil(error, @"Error deleting document: %@", error);
    STAssertNotNil(deleted, @"Error deleting document: %@", error);
    
    // Check new revision isn't found
    error = nil;
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    STAssertNotNil(error, @"No Error getting deleted document");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(retrieved, @"retrieved object was not nil");
    
    // Check we can get the updated revision before it was deleted (ob2)
    error = nil;
    const NSUInteger expected_count = 1;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob2.revId error:&error];
    STAssertNil(error, @"Error getting document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[key2], value2, @"Object from database has wrong data");
    
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @3};
    NSLog(@"checking table counts");
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    NSLog(@"done checking table count");
    
    //explicit check of docs/revs tables
    __block int doc_id_inDocsTable;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from docs"];
        [result next];
        NSLog(@"testing content of docs table");
        STAssertEqualObjects(docId, [result stringForColumn:@"docid"],@"%@ != %@", docId,[result stringForColumn:@"docid"]);
        doc_id_inDocsTable = [result intForColumn:@"doc_id"];
        STAssertFalse([result next], @"There are too many rows in docs");
        [result close];
    }];
    
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from revs"];
        [result next];
        
        NSLog(@"testing content of revs table");
        
        //initial doc
        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        STAssertTrue([result intForColumn:@"sequence"] == 1, @"%d", [result intForColumn:@"sequence"]);
        STAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 1, @"rev: %@", [result stringForColumn:@"revid"] );
        STAssertFalse([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        STAssertFalse([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"deleted"]);
        STAssertEqualObjects([result objectForColumnName:@"parent"], [NSNull null], @"Found %@", [result objectForColumnName:@"parent"]);

        NSError *error;
        NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                   options: TDJSONReadingMutableContainers
                                                     error: &error];
        STAssertTrue([jsonDoc isEqualToDictionary:@{@"hello": @"world"}],@"JSON %@. NSError %@", jsonDoc, error);
        
        //updated doc
        STAssertTrue([result next], @"Didn't find the second row in the revs table");
        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        STAssertTrue([result intForColumn:@"sequence"] == 2, @"%d", [result intForColumn:@"sequence"]);
        STAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 2, @"rev: %@", [result stringForColumn:@"revid"] );
        STAssertFalse([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        STAssertFalse([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"deleted"]);
        STAssertTrue([result intForColumn:@"parent"] == 1, @"Found %d", [result intForColumn:@"parent"]);
        
        error = nil;
        jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                     options: TDJSONReadingMutableContainers
                                       error: &error];
        STAssertTrue([jsonDoc isEqualToDictionary:@{key2: value2}],@"JSON %@. NSError %@", jsonDoc, error);
   
        
        //deleted doc
        STAssertTrue([result next], @"Didn't find the third row in the revs table");
        STAssertEquals(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        STAssertTrue([result intForColumn:@"sequence"] == 3, @"%d", [result intForColumn:@"sequence"]);
        STAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 3, @"rev: %@", [result stringForColumn:@"revid"] );
        STAssertTrue([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        STAssertTrue([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"current"]);
        STAssertTrue([result intForColumn:@"parent"] == 2, @"Found %d", [result intForColumn:@"parent"]);
        
        //TD_Database+Insertion inserts an empty NSData object instead of NSNull
        STAssertEqualObjects([result objectForColumnName:@"json"], [NSData data], @"Found %@", [result objectForColumnName:@"json"]);
        
        error = nil;
        jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                     options: TDJSONReadingMutableContainers
                                       error: &error];
        STAssertNil(jsonDoc, @"Expected json dictionary to be nil: %@. Error %@",jsonDoc, error);
        
        //should be done
        STAssertFalse([result next], @"There are too many rows in revs");
        STAssertNil([result stringForColumn:@"doc_id"], @"after [result next], doc_id is %@", [result stringForColumn:@"doc_id"]);
        STAssertNil([result stringForColumn:@"revid"], @"after [result next],  revid is %@", [result stringForColumn:@"revid"]);
        
        [result close];
    }];

}

-(void)testUpdateDeleteUpdateOldRev
{
    
    //create document rev 1-
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];

    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    //update document rev 2-
    error = nil;
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNil(error, @"Error updating document");
    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    //delete doc. rev 3-
    error = nil;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentWithId:docId
                                                       rev:ob2.revId
                                                     error:&error];
    STAssertNil(error, @"Error deleting document: %@", error);
    STAssertNotNil(deleted, @"Error deleting document: %@", error);
    
    // Check new revision isn't found
    error = nil;
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    STAssertNotNil(error, @"No Error getting deleted document");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(retrieved, @"retrieved object was not nil");
    
    //now try updating rev 2-
    
    //get update rev 2-
    error = nil;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob2.revId error:&error];
    STAssertNil(error, @"Error getting document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEqualObjects(retrieved.documentAsDictionary[key2], value2, @"Object from database has wrong data");
    
    //try updating rev 2-
    error = nil;
    NSString *key3 = @"chew";
    NSString *value3 = @"branca";
    CDTDocumentBody *body3 = [[CDTDocumentBody alloc] initWithDictionary:@{key3:value3}];
    CDTDocumentRevision *ob3 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob2.revId
                                                               body:body3
                                                              error:&error];
    STAssertNotNil(error, @"No Error updating deleted document");
    //inconsitent with error reported by cloudant/couchdb. cloudant/couch returns 409, TD* retunrs 404
//    STAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", error.code);
    STAssertNil(ob3, @"retrieved object was not nil");
}

-(void)testGetAllDocsDoesntFindDeletedDocs
{
    
    NSError *error;
    int objectCount = 100;
    NSArray *bodies = [self generateDocuments:objectCount];
    NSMutableArray *dbObjects = [NSMutableArray arrayWithCapacity:objectCount];
    for (int i = 0; i < objectCount; i++) {
        error = nil;
        // Results will be ordered by docId, so give an orderable ID.
        NSString *docId = [NSString stringWithFormat:@"hello-%010d", i];
        CDTDocumentRevision *ob = [self.datastore createDocumentWithId:docId body:bodies[i] error:&error];
        STAssertNil(error, @"Error creating document");
        [dbObjects addObject:ob];
    }
    
    NSMutableArray *deletedDbObjects = [[NSMutableArray alloc] init];
    NSMutableSet *deletedDbDicts = [[NSMutableSet alloc] init];
    NSMutableArray *notDeletedDbObjects = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < objectCount; i++) {
        if(arc4random_uniform(100) < 30) {  //delete ~30% of the docs
            error = nil;
            CDTDocumentRevision *ob = [dbObjects objectAtIndex:i];
            CDTDocumentRevision *deleted = [self.datastore deleteDocumentWithId:ob.docId
                                                                            rev:ob.revId
                                                                          error:&error];
            STAssertNotNil(deleted, @"Error deleting document: %@", error);
            [deletedDbObjects addObject:ob];
            [deletedDbDicts addObject:ob.documentAsDictionary];
        }
        else
            [notDeletedDbObjects addObject:[dbObjects objectAtIndex:i]];
    }
    
    // Test for docs that are expected in the database
    int offset = 0;
    NSArray *result;
    result = [self.datastore getAllDocumentsOffset:offset
                                             limit:objectCount + 10
                                        descending:NO];
    
    //compare the returned revs to the expected with getAllDocuments
    [self getAllDocuments_compareResultExpected:notDeletedDbObjects actual:result count:(int)notDeletedDbObjects.count offset:offset];
    
    //make sure none of the deleted documents are found in the results.
    for(CDTDocumentRevision* aRev in result){
        for(NSDictionary *aDeletedDict in deletedDbDicts){
            STAssertFalse(aDeletedDict == aRev.documentAsDictionary, @"Found equal pointers. %d == %d", aRev.documentAsDictionary, aDeletedDict );
            STAssertFalse([aDeletedDict isEqualToDictionary:aRev.documentAsDictionary], @"Found deleted dictionary in results");
        }
        //is this the same as above?
        STAssertNil([deletedDbDicts member:aRev.documentAsDictionary], @"Found result in deleted set: %@", aRev.documentAsDictionary);
    }

    //get all of the previous revisions of the deleted docs and make sure they are deleted.
    [self.datastore documentCount];
    NSString *dbPath = [self pathForDBName:self.datastore.name];
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    STAssertNotNil(queue, @"FMDatabaseQueue was nil: %@", queue);
    
    for(CDTDocumentRevision *aRev in deletedDbObjects){
        NSError *error;
        CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:aRev.docId rev:aRev.revId error:&error];
        STAssertNil(error, @"Error getting retreived doc. %@, %@", aRev.docId, aRev.revId);
        STAssertNotNil(retrieved, @"CDTDocumentRevision was nil");
        
        BOOL found = NO;
        for(NSDictionary *aDeletedDict in deletedDbDicts){
            if([aDeletedDict isEqualToDictionary:retrieved.documentAsDictionary])
                found = YES;
        }
        STAssertTrue(found, @"didn't find %@", aRev.documentAsDictionary);
        
        //query the database to ensure it has the proper structure
        [queue inDatabase:^(FMDatabase *db){
            
            FMResultSet *result = [db executeQuery:
                                   @"select * from revs, docs where revs.doc_id = docs.doc_id and docs.docid = (?)", aRev.docId ];
            int count = 0;
            while([result next]){
                count++;
                if(count == 2){
                    STAssertTrue([result boolForColumn:@"deleted"], @"not deleted");
                    STAssertTrue([result boolForColumn:@"current"], @"this rev is not current");
                }
                else{
                    STAssertFalse([result boolForColumn:@"deleted"], @"wrong rev is deleted");
                    STAssertFalse([result boolForColumn:@"current"], @"wrong rev is current");
                    NSError *error;
                    NSDictionary *jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                 options: TDJSONReadingMutableContainers
                                                   error: &error];
                    STAssertTrue([jsonDoc isEqualToDictionary:aRev.documentAsDictionary],@"JSON %@. NSError %@", jsonDoc, error);
                }
            }
            STAssertTrue(count == 2, @"found more than %d rows", count);
            [result close];
        }];
    }
    
}

-(void)testDeleteNonExistingDoc
{
    [self.datastore documentCount]; //ensure db population
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    NSError *error;
    int objectCount = 100;
    NSArray *bodies = [self generateDocuments:objectCount];
    NSMutableArray *dbObjects = [NSMutableArray arrayWithCapacity:objectCount];
    for (int i = 0; i < objectCount; i++) {
        error = nil;
        // Results will be ordered by docId, so give an orderable ID.
        NSString *docId = [NSString stringWithFormat:@"hello-%010d", i];
        CDTDocumentRevision *aRev = [self.datastore createDocumentWithId:docId body:bodies[i] error:&error];
        STAssertNil(error, @"Error creating document");
        [dbObjects addObject:aRev];
    }
    
    NSDictionary *modifiedCount = @{@"docs": [NSNumber numberWithInt:objectCount], @"revs": [NSNumber numberWithInt:objectCount]};
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    initialRowCount = [self.dbutil getAllTablesRowCount];
    
    error = nil;
    NSString *docId = @"idonotexist";
    NSString *revId = @"1-abcdef1234567890abcdef9876543210";
    CDTDocumentRevision *aRev = [self.datastore getDocumentWithId:docId error:&error ];
    STAssertNotNil(error, @"No Error getting document that doesn't exist");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(aRev, @"CDTDocumentRevision should be nil after getting document that doesn't exist");
    
    error = nil;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentWithId:docId
                                                       rev:revId
                                                     error:&error];
    STAssertNotNil(error, @"No Error deleting document that doesn't exist");
    STAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", error.code);
    STAssertNil(deleted, @"CDTDocumentRevision* was not nil. Deletion successful?: %@", error);
    
    
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];
    
}

#pragma mark - Other Tests

-(void)testCompactSingleDoc
{
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";
    
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{key1:value1}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    error = nil;
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{key2:value2}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:ob.docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNil(error, @"Error updating document");
    STAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    TDStatus statusResults = [self.datastore.database compact];
    STAssertTrue([TDStatusToNSError( statusResults, nil) code] == 200, @"TDStatusAsNSError: %@", TDStatusToNSError( statusResults, nil));
    
}
@end
