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

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>
#import <MRDatabaseContentChecker/MRDatabaseContentChecker.h>

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
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
#import "CDTAttachment.h"

@interface CDTDatastore ()
- (BOOL)validateAttachments:(NSDictionary<NSString *, CDTAttachment *> *)attachments;
@end

@interface DatastoreCRUD : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) DBQueryUtils *dbutil;
@end


@implementation DatastoreCRUD

- (void)setUp
{
    [super setUp];

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    self.dbutil =[[DBQueryUtils alloc] initWithDbPath:[self pathForDBName:self.datastore.name]];
    
    XCTAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.
    
    self.datastore = nil;
    self.dbutil = nil;
    
    [super tearDown];
}

#pragma mark - helper methods


-(NSArray*)generateDocuments:(int)count
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSDictionary *dict = @{[NSString stringWithFormat:@"hello-%i", i]: @"world"};
        [result addObject:dict];
    }
    return result;
}


#pragma mark - CREATE tests

-(void) testDocumentWithInfinityValue
{
    NSError * error;
    CDTDocumentRevision *revision = [CDTDocumentRevision revision];
    revision.body = [@{ @"infinity" : @(INFINITY) } mutableCopy];

    CDTDocumentRevision * rev = [self.datastore createDocumentFromRevision:revision
                                                                     error:&error];
    
    XCTAssertNil(rev,@"revision is not nil");
    XCTAssertNotNil(error,@"Error should be set");
    XCTAssertEqual(400,
                   error.code,
                   @"Error code should be 400, but was %ld",
                   (long)error.code);
}

- (void)testAttachmentValidationUnexpectedAttsDictKey
{
    CDTUnsavedDataAttachment *dataAttachment = [[CDTUnsavedDataAttachment alloc]
        initWithData:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                name:@"test"
                type:@"text/plain"];
    NSDictionary<NSString *, CDTAttachment *> *attachmentsDict =
        @{ @"not the name" : dataAttachment };
    XCTAssertFalse([self.datastore validateAttachments:attachmentsDict],
                   "Attachments dictionary not keyed on attachment name should fail validation");
}

- (void)testAttachmentValidationCorrectAttsDictKey
{
    CDTUnsavedDataAttachment *dataAttachment = [[CDTUnsavedDataAttachment alloc]
        initWithData:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                name:@"test"
                type:@"text/plain"];
    NSDictionary<NSString *, CDTAttachment *> *attachmentsDict = @{ @"test" : dataAttachment };
    XCTAssertTrue([self.datastore validateAttachments:attachmentsDict],
                  "Attachments dictionary keyed on attachment name should pass validation");
}

-(void) testDocumentWithNonSerialisableValue {
    NSError * error;
    CDTDocumentRevision *revision = [CDTDocumentRevision revision];
    revision.body = [@{ @"nonserialisable" : [NSDate date] } mutableCopy];

    CDTDocumentRevision * rev = [self.datastore createDocumentFromRevision:revision
                                                                     error:&error];
    
    XCTAssertNil(rev,@"revision is not nil");
    XCTAssertNotNil(error,@"Error should be set");
    XCTAssertEqual(400,
                   error.code,
                   @"Error code should be 400, but was %ld",
                   (long)error.code);
}

-(void)testCreateOneDocumentSQLEntries
{
    NSError *error;
    NSString *key = @"hello";
    NSString *value = @"world";
    NSString *testDocId = @"document_id_for_CreateOneDocumentSQLEntries";
    
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.

    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];

    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:testDocId];
    doc.body = [@{key:value} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
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
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
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
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}


-(void)testCannotInsertNil
{

    NSError *error;
    NSString *testDocId = @"document_id_for_cannotInsertNil";

    CDTDocumentRevision *rev;
    rev = [CDTDocumentRevision revisionWithDocId:testDocId];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    rev.body = nil;
    rev.attachments = nil;
#pragma clang diagnostic pop
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNotNil(error, @"No Error creating document!");
    XCTAssertTrue(error.code == 400, @"Error was not a 400. Found %ld", (long)error.code);
    XCTAssertNil(ob, @"CDTDocumentRevision object was not nil");
    
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];

}
-(void)testCreateDocumentWithIdInBodyFails
{
    NSError *error;
    NSString *key = @"hello";
    NSString *value = @"world";
    NSString *testDocId = @"document_id_for_testCreateDocumentWithIdInBody";

    CDTDocumentRevision *rev;
    rev = [CDTDocumentRevision revisionWithDocId:testDocId];
    rev.body = [@{key:value,@"_id":testDocId} mutableCopy];

    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNotNil(error, @"Error creating document");
    XCTAssertNil(ob, @"CDTDocumentRevision object was nil");
}

-(void)testCannotCreateNewDocWithoutUniqueID
{
    NSError *error;
    NSString *key = @"hello";
    NSString *value = @"world";
    NSString *testDocId = @"document_id_for_CannotCreateNewDocWithoutUniqueID";

    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:testDocId];
    doc.body = [@{key:value} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    doc = [CDTDocumentRevision revisionWithDocId:testDocId];
    doc.body = [@{key:value} mutableCopy];
    ob = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNotNil(error, @"Error was nil when creating second doc with same doc_id");
    XCTAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", (long)error.code);
    XCTAssertNil(ob, @"CDTDocumentRevision object was not nil when creating second doc with same doc_id");
}

-(void)testAddDocument
{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    doc.body = [@{@"hello": @"world"} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:doc error:&error];
    
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
}

