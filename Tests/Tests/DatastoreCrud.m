//
//  DatastoreCrud.m
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "DatastoreCrud.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"

@implementation DatastoreCrud

- (void)setUp
{
    [super setUp];
    
    self.datastore = [self.factory datastoreNamed:@"test"];
    
    STAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.
    
    self.datastore = nil;
    
    [super tearDown];
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
    STAssertNotNil(ob, @"Datastore object was nil");
    STAssertEqualObjects(@"document_id_for_test", ob.docId, @"Document ID was not as set in test");
    
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

-(void)testGetDocument
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"Datastore object was nil");
    
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
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world", @"index": [NSNumber numberWithInt:i]}];
        CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
        STAssertNil(error, @"Error creating document");
        
        NSString *docId = ob.docId;
        [docIds addObject:docId];
    }
    
    NSArray *retrivedDocIds = @[docIds[5], docIds[7], docIds[12], docIds[170]];
    NSArray *obs = [self.datastore getDocumentsWithIds:retrivedDocIds error:&error];
    STAssertNil(error, @"Error getting documents");
    
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

-(void)testUpdatingSingleDocument
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"Datastore object was nil");
    
    NSString *docId = ob.docId;
    
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{@"hi": @"mike"}];
    CDTDocumentRevision *ob2 = [self.datastore updateDocumentWithId:docId
                                                            prevRev:ob.revId
                                                               body:body2
                                                              error:&error];
    STAssertNil(error, @"Error updating document");
    STAssertNotNil(ob2, @"Datastore object was nil");
    
    // Check new revision
    const NSUInteger expected_count = 1;
    CDTDocumentRevision *retrieved;
    
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    STAssertNil(error, @"Error getting document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob2.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[@"hi"], @"mike", @"Object from database has wrong data");
    
    // Check we can get old revision
    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
    STAssertNil(error, @"Error getting document using old rev");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)testDeleteDocument
{
    NSError *error;
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *ob = [self.datastore createDocumentWithBody:body error:&error];
    STAssertNil(error, @"Error creating document");
    STAssertNotNil(ob, @"Datastore object was nil");
    
    NSString *docId = ob.docId;
    Boolean deleted = [self.datastore deleteDocumentWithId:docId
                                                       rev:ob.revId
                                                     error:&error];
    STAssertNil(error, @"Error deleting document");
    STAssertTrue(deleted, @"Object wasn't deleted successfully");
    
    // Check new revision isn't found
    CDTDocumentRevision *retrieved;
    retrieved = [self.datastore getDocumentWithId:docId error:&error];
    STAssertNotNil(error, @"Error getting document");
    STAssertNil(retrieved, @"retrieved object was nil");
    
    error = nil;
    
    // Check we can get old revision
    const NSUInteger expected_count = 1;
    retrieved = [self.datastore getDocumentWithId:docId rev:ob.revId error:&error];
    STAssertNil(error, @"Error getting document");
    STAssertNotNil(retrieved, @"retrieved object was nil");
    STAssertEqualObjects(ob.docId, retrieved.docId, @"Object retrieved from database has wrong docid");
    STAssertEqualObjects(ob.revId, retrieved.revId, @"Object retrieved from database has wrong revid");
    STAssertEquals(retrieved.documentAsDictionary.count, expected_count, @"Object from database has != 1 key");
    STAssertEqualObjects(retrieved.documentAsDictionary[@"hello"], @"world", @"Object from database has wrong data");
}

-(void)test_getAllDocumentsOffsetLimitDescending
{
    NSError *error;
    int objectCount = 100;
    NSArray *bodies = [self generateDocuments:objectCount];
    NSMutableArray *dbObjects = [NSMutableArray arrayWithCapacity:objectCount];
    for (int i = 0; i < objectCount; i++) {
        // Results will be ordered by docId, so give an orderable ID.
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

@end