-(void)testCreateDocumentWithId
{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:@"document_id_for_test"];
    doc.body = [@{@"hello":@"world"} mutableCopy];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:doc error:&error];
    
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    XCTAssertEqualObjects(@"document_id_for_test", ob.docId, @"Document ID was not as set in test");
    
    error = nil;
    NSString *docId = ob.docId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId error:&error];
    
    XCTAssertNil(error, @"Error retrieving document");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    const NSUInteger expected_count = 1;
    XCTAssertEqual(ob.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(ob.body[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testCannotCreateConflict
{
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    doc.body = [@{key1:value1} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";

    doc = [ob copy];
    doc.body = [@{key2:value2} mutableCopy];
    
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:doc error:&error];
    XCTAssertNil(error, @"Error updating document");
    XCTAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    //now create a conflict
    error = nil;
    NSString *key3 = @"hi";
    NSString *value3 = @"adam";

    doc = [ob copy];
    doc.body = [@{key3:value3} mutableCopy];
    
    CDTDocumentRevision *ob3 = [self.datastore updateDocumentFromRevision:doc error:&error];
    XCTAssertTrue(error.code == 409, @"Incorrect error code: %@", error);
    XCTAssertNil(ob3, @"CDTDocumentRevision object was not nil");
    
}

- (void)testCreateUsingCDTDocumentRevision
{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:@"MyFirstTestDoc"];
    doc.body = [@{@"title":@"Testing New creation API",@"FirstTest":@YES} mutableCopy];
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertTrue(saved, @"Failed to save new document");
    
}

- (void)testCreateWithoutBodyInCDTDocumentRevision
{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    doc.body = nil;
#pragma clang diagnostic pop
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNil(saved, @"Document was created without a body");
}

- (void)testCreateWithaDocumentIdNoBodyCDTDocumentRevision
{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:@"doc1"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    doc.body = nil;
#pragma clang diagnostic pop
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNil(saved, @"Document with Id but no body created");
}

- (void)testCreateWithDefaultMutableRevision {
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertNotNil(saved, @"Default document was not created");
    XCTAssertNil(error,"reccieved an error, expected no error");
}

- (void)testCreateWithOnlyBodyCDTDocumentRevision
{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    doc.body = [@{@"DocumentBodyItem1":@"Hi",@"Hello":@"World"} mutableCopy];
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision: doc error:&error];
    XCTAssertTrue(saved, @"Document was not created");
}

-(void) testCreateWithAppendedBodyData {
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    NSMutableDictionary *body = [doc.body mutableCopy];
    body[@"value"] = @"Modified";
    doc.body = body;
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision: doc error:&error];
    XCTAssertTrue(saved, @"Document was not created");
    XCTAssertEqualObjects(saved.body, @{@"value":@"Modified"});
    XCTAssertNil(error, @"Error was not nil, an error occured creating the document");
}

-(void) testCreateWithAppenedAttachment {
    NSData *data = [@"Hello World!" dataUsingEncoding:NSUTF8StringEncoding];
    CDTAttachment *attachment =
        [[CDTUnsavedDataAttachment alloc] initWithData:data name:@"helloWorld.txt" type:@"txt"];
                                   //initWithName:@"HelloWorld.txt" type:@"txt" size:[data length]];
    
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    NSMutableDictionary *attachments = [doc.attachments mutableCopy];
    attachments[attachment.name] = attachment;
    doc.attachments = attachments;
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertTrue(saved, @"Document was not created");
    XCTAssertTrue([saved.attachments count] == 1);
    XCTAssertNil(error,@"Error was not nil, an error occured creating the document");
}

#pragma mark - READ tests

-(void)testGetDocument
{
    NSError *error;

    CDTDocumentRevision *doc = [CDTDocumentRevision revision];
    doc.body = [@{@"hello":@"world"}mutableCopy];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:doc error:&error];
    
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    NSString *docId = ob.docId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId error:&error];
    
    XCTAssertNil(error, @"Error retrieving document");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    const NSUInteger expected_count = 1;
    XCTAssertEqual(ob.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(ob.body[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testGetDocumentWithIdAndRev
{
    NSError *error;

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{@"hello":@"world"} mutableCopy];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    
    error = nil;
    NSString *docId = ob.docId;
    NSString *revId = ob.revId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId rev:revId error:&error];
    XCTAssertNil(error, @"Error retrieving document");
    
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    const NSUInteger expected_count = 1;
    XCTAssertEqual(ob.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(ob.body[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testGetDocumentsWithIds
{
    NSError *error;
    NSMutableArray *docIds = [NSMutableArray arrayWithCapacity:20];
    
    for (int i = 0; i < 200; i++) {
        error = nil;
        CDTDocumentRevision *rev = [CDTDocumentRevision revision];
        rev.body = [@{@"hello":@"world",@"index":[NSNumber numberWithInt:i]} mutableCopy];
        CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document");
        
        NSString *docId = ob.docId;
        [docIds addObject:docId];
    }
    
    NSArray *retrivedDocIds = @[docIds[5], docIds[7], docIds[12], docIds[170]];
    NSArray *obs = [self.datastore getDocumentsWithIds:retrivedDocIds];
    XCTAssertNotNil(obs, @"Error getting documents");
    
    int ob_index = 0;
    for (NSNumber *index in @[@5, @7, @12, @170]) {
        NSString *docId = [docIds objectAtIndex:[index intValue]];
        CDTDocumentRevision *retrieved = [obs objectAtIndex:ob_index];
        
        XCTAssertNotNil(retrieved, @"retrieved object was nil");
        XCTAssertEqualObjects(retrieved.docId, docId, @"Object retrieved from database has wrong docid");
        const NSUInteger expected_count = 2;
        XCTAssertEqual(retrieved.body.count, expected_count, @"Object from database has != 2 keys");
        XCTAssertEqualObjects(retrieved.body[@"hello"], @"world", @"Object from database has wrong data");
        XCTAssertEqualObjects(retrieved.body[@"index"], index, @"Object from database has wrong data");
        
        ob_index++;
    }
}

-(void)testGetDocumentsWithIds_NonExistentDocument
{
    NSError *error;
    NSMutableArray *docIds = [NSMutableArray arrayWithCapacity:20];
    
    for (int i = 0; i < 200; i++) {
        error = nil;
        CDTDocumentRevision *rev = [CDTDocumentRevision revision];
        rev.body = [@{@"hello":@"world",@"index":[NSNumber numberWithInt:i]} mutableCopy];
        CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document");
        
        NSString *docId = ob.docId;
        [docIds addObject:docId];
    }
    
    NSArray *retrivedDocIds = @[docIds[5], docIds[7], docIds[12], docIds[170], @"i_do_not_exist"];
    NSArray *obs = [self.datastore getDocumentsWithIds:retrivedDocIds];
    XCTAssertNotNil(obs, @"Error getting documents");
    
    XCTAssertEqual([obs count], 4, @"Unexpected number of documents");
    
    int ob_index = 0;
    for (NSNumber *index in @[@5, @7, @12, @170]) {
        NSString *docId = [docIds objectAtIndex:[index intValue]];
        CDTDocumentRevision *retrieved = [obs objectAtIndex:ob_index];
        
        XCTAssertNotNil(retrieved, @"retrieved object was nil");
        XCTAssertEqualObjects(retrieved.docId, docId, @"Object retrieved from database has wrong docid");
        const NSUInteger expected_count = 2;
        XCTAssertEqual(retrieved.body.count, expected_count, @"Object from database has != 2 keys");
        XCTAssertEqualObjects(retrieved.body[@"hello"], @"world", @"Object from database has wrong data");
        XCTAssertEqualObjects(retrieved.body[@"index"], index, @"Object from database has wrong data");
        
        ob_index++;
    }
}

-(void)testGetNonExistingDocument
{
    NSError *error;

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{@"hello":@"world"}mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    
    error = nil;
    NSString *docId = @"i_do_not_exist";
    NSString *revId = ob.revId;
    CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:docId rev:revId error:&error];
    XCTAssertNotNil(error, @"Error should not be nil.");
    XCTAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", (long)error.code);
    XCTAssertNil(retrieved, @"retrieved object was nil");
    
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
        CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:randomId];
        rev.body = [dict mutableCopy];

        error = nil;
        if([lastDocForId[randomId][@"numUpdates"] intValue] == 0) {
            cdt_rev = [self.datastore createDocumentFromRevision:rev error:&error];
            XCTAssertNil(error, @"Error creating document. %@", error);
            XCTAssertNotNil(cdt_rev, @"CDTDocumentRevision was nil");
        }
        else{
            cdt_rev = [self.datastore getDocumentWithId:randomId
                                                  error:&error];
            CDTDocumentRevision *update = [cdt_rev copy];
            update.body = rev.body;
            XCTAssertNil(error, @"Error getting document");
            XCTAssertNotNil(cdt_rev, @"retrieved CDTDocumentRevision was nil");
            error = nil;
            cdt_rev = [self.datastore updateDocumentFromRevision:update error:&error];
            XCTAssertNil(error, @"Error updating document");
            XCTAssertNotNil(cdt_rev, @"updated CDTDocumentRevision was nil");
        }
        
        //update our dictionary that is recording the last "event" for each doc id
        unsigned int currentCount = [lastDocForId[randomId][@"numUpdates"] unsignedIntValue];
        lastDocForId[randomId][@"numUpdates"]  = [NSNumber numberWithUnsignedInt:currentCount + 1];
        lastDocForId[randomId][@"lastrev"] =  cdt_rev.revId;
        lastDocForId[randomId][@"json"] = dict;
        
        XCTAssertTrue([lastDocForId[randomId][@"numUpdates"] unsignedIntegerValue] == [TD_Revision generationFromRevID:cdt_rev.revId],
                       @"rev prefix value does not equal expected number of updates");
    }
    
    NSDictionary *modifiedCounts = @{@"docs":@4, @"revs":[NSNumber numberWithInt:totalUpdates]};
    [self.dbutil checkTableRowCount:initialRowCounts modifiedBy:modifiedCounts];
    
    //now compact and check that all old revs obtained via CDTDatastore contain empty JSON.
    //note: I have to #import "TD_Database+Insertion.h" in order to compact.
    TDStatus statusResults = [self.datastore.database compact];
    XCTAssertTrue([TDStatusToNSError( statusResults, nil) code] == 200,
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
            XCTAssertNil(error, @"Error getting document");
            XCTAssertNotNil(cdt_rev, @"retrieved object was nil");
            XCTAssertEqualObjects(lastRev, cdt_rev.revId, @"Object retrieved from database has wrong revid");
            XCTAssertEqualObjects(cdt_rev.body, lastRecordedJsonDoc, @"Object from database has wrong data");
            XCTAssertTrue(numUpdates == [TD_Revision generationFromRevID:cdt_rev.revId], @"rev prefix value does not equal expected number of updates");
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
                XCTAssertEqualObjects([result stringForColumn:@"docid"], aDocId,
                                     @"Document ID mismatch: %@", [result stringForColumn:@"docid"]);
                
                NSString *revid = [result stringForColumn:@"revid"];
                XCTAssertTrue([TD_Revision generationFromRevID:revid] - 1 == revPrefix,
                              @"revision out of order: Found Rev: %@ and previous prefix %ld",
                              revid, (long)revPrefix);
                revPrefix = [TD_Revision generationFromRevID:revid];
                
                XCTAssertFalse([result boolForColumn:@"deleted"], @"deleted? %@", [result stringForColumn:@"deleted"]);
                
                //this should be the first row in the result
                if(docNum == -1){
                    docNum = [result intForColumn:@"docnum"]; //make sure docNum is always the same
                    XCTAssertEqualObjects([result objectForColumnName:@"parent"], [NSNull null], @"parent: %@", [result objectForColumnName:@"parent"]);
                }
                else{
                    XCTAssertTrue([result intForColumn:@"docnum"] == docNum, @"%@", [result stringForColumn:@"docnum"]);
                    XCTAssertTrue([result intForColumn:@"docnum"] <= ids.count, @"%@", [result stringForColumn:@"docnum"]);
                }
                
                //only the last rev should have valid JSON data
                //otherwise FMDB returns an empty NSData object.
                if([revid isEqualToString:lastDocForId[aDocId][@"lastrev"]]){
                    NSError *error;
                    NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                               options: TDJSONReadingMutableContainers
                                                                 error: &error];
                    XCTAssertTrue([jsonDoc isEqualToDictionary:lastDocForId[aDocId][@"json"]], @"Found: %@", jsonDoc);
                    if(jsonDoc)
                        foundJSON = YES;
                }
                else{
                    //This was slightly unexpected. When TD_Database deletes, the JSON becomes an empty NSData
                    //object. But when compacting, it sets it to null. See TD_Database+Insertion compact.
                    XCTAssertEqualObjects([result objectForColumnName:@"json"], [NSNull null],
                                         @"Expected revs.json to be empty NSData. Found %@", [result objectForColumnName:@"json"]);
                }
                
            }
            
            XCTAssertTrue(foundJSON, @"didn't find json");
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
        CDTDocumentRevision *rev;
        rev = [CDTDocumentRevision revisionWithDocId:docId];
        rev.body = bodies[i];
        CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document");
        [dbObjects addObject:ob];
    }
    //    NSArray* reversedObjects = [[dbObjects reverseObjectEnumerator] allObjects];
    
    // Test count and offsets for descending and ascending
    [self getAllDocuments_testCountAndOffset:objectCount expectedDbObjects:dbObjects descending:NO];
    //[self getAllDocuments_testCountAndOffset:objectCount expectedDbObjects:reversedObjects descending:YES];
}

-(void)testGetAllDocumentIds
{
    XCTAssertEqual([self.datastore getAllDocumentIds].count, 0, @"No documents should exist.");
    
    NSError *error;
    int objectCount = 1000;
    NSArray *bodies = [self generateDocuments:objectCount];
    NSMutableArray *dbObjects = [NSMutableArray arrayWithCapacity:objectCount];
    for (int i = 0; i < objectCount; i++) {
        // Results will be ordered by docId, so give an orderable ID.
        error = nil;
        NSString *docId = [NSString stringWithFormat:@"hello-%04d", i];
        CDTDocumentRevision *rev;
        rev = [CDTDocumentRevision revisionWithDocId:docId];
        rev.body = bodies[i];
        CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document");
        [dbObjects addObject:ob];
    }
    
    XCTAssertEqual([self.datastore getAllDocumentIds].count,
                   objectCount,
                   @"There should be %d document ids.", objectCount);
    
    NSArray *docIds = [self.datastore getAllDocumentIds];
    for (int i = 0; i < objectCount; i++) {
        NSString *found = docIds[i];
        NSString *expected = [NSString stringWithFormat:@"hello-%04d", i];
        XCTAssertTrue([found isEqualToString:expected],
                      @"Expecting %@ but found %@", expected, found);
    }
    
}

-(void)assertIdAndRevisionAndShallowContentExpected:(CDTDocumentRevision *)expected actual:(CDTDocumentRevision *)actual
{
    XCTAssertEqualObjects([actual docId], [expected docId], @"docIDs don't match");
    XCTAssertEqualObjects([actual revId], [expected revId], @"revIDs don't match");
    
    NSDictionary *expectedDict = expected.body;
    NSDictionary *actualDict = actual.body;
    
    for (NSString *key in [expectedDict keyEnumerator]) {
        XCTAssertNotNil([actualDict objectForKey:key], @"Actual didn't contain key %@", key);
        XCTAssertEqualObjects([actualDict objectForKey:key], [expectedDict objectForKey:key], @"Actual value didn't match expected value");
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
}

-(void)getAllDocuments_compareResultExpected:(NSArray*)expectedDbObjects actual:(NSArray*)result count:(int)count offset:(int)offset
{
    NSUInteger expected = (NSUInteger)count;
    XCTAssertEqual(result.count, expected, @"expectedDbObject count didn't match result count");
    for (int i = 0; i < result.count; i++) {
        CDTDocumentRevision *actual = result[i];
        CDTDocumentRevision *expected = expectedDbObjects[i + offset];
        [self assertIdAndRevisionAndShallowContentExpected:expected actual:actual];
    }
}


#pragma mark - UPDATE tests

- (void)testUpdateDeletedDocumentWithOldRevReturns409
{
    NSError *error = nil;
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{ @"hello" : @"world" } mutableCopy];

    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error);

    error = nil;
    [self.datastore deleteDocumentFromRevision:saved error:&error];
    XCTAssertNil(error);
    error = nil;

    saved.body = [@{ @"hello" : @"world", @"updated" : @(YES) } mutableCopy];
    [self.datastore updateDocumentFromRevision:saved error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(409, error.code);
}

-(void)testUpdateBadDocId
{
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{key1:value1} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];

    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    error = nil;
    rev = [[CDTDocumentRevision alloc] initWithDocId:@"Idonotexist"
                                          revisionId:ob.revId
                                                body:[@{ key2 : value2 } mutableCopy]
                                         attachments:nil];

    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    
    XCTAssertNotNil(error, @"No error when updating document with bad id");
    XCTAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", (long)error.code);
    XCTAssertNil(ob2, @"CDTDocumentRevision object was not nil after update with bad rev");
    
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

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{key1:value1} mutableCopy];
    
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    error = nil;
    rev = [ob copy];
    rev.body = [@{key2:value2} mutableCopy];

    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    // Check new revision
    const NSUInteger expected_count = 1;
    CDTDocumentRevision *retrieved;
    error = nil;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    XCTAssertNil(error, @"Error getting document");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    XCTAssertEqual(retrieved.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(retrieved.body[key2], value2, @"Object from database has wrong data");
    
    // Check we can get old revision
    error = nil;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
    XCTAssertNil(error, @"Error getting document using old rev");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    XCTAssertEqual(retrieved.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(retrieved.body[key1], value1, @"Object from database has wrong data");
    
    
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
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
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
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];

}

-(void)testUpdateWithNilDocumentBody
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSError *error;

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{@"hello":@"world"} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");

    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    error = nil;

    rev = [ob copy];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    rev.body = nil;
#pragma clang diagnostic pop
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNotNil(error, @"No Error updating document with nil document body");
    XCTAssertTrue(error.code == 400, @"Error was not a 400. Found %ld", (long)error.code);
    XCTAssertNil(ob2, @"CDTDocumentRevision object was not nil when updating with nil document body");
    
    NSDictionary *modifiedCount = nil;
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
}

-(void)testMultipleUpdates
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSString *dbPath = [self pathForDBName:self.datastore.name];
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    XCTAssertNotNil(queue, @"FMDatabaseQueue was nil: %@", queue);
    
    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];

    NSError *error;
    int numOfUpdates = 1001;

    NSArray *bodies = [self generateDocuments:numOfUpdates + 1];

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = bodies[0];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    XCTAssertNotNil(ob.docId, @"doc id is nil");
    XCTAssertNotNil(ob.revId, @"rev id is nil");
    
    for(int i = 0; i < numOfUpdates; i++){
        error = nil;
        rev = [ob copy];
        rev.body = bodies[i+1];
        ob = [self.datastore updateDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document. Update Number %d", i);
        XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil. Update Number %d", i);
        
        XCTAssertNotNil(ob.docId, @"doc id is nil");
        XCTAssertNotNil(ob.revId, @"rev id is nil");
    }
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": [[NSNumber alloc] initWithInt:numOfUpdates + 1]};
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    
    MRDatabaseContentChecker *dc =[[MRDatabaseContentChecker alloc] init];
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSError *validationError;
        NSArray *expectedRows = @[
                                  @[@"docId"],
                                  @[ob.docId]
                                  ];
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
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
            NSDictionary *expectedDict = bodies[counter-1];
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
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);

    }];


}


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

-(void)testUpdatingWithUnderscoreDeleteFieldDoesNotDelete
{
    // Create the first revision
    NSString *key1 = @"hello";
    NSString *value1 = @"world";

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{key1:value1} mutableCopy];

    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:nil];
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    // Attempt to update with a _deleted key in the body
    NSString *docId = ob.docId;
    NSString *delkey = @"_deleted";
    NSNumber *delvalue= [NSNumber numberWithBool:YES];
    NSString *key2 = @"hi";
    NSString *value2 = @"adam";
    NSError *error;
    NSDictionary *body2dict =@{key1:value1, key2:value2, delkey:delvalue};
    rev = [ob copy];
    rev.body = [body2dict mutableCopy];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNil(ob2, @"CDTDocumentRevision object was not nil");
    XCTAssertNotNil(error, @"Error wasn't set");
    XCTAssertEqual(error.code, (NSInteger)400, @"Wrong error code");
    XCTAssertEqualObjects([error.userInfo objectForKey:NSLocalizedFailureReasonErrorKey],
                   @"Bodies may not contain _ prefixed fields. Use CDTDocumentRevision properties.", 
                   @"Incorrect error message");
    
    error = nil;
    
    
    //now test the content of docs/revs tables explicitely.
    MRDatabaseContentChecker *dc =[[MRDatabaseContentChecker alloc] init];
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        
        NSError *validationError;
        NSArray *expectedRows = @[
                                  @[@"doc_id", @"docid"],
                                  @[@1,        docId]
                                  ];
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"docs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        
        NSString *revId = @"1-1f7588ca02054efe626a6e440a431861";
        NSData *json = [TDJSON dataWithJSONObject:@{key1: value1} 
                                          options:0 
                                            error:nil];
        NSArray *expectedRows = @[
                                  @[@"doc_id", @"sequence", @"revid", @"current", @"deleted", @"json"],
                                  @[@(1),      @1,          revId,    @YES,        @NO,        json],
                                  ];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
    

    
}

-(void) testUpdateDocumentThroughCDTMutableRevision{
    NSError *error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:@"MyFirstTestDoc"];
    doc.body = [@{@"title":@"Testing New creation API",@"FirstTest":@YES} mutableCopy];
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertTrue(saved, @"Failed to save new document");

    NSMutableDictionary *update = [saved.body mutableCopy];
    [update setObject:@"UpdatedDocValue" forKey:@"UpdatedDoc"];
    saved.body = update;
    CDTDocumentRevision *updated = [self.datastore updateDocumentFromRevision:saved error:&error];
    XCTAssertTrue(updated, @"Object did not update");
}

#pragma mark - DELETE tests

- (void)testDeleteDeletedDocumentWithOldRevReturns409
{
    NSError *error = nil;
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{ @"hello" : @"world" } mutableCopy];

    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error);

    error = nil;
    [self.datastore deleteDocumentFromRevision:saved error:&error];
    XCTAssertNil(error);
    error = nil;

    [self.datastore deleteDocumentFromRevision:saved error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(409, error.code);
}

- (void)testDeletedItem404
{
    NSError *error = nil;

    CDTDocumentRevision *mRev = [CDTDocumentRevision revision];
    mRev.body = [@{@"name": @"Zambia", @"area": @(752614)} mutableCopy];
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mRev error:&error];

    [self.datastore deleteDocumentFromRevision:rev error:&error];

    CDTDocumentRevision *tmp = [self.datastore getDocumentWithId:rev.docId
                                                           error:&error];

    XCTAssertNil(tmp, @"deleted doc returned");
    XCTAssertEqual((NSInteger)404, [error code], @"Wrong error code for deleted item.");
}

- (void)testDeletedFlagOnDocumentRevision
{
    NSError *error = nil;

    CDTDocumentRevision *mRev = [CDTDocumentRevision revision];
    mRev.body = [@{@"name": @"Zambia", @"area": @(752614)} mutableCopy];
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mRev error:&error];

    rev = [self.datastore deleteDocumentFromRevision:rev error:&error];

    CDTDocumentRevision *tmp = [self.datastore getDocumentWithId:rev.docId
                                        rev:rev.revId
                                      error:&error];

    XCTAssertNotNil(tmp, @"Deleted doc not returned when queried with rev ID");
    XCTAssertTrue(tmp.deleted, @"Deleted document was not flagged deleted");
}

-(void)testDeleteDocument
{
    [self.datastore documentCount]; //this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.

    NSMutableDictionary *initialRowCount = [self.dbutil getAllTablesRowCount];
    
    NSError *error;
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{@"hello": @"world"} mutableCopy];

    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    error = nil;
    NSString *docId = ob.docId;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentFromRevision:ob error:&error];
    XCTAssertNil(error, @"Error deleting document: %@", error);
    XCTAssertNotNil(deleted, @"Error deleting document: %@", error);
    
    // Check new revision isn't found
    error = nil;
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    XCTAssertNotNil(error, @"No Error getting deleted document");
    XCTAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", (long)error.code);
    XCTAssertNil(retrieved, @"retrieved object was not nil");
    
    //Now try deleting it again.
    error = nil;
    deleted = [self.datastore deleteDocumentFromRevision:ob error:&error];
    XCTAssertNil(deleted, @"CDTRevsision was not nil on Error deleting document: %@", error);
    XCTAssertNotNil(error, @"No Error trying to delete already deleted document");
    //CouchDB/Cloudant returns 409, But CloudantSync returns a 404.
    //STAssertTrue(error.code == 409, @"Found %@", error);
    
    // Check we can get old revision
    error = nil;
    const NSUInteger expected_count = 1;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
    XCTAssertNil(error, @"Error getting document");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    XCTAssertEqual(retrieved.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(retrieved.body[@"hello"], @"world", @"Object from database has wrong data");
    
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @2};
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    
    //explicit check of docs/revs tables
    __block int doc_id_inDocsTable;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from docs"];
        [result next];
        XCTAssertEqualObjects(docId, [result stringForColumn:@"docid"],@"%@ != %@", docId,[result stringForColumn:@"docid"]);
        doc_id_inDocsTable = [result intForColumn:@"doc_id"];
        XCTAssertFalse([result next], @"There are too many rows in docs");
        [result close];
    }];
    
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from revs"];
        [result next];
        
        NSError *error;
        
        XCTAssertEqual(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        XCTAssertTrue([result intForColumn:@"sequence"] == 1, @"%d", [result intForColumn:@"sequence"]);
        XCTAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 1, @"rev: %@", [result stringForColumn:@"revid"] );
        XCTAssertFalse([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertFalse([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertEqualObjects([result objectForColumnName:@"parent"], [NSNull null], @"Found %@", [result objectForColumnName:@"parent"]);
        NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                   options: TDJSONReadingMutableContainers
                                                     error: &error];
        XCTAssertTrue([jsonDoc isEqualToDictionary:@{@"hello": @"world"}],@"JSON %@. NSError %@", jsonDoc, error);
        
        //next row
        XCTAssertTrue([result next], @"Didn't find the second row in the revs table");
        XCTAssertEqual(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        XCTAssertTrue([result intForColumn:@"sequence"] == 2, @"%d", [result intForColumn:@"sequence"]);
        XCTAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 2, @"rev: %@", [result stringForColumn:@"revid"] );
        XCTAssertTrue([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertTrue([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertTrue([result intForColumn:@"parent"] == 1, @"Found %d",
                      [result intForColumn:@"parent"]);

        // Although TD_Database+Insertion inserts an empty NSData object instead of NSNull on
        // delete,
        // FMDB 2.4+ returns NSNull for empty NSData when reading from the database.
        XCTAssertEqual([result objectForColumnName:@"json"], [NSNull null], @"Found %@",
                       [result objectForColumnName:@"json"]);

        //shouldn't be any more rows.
        XCTAssertFalse([result next], @"There are too many rows in revs");
        XCTAssertNil([result stringForColumn:@"doc_id"], @"after [result next], doc_id is %@", [result stringForColumn:@"doc_id"]);
        XCTAssertNil([result stringForColumn:@"revid"], @"after [result next],  revid is %@", [result stringForColumn:@"revid"]);
        
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
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{@"hello":@"world"} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    //update document
    error = nil;
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    rev = [ob copy];
    rev.body = [@{key2:value2} mutableCopy];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error updating document");
    XCTAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    //delete doc.
    error = nil;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentFromRevision:ob2 error:&error];
    XCTAssertNil(error, @"Error deleting document: %@", error);
    XCTAssertNotNil(deleted, @"Error deleting document: %@", error);
    
    // Check new revision isn't found
    error = nil;
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    XCTAssertNotNil(error, @"No Error getting deleted document");
    XCTAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", (long)error.code);
    XCTAssertNil(retrieved, @"retrieved object was not nil");
    
    // Check we can get the updated revision before it was deleted (ob2)
    error = nil;
    const NSUInteger expected_count = 1;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob2.revId error:&error];
    XCTAssertNil(error, @"Error getting document");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    XCTAssertEqual(retrieved.body.count, expected_count, @"Object from database has != 1 key");
    XCTAssertEqualObjects(retrieved.body[key2], value2, @"Object from database has wrong data");
    
    
    NSDictionary *modifiedCount = @{@"docs": @1, @"revs": @3};
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    
    //explicit check of docs/revs tables
    __block int doc_id_inDocsTable;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from docs"];
        [result next];
        XCTAssertEqualObjects(docId, [result stringForColumn:@"docid"],@"%@ != %@", docId,[result stringForColumn:@"docid"]);
        doc_id_inDocsTable = [result intForColumn:@"doc_id"];
        XCTAssertFalse([result next], @"There are too many rows in docs");
        [result close];
    }];
    
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"select * from revs"];
        [result next];
            
        //initial doc
        XCTAssertEqual(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        XCTAssertTrue([result intForColumn:@"sequence"] == 1, @"%d", [result intForColumn:@"sequence"]);
        XCTAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 1, @"rev: %@", [result stringForColumn:@"revid"] );
        XCTAssertFalse([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertFalse([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"deleted"]);
        XCTAssertEqualObjects([result objectForColumnName:@"parent"], [NSNull null], @"Found %@", [result objectForColumnName:@"parent"]);

        NSError *error;
        NSDictionary* jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                   options: TDJSONReadingMutableContainers
                                                     error: &error];
        XCTAssertTrue([jsonDoc isEqualToDictionary:@{@"hello": @"world"}],@"JSON %@. NSError %@", jsonDoc, error);
        
        //updated doc
        XCTAssertTrue([result next], @"Didn't find the second row in the revs table");
        XCTAssertEqual(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        XCTAssertTrue([result intForColumn:@"sequence"] == 2, @"%d", [result intForColumn:@"sequence"]);
        XCTAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 2, @"rev: %@", [result stringForColumn:@"revid"] );
        XCTAssertFalse([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertFalse([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"deleted"]);
        XCTAssertTrue([result intForColumn:@"parent"] == 1, @"Found %d", [result intForColumn:@"parent"]);
        
        error = nil;
        jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                     options: TDJSONReadingMutableContainers
                                       error: &error];
        XCTAssertTrue([jsonDoc isEqualToDictionary:@{key2: value2}],@"JSON %@. NSError %@", jsonDoc, error);
   
        
        //deleted doc
        XCTAssertTrue([result next], @"Didn't find the third row in the revs table");
        XCTAssertEqual(doc_id_inDocsTable, [result intForColumn:@"doc_id"], @"%d != %d", doc_id_inDocsTable, [result intForColumn:@"doc_id"]);
        XCTAssertTrue([result intForColumn:@"sequence"] == 3, @"%d", [result intForColumn:@"sequence"]);
        XCTAssertTrue([TD_Revision generationFromRevID:[result stringForColumn:@"revid"]] == 3, @"rev: %@", [result stringForColumn:@"revid"] );
        XCTAssertTrue([result boolForColumn:@"current"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertTrue([result boolForColumn:@"deleted"], @"%@", [result stringForColumn:@"current"]);
        XCTAssertTrue([result intForColumn:@"parent"] == 2, @"Found %d", [result intForColumn:@"parent"]);

        // Although TD_Database+Insertion inserts an empty NSData object instead of NSNull on
        // delete,
        // FMDB 2.4+ returns NSNull for empty NSData when reading from the database.
        XCTAssertEqual([result objectForColumnName:@"json"], [NSNull null], @"Found %@",
                       [result objectForColumnName:@"json"]);

        //should be done
        XCTAssertFalse([result next], @"There are too many rows in revs");
        XCTAssertNil([result stringForColumn:@"doc_id"], @"after [result next], doc_id is %@", [result stringForColumn:@"doc_id"]);
        XCTAssertNil([result stringForColumn:@"revid"], @"after [result next],  revid is %@", [result stringForColumn:@"revid"]);
        
        [result close];
    }];

}

-(void)testUpdateDeleteUpdateOldRev
{
    
    //create document rev 1-
    NSError *error;
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{@"hello": @"world"}mutableCopy];

    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    //update document rev 2-
    error = nil;
    NSString *docId = ob.docId;
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    rev = [ob copy];
    rev.body = [@{key2:value2} mutableCopy];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error updating document");
    XCTAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    //delete doc. rev 3-
    error = nil;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentFromRevision:ob2 error:&error];
    XCTAssertNil(error, @"Error deleting document: %@", error);
    XCTAssertNotNil(deleted, @"Error deleting document: %@", error);
    
    // Check new revision isn't found
    error = nil;
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    XCTAssertNotNil(error, @"No Error getting deleted document");
    XCTAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", (long)error.code);
    XCTAssertNil(retrieved, @"retrieved object was not nil");
    
    //now try updating rev 2-
    
    //get update rev 2-
    error = nil;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob2.revId error:&error];
    XCTAssertNil(error, @"Error getting document");
    XCTAssertNotNil(retrieved, @"retrieved object was nil");
    XCTAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    XCTAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    XCTAssertEqualObjects(retrieved.body[key2], value2, @"Object from database has wrong data");
    
    //try updating rev 2-
    error = nil;
    NSString *key3 = @"chew";
    NSString *value3 = @"branca";
    rev = [ob2 copy];
    rev.body = [@{key3:value3} mutableCopy];
    CDTDocumentRevision *ob3 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNotNil(error, @"No Error updating deleted document");
    //inconsitent with error reported by cloudant/couchdb. cloudant/couch returns 409, TD* retunrs 404
//    STAssertTrue(error.code == 409, @"Error was not a 409. Found %ld", error.code);
    XCTAssertNil(ob3, @"retrieved object was not nil");
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
        CDTDocumentRevision *rev;
        rev = [CDTDocumentRevision revisionWithDocId:docId];
        rev.body = bodies[i];
        CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document");
        [dbObjects addObject:ob];
    }
    
    NSMutableArray *deletedDbObjects = [[NSMutableArray alloc] init];
    NSMutableSet *deletedDbDicts = [[NSMutableSet alloc] init];
    NSMutableArray *notDeletedDbObjects = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < objectCount; i++) {
        if(arc4random_uniform(100) < 30) {  //delete ~30% of the docs
            error = nil;
            CDTDocumentRevision *ob = [dbObjects objectAtIndex:i];
            CDTDocumentRevision *deleted = [self.datastore deleteDocumentFromRevision:ob
                                                                                error:&error];

            XCTAssertNotNil(deleted, @"Error deleting document: %@", error);
            [deletedDbObjects addObject:ob];
            [deletedDbDicts addObject:ob.body];
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
            XCTAssertFalse(aDeletedDict == aRev.body, @"Found equal pointers. %@ == %@", aRev.body,
                           aDeletedDict);
            XCTAssertFalse([aDeletedDict isEqualToDictionary:aRev.body], @"Found deleted dictionary in results");
        }
        //is this the same as above?
        XCTAssertNil([deletedDbDicts member:aRev.body], @"Found result in deleted set: %@", aRev.body);
    }

    //get all of the previous revisions of the deleted docs and make sure they are deleted.
    [self.datastore documentCount];
    NSString *dbPath = [self pathForDBName:self.datastore.name];
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    XCTAssertNotNil(queue, @"FMDatabaseQueue was nil: %@", queue);
    
    for(CDTDocumentRevision *aRev in deletedDbObjects){
        NSError *error;
        CDTDocumentRevision *retrieved = [self.datastore getDocumentWithId:aRev.docId rev:aRev.revId error:&error];
        XCTAssertNil(error, @"Error getting retreived doc. %@, %@", aRev.docId, aRev.revId);
        XCTAssertNotNil(retrieved, @"CDTDocumentRevision was nil");
        
        BOOL found = NO;
        for(NSDictionary *aDeletedDict in deletedDbDicts){
            if([aDeletedDict isEqualToDictionary:retrieved.body])
                found = YES;
        }
        XCTAssertTrue(found, @"didn't find %@", aRev.body);
        
        //query the database to ensure it has the proper structure
        [queue inDatabase:^(FMDatabase *db){
            
            FMResultSet *result = [db executeQuery:
                                   @"select * from revs, docs where revs.doc_id = docs.doc_id and docs.docid = (?)", aRev.docId ];
            int count = 0;
            while([result next]){
                count++;
                if(count == 2){
                    XCTAssertTrue([result boolForColumn:@"deleted"], @"not deleted");
                    XCTAssertTrue([result boolForColumn:@"current"], @"this rev is not current");
                }
                else{
                    XCTAssertFalse([result boolForColumn:@"deleted"], @"wrong rev is deleted");
                    XCTAssertFalse([result boolForColumn:@"current"], @"wrong rev is current");
                    NSError *error;
                    NSDictionary *jsonDoc = [TDJSON JSONObjectWithData: [result dataForColumn:@"json"]
                                                 options: TDJSONReadingMutableContainers
                                                   error: &error];
                    XCTAssertTrue([jsonDoc isEqualToDictionary:aRev.body],@"JSON %@. NSError %@", jsonDoc, error);
                }
            }
            XCTAssertTrue(count == 2, @"found more than %d rows", count);
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
        CDTDocumentRevision *rev;
        rev = [CDTDocumentRevision revisionWithDocId:docId];
        rev.body = bodies[i];
        CDTDocumentRevision *aRev = [self.datastore createDocumentFromRevision:rev error:&error];
        XCTAssertNil(error, @"Error creating document");
        [dbObjects addObject:aRev];
    }
    
    NSDictionary *modifiedCount = @{@"docs": [NSNumber numberWithInt:objectCount], @"revs": [NSNumber numberWithInt:objectCount]};
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:modifiedCount];
    initialRowCount = [self.dbutil getAllTablesRowCount];
    
    error = nil;
    NSString *docId = @"idonotexist";
    CDTDocumentRevision *aRev = [self.datastore getDocumentWithId:docId error:&error ];
    XCTAssertNotNil(error, @"No Error getting document that doesn't exist");
    XCTAssertTrue(error.code == 404, @"Error was not a 404. Found %ld", (long)error.code);
    XCTAssertNil(aRev, @"CDTDocumentRevision should be nil after getting document that doesn't exist");
    
    error = nil;
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentFromRevision:aRev error:&error];
    XCTAssertNotNil(error, @"No Error deleting document that doesn't exist");
    XCTAssertTrue(error.code == 400, @"Error was not a 400. Found %ld", (long)error.code);
    XCTAssertNil(deleted, @"CDTDocumentRevision* was not nil. Deletion successful?: %@", error);
    
    
    [self.dbutil checkTableRowCount:initialRowCount modifiedBy:nil];
    
}

-(void)testDeleteUsingCDTDocumentRevision
{
    NSError * error;
    CDTDocumentRevision *doc = [CDTDocumentRevision revisionWithDocId:@"MyFirstTestDoc"];
    doc.body = [@{@"title":@"Testing New creation API",@"FirstTest":@YES} mutableCopy];
    CDTDocumentRevision *saved = [self.datastore createDocumentFromRevision:doc error:&error];
    XCTAssertTrue(saved, @"Failed to save new document");
    
    CDTDocumentRevision *deleted = [self.datastore deleteDocumentFromRevision:saved error:&error];
    XCTAssertTrue(deleted && deleted.deleted, @"Document was not deleted");
}

-(void) testDeleteDocumentUsingIdHasMultipleLeafNodesInTree
{
    NSError * error;
    CDTDocumentRevision *mutableRev;
    mutableRev = [CDTDocumentRevision revisionWithDocId:@"aTestDocId"];
    mutableRev.body = [@{ @"hello" : @"world" } mutableCopy];

    CDTDocumentRevision * rev = [self.datastore createDocumentFromRevision:mutableRev error:&error];
    
    XCTAssertNotNil(rev, @"Document was not created");

    NSMutableDictionary *body = [rev.body mutableCopy];
    [body setObject:@"objc" forKey:@"writtenIn"];
    rev.body = body;

    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev2, @"Failed performing update");
    
    //now need to force insert into the DB little messy though

    [body setObject:@"conflictedinsert" forKey:@"conflictedkeyconflicted"];

    //borrow conversion code from update then do force insert
    
    TD_Revision *converted = [[TD_Revision alloc]initWithDocID:rev.docId
                                                         revID:rev.revId
                                                       deleted:rev.deleted];
    converted.body = [[TD_Body alloc] initWithProperties:body];

    TDStatus status;

    [self.datastore.database putRevision:converted
                          prevRevisionID:rev.revId
                           allowConflict:YES
                                  status:&status];

    NSArray * deleted = [self.datastore deleteDocumentWithId:mutableRev.docId error:&error];
    
    XCTAssertTrue([deleted count] == 2, @"Number of deletions do not match");
    
}

#pragma mark - Other Tests

-(void)testCompactSingleDoc
{
    NSError *error;
    NSString *key1 = @"hello";
    NSString *value1 = @"world";

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{key1:value1} mutableCopy];
    CDTDocumentRevision *ob = [self.datastore createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error creating document");
    XCTAssertNotNil(ob, @"CDTDocumentRevision object was nil");
    
    NSString *key2 = @"hi";
    NSString *value2 = @"mike";
    error = nil;
    rev = [ob copy];
    rev.body = [@{key2:value2} mutableCopy];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentFromRevision:rev error:&error];
    XCTAssertNil(error, @"Error updating document");
    XCTAssertNotNil(ob2, @"CDTDocumentRevision object was nil");
    
    TDStatus statusResults = [self.datastore.database compact];
    XCTAssertTrue([TDStatusToNSError( statusResults, nil) code] == 200, @"TDStatusAsNSError: %@", TDStatusToNSError( statusResults, nil));
    
}
@end
