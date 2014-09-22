//
//  IndexManagerTests.m
//  Tests
//
//  Created by Thomas Blench on 27/01/2014.
//
//

#import "IndexManagerTests.h"
#import "CDTIndexManager.h"
#import "CDTDocumentBody.h"
#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"
#import "CDTDocumentRevision.h"

#import "TD_Revision.h"
#import "TD_Body.h"


@implementation IndexManagerTests

#pragma mark Tests

- (void)testCreateIndexManager
{
    NSError *err = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&err];
    STAssertNotNil(im, @"indexManager is nil");
}

- (void)testAddFieldIndex
{
    NSError *err = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&err];

    BOOL ok = [im ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&err];
    STAssertTrue(ok, @"ensureIndexedWithIndexName did not return true");
    STAssertNil(err, @"error is not nil");
}

- (void)testAddInvalidFieldIndex
{
    NSError *err = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&err];

    BOOL ok = [im ensureIndexedWithIndexName:@"abc123^&*^&%^^*^&(; drop table customer;" fieldName:@"name" error:&err];
    STAssertFalse(ok, @"ensureIndexedWithIndexName did not return false");
    STAssertNotNil(err, @"error is nil");
}


- (void)testAddSameFieldIndexTwice
{
    NSError *err = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&err];

    NSError *error1 = nil;
    BOOL ok1 = [im ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error1];
    STAssertTrue(ok1, @"ensureIndexedWithIndexName did not return true");
    STAssertNil(error1, @"error is not nil");

    NSError *error2 = nil;
    BOOL ok2 = [im ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error2];
    STAssertFalse(ok2, @"ensureIndexedWithIndexName did not return false");
    STAssertNotNil(error2, @"error is nil");
}

- (void)testDeleteNonexistantIndex
{
    NSError *err = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&err];

    BOOL ok = [im deleteIndexWithIndexName:@"index1" error:&err];
    STAssertFalse(ok, @"ensureIndexedWithIndexName did not return false");
    STAssertNotNil(err, @"error is nil");
}

- (void)testIndexSomeDocuments
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    int nDocs = 1000;
    while(nDocs--) {
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"tom"}];
        [self.datastore createDocumentWithBody:body error:&error];
    }

    NSError *error1 = nil;
    BOOL ok1 = [im ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error1];
    STAssertTrue(ok1, @"ensureIndexedWithIndexName did not return true");
    STAssertNil(error1, @"error is not nil");
}

- (void)testIndexSomeDocumentsWithUpdate
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    int nDocs = 1000;
    while(nDocs--) {
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"tom"}];
        [self.datastore createDocumentWithBody:body error:&error];
    }

    NSError *error1 = nil;
    BOOL ok1 = [im ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error1];
    STAssertTrue(ok1, @"ensureIndexedWithIndexName did not return true");
    STAssertNil(error1, @"error is not nil");

    // create some more docs after creating index
    nDocs = 1000;
    while(nDocs--) {
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"bill"}];
        [self.datastore createDocumentWithBody:body error:&error];
    }

    CDTQueryResult *res1 = [im queryWithDictionary:@{@"index1":@"tom"} error:&error];
    CDTQueryResult *res2 = [im queryWithDictionary:@{@"index1":@"bill"} error:&error];

    unsigned long count1 = [[res1 documentIds] count];
    unsigned long count2 = [[res2 documentIds] count];

    STAssertEquals(count1, 1000UL, @"Query should return 1000 documents");
    STAssertEquals(count2, 1000UL, @"Query should return 1000 documents");
}

- (void)testIndexSingleCriteria
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs

    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Tom", @"surname": @"Blench"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"William", @"surname": @"Blench"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Tom", @"surname": @"Smith"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"David", @"surname": @"Jones"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Tom", @"surname": @"Jones"}]
                                     error:&error];

    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:&error];
    [im ensureIndexedWithIndexName:@"surname" fieldName:@"surname" error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"name":@"Tom"} error:&error];
    unsigned long count = [[res documentIds] count];
    STAssertEquals(count, 3UL, @"Query should return 3 documents");
}

- (void)testIndexMultipleCriteria
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs

    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Tom", @"surname": @"Blench"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"William", @"surname": @"Blench"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Tom", @"surname": @"Smith"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"David", @"surname": @"Jones"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Tom", @"surname": @"Jones"}]
                                     error:&error];

    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:&error];
    [im ensureIndexedWithIndexName:@"surname" fieldName:@"surname" error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"name":@"Tom",@"surname":@"Blench"} error:&error];
    STAssertEquals([[res documentIds] count], (NSUInteger)1, @"Query should return 1 document");
}


- (void)ignored_testIndexQueryPerformance
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    int nDocs = 25600;
    while(nDocs--) {
        if (nDocs % 1000 == 0) {printf(".");}
        NSString *foods[4];
        for (int i=0; i<4; i++) {
            switch(lrand48() % 4) {
                case 0:
                    foods[i] = @"bacon";
                    break;
                case 1:
                    foods[i] = @"ham";
                    break;
                case 2:
                    foods[i] = @"eggs";
                    break;
                case 3:
                    foods[i] = @"brie";
                    break;
            }
        }

        [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"breakfast": foods[0], @"elevenses": foods[1], @"lunch": foods[2], @"dinner": foods[3]}] error:&error];
    }

//    NSLog(@"start index");
    [im ensureIndexedWithIndexName:@"breakfast" fieldName:@"breakfast" error:&error];
    [im ensureIndexedWithIndexName:@"elevenses" fieldName:@"elevenses" error:&error];
    [im ensureIndexedWithIndexName:@"lunch" fieldName:@"lunch" error:&error];
    [im ensureIndexedWithIndexName:@"dinner" fieldName:@"dinner" error:&error];
//    NSLog(@"end index");

    CDTQueryResult *res = [im queryWithDictionary:@{@"breakfast":@"bacon",@"elevenses":@"ham",@"lunch":@"eggs",@"dinner":@"brie"} error:&error];

//    NSLog(@"end query");
    unsigned long count=[[res documentIds] count];
    // NB this is dependent on lrand48 implementation
    STAssertEquals(count, 98UL, @"Query should return 98 documents");
}

- (void)testResultEnumerator
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    int nDocs = 161;
    for(int i=0; i<nDocs; i++) {
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"tom"}];
        [self.datastore createDocumentWithBody:body error:&error];
    }

    NSError *error1 = nil;
    BOOL ok1 = [im ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error1];
    STAssertTrue(ok1, @"ensureIndexedWithIndexName did not return true");
    STAssertNil(error1, @"error is not nil");

    CDTQueryResult *res = [im queryWithDictionary:@{@"index1":@"tom"} error:&error];

    // helper fn countResults is a for loop which tests enumerator
    int count=[self countResults:res];
    STAssertEquals(count, nDocs, @"counts not equal");
}

- (void)testCreateAndDeleteIndex
{
    NSError *error = nil;
    NSError *error1 = nil;
    NSError *error2 = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:&error1];
    [im deleteIndexWithIndexName:@"name" error:&error2];

    STAssertNil(error1, @"ensureIndexedWithIndexName should not return error");
    STAssertNil(error2, @"deleteIndexWithIndexName should not return error");
}

- (void)test2IndexManagers
{
    NSError *error = nil;

    // check that we re-use the existing schema, tables, etc
    {
        CDTIndexManager *im1 = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

        NSError *error1 = nil;
        BOOL ok1 = [im1 ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error1];
        STAssertTrue(ok1, @"ensureIndexedWithIndexName did not return true");
        STAssertNil(error1, @"error is not nil");
    }

    {
        CDTIndexManager *im2 = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

        NSError *error2 = nil;
        BOOL ok2 = [im2 ensureIndexedWithIndexName:@"index1" fieldName:@"name" error:&error2];
        STAssertTrue(ok2, @"ensureIndexedWithIndexName did not return true");
        STAssertNil(error2, @"error is not nil");
    }
}

- (void)testCustomIndexers
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs

    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"animal": @"elephant"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"animal": @"two-toed sloth"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"animal": @"aardvark"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"animal": @"cat"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"animal": @"dog"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"animal": @"duck-billed platypus"}]
                                     error:&error];

    CDTTestIndexer1 *indexer = [[CDTTestIndexer1 alloc] init];

    [im ensureIndexedWithIndexName:@"animal" type:CDTIndexTypeString indexer:indexer error:&error];

    CDTQueryResult *res1 = [im queryWithDictionary:@{@"animal":@"du"} error:&error];
    CDTQueryResult *res2 = [im queryWithDictionary:@{@"animal":@"d"} error:&error];

    unsigned long count1=[[res1 documentIds] count];
    unsigned long count2=[[res2 documentIds] count];

    STAssertEquals(count1, 1UL, @"Query for prefix 'd' should return 1 document");

    STAssertEquals(count2, 2UL, @"Query for prefix 'du' should return 2 documents");
}

- (void)testNumericIndexers
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs

    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"one", @"numeral": @"1"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"eins", @"numeral": @"1"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"一", @"numeral": @"1"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"two", @"numeral": @"2"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"ニ", @"numeral": @"2"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"three", @"numeral": @"3"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"four", @"numeral": @"4"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"five", @"numeral": @"5"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"six", @"numeral": @"6"}]
                                     error:&error];

    [im ensureIndexedWithIndexName:@"numeral" fieldName:@"numeral" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res1 = [im queryWithDictionary:@{@"numeral":@1} error:&error];
    CDTQueryResult *res2 = [im queryWithDictionary:@{@"numeral":@{@"min":@2}} error:&error];

    unsigned long count1=[[res1 documentIds] count];
    unsigned long count2=[[res2 documentIds] count];

    STAssertEquals(count1, 3UL, @"Didn't get expected number of results");
    STAssertEquals(count2, 6UL, @"Didn't get expected number of results");
}

- (void)testUniqueValues
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs

    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"one", @"numeral": @"1"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"eins", @"numeral": @"1"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"一", @"numeral": @"1"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"two", @"numeral": @"2"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"ニ", @"numeral": @"2"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"three", @"numeral": @"3"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"four", @"numeral": @"4"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"five", @"numeral": @"5"}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"six", @"numeral": @"6"}]
                                     error:&error];

    [im ensureIndexedWithIndexName:@"number" fieldName:@"number" type:CDTIndexTypeString error:&error];
    [im ensureIndexedWithIndexName:@"numeral" fieldName:@"numeral" type:CDTIndexTypeInteger error:&error];

    NSArray *res1 = [im uniqueValuesForIndex:@"numeral" error:&error];
    NSArray *res2 = [im uniqueValuesForIndex:@"number" error:&error];

    unsigned long count1=[res1 count];
    unsigned long count2=[res2 count];

    STAssertEquals(count1, 6UL, @"Didn't get expected number of results");
    STAssertEquals(count2, 9UL, @"Didn't get expected number of results");
}

- (void)testComplexQuery
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    [self initLotsOfData];

    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:&error];
    [im ensureIndexedWithIndexName:@"area" fieldName:@"area" type:CDTIndexTypeInteger error:&error];
    [im ensureIndexedWithIndexName:@"elec_consumption" fieldName:@"elec_consumption" type:CDTIndexTypeInteger error:&error];
    [im ensureIndexedWithIndexName:@"population" fieldName:@"population" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"name":@[@"Afghanistan", @"Albania", @"Algeria", @"American Samoa"],
                                                     @"elec_consumption": @{@"min": @(652200000)},
                                                     @"population": @{@"max": @(3563112)},
                                                     @"area": @{@"min": @(200), @"max": @(2381740)}
                                                     }
                                            error:&error];

    unsigned long count=[[res documentIds] count];
    STAssertEquals(count, 1UL, @"Didn't get expected number of results");
}

- (void)testOrderQuery1
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    [self initLotsOfData];

    [im ensureIndexedWithIndexName:@"area" fieldName:@"area" type:CDTIndexTypeInteger error:&error];
    [im ensureIndexedWithIndexName:@"population" fieldName:@"population" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"population": @{@"max": @(100000000)}}
                                          options:@{kCDTQueryOptionSortBy: @"area", kCDTQueryOptionDescending: @(YES)}
                                            error:&error];
    int lastVal = 100000000;

    STAssertTrue([[res documentIds] count] > 0, @"Query yielded nothing!");

    for(CDTDocumentRevision *doc in res) {
        NSNumber *val = [[doc body] objectForKey:@"area"];
        int valInt = [val intValue];
        STAssertTrue(valInt <= lastVal, @"Not sorted");
        lastVal = valInt;
    }
}

- (void)testOrderQuery2
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    [self initLotsOfData];

    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" type:CDTIndexTypeString error:&error];
    [im ensureIndexedWithIndexName:@"population" fieldName:@"population" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"population": @{@"min": @(10000000)}}
                                          options:@{kCDTQueryOptionSortBy: @"name", kCDTQueryOptionDescending: @(YES)}
                                            error:&error];
    NSString *lastName = @"Zzzzzzzzistan"; // probably the last country in the alphabet

    STAssertTrue([[res documentIds] count] > 0, @"Query yielded nothing!");

    for(CDTDocumentRevision *doc in res) {
        NSString *val = [[doc body] objectForKey:@"name"];

        STAssertTrue([val compare:lastName] < 0, @"Not sorted correctly");
        lastName = val;
    }
}


- (void)testOffsetLimitQuery
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // create some docs
    [self initLotsOfData];

    [im ensureIndexedWithIndexName:@"area" fieldName:@"area" type:CDTIndexTypeInteger error:&error];

    // this will give 194 in total
    NSDictionary *query = @{@"area": @{@"min": @(200), @"max": @(2381740)}};

    CDTQueryResult *res1 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionLimit: @(10)}
                                             error:&error];
    CDTQueryResult *res2 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionOffset: @(190), kCDTQueryOptionLimit: @(10)}
                                             error:&error];
    CDTQueryResult *res3 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionOffset: @(193), kCDTQueryOptionLimit: @(1)}
                                             error:&error];
    CDTQueryResult *res4 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionOffset: @(194), kCDTQueryOptionLimit: @(10)}
                                             error:&error];
    CDTQueryResult *res5 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionOffset: @(200), kCDTQueryOptionLimit: @(100)}
                                             error:&error];
    CDTQueryResult *res6 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionOffset: @(10)}
                                             error:&error];
    CDTQueryResult *res7 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionOffset: @(-1)}
                                             error:&error];
    CDTQueryResult *res8 = [im queryWithDictionary:query
                                           options:@{kCDTQueryOptionLimit: @(-1)}
                                             error:&error];

    unsigned long count1=[[res1 documentIds] count];
    unsigned long count2=[[res2 documentIds] count];
    unsigned long count3=[[res3 documentIds] count];
    unsigned long count4=[[res4 documentIds] count];
    unsigned long count5=[[res5 documentIds] count];
    unsigned long count6=[[res6 documentIds] count];
    unsigned long count7=[[res7 documentIds] count];
    unsigned long count8=[[res8 documentIds] count];

    STAssertEquals(count1, 10UL, @"Didn't get expected number of results");
    STAssertEquals(count2, 4UL, @"Didn't get expected number of results");
    STAssertEquals(count3, 1UL, @"Didn't get expected number of results");
    STAssertEquals(count4, 0UL, @"Didn't get expected number of results");
    STAssertEquals(count5, 0UL, @"Didn't get expected number of results");
    STAssertEquals(count6, 184UL, @"Didn't get expected number of results");
    STAssertEquals(count7, 194UL, @"Didn't get expected number of results");
    STAssertEquals(count8, 0UL, @"Didn't get expected number of results");
}

- (void)testQueryError1
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    [im ensureIndexedWithIndexName:@"index1" fieldName:@"index1" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"index2": @"value"}
                                            error:&error];

    STAssertEquals([error code], CDTIndexErrorIndexDoesNotExist, @"Did not get CDTIndexErrorIndexDoesNotExist error");
    STAssertNil(res, @"Result was not nil");
}

- (void)testQueryError2
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    [im ensureIndexedWithIndexName:@"index1" fieldName:@"index1" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"abc123^&*^&%^^*^&(; drop table customer": @"value"}
                                            error:&error];

    STAssertEquals([error code], CDTIndexErrorInvalidIndexName, @"Did not get CDTIndexErrorInvalidIndexName error");
    STAssertNil(res, @"Result was not nil");
}

- (void)testQueryError3
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    [im ensureIndexedWithIndexName:@"index1" fieldName:@"index1" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"index1": @"value"}
                                          options:@{kCDTQueryOptionSortBy: @"index2"}
                                            error:&error];

    STAssertEquals([error code], CDTIndexErrorIndexDoesNotExist, @"Did not get CDTIndexErrorIndexDoesNotExist error");
    STAssertNil(res, @"Result was not nil");
}

- (void)testQueryError4
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    [im ensureIndexedWithIndexName:@"index1" fieldName:@"index1" type:CDTIndexTypeInteger error:&error];

    CDTQueryResult *res = [im queryWithDictionary:@{@"index1": @"value"}
                                          options:@{kCDTQueryOptionSortBy: @"abc123^&*^&%^^*^&(; drop table customer"}
                                            error:&error];

    STAssertEquals([error code], CDTIndexErrorInvalidIndexName, @"Did not get CDTIndexErrorInvalidIndexName error");
    STAssertNil(res, @"Result was not nil");
}

- (void)testIndexerTypes
{
    NSError *error = nil;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"string": @"Ipsem lorem",
                                                                                         @"number": @1,
                                                                                         @"list": @[@"a",@"b",@"c"],
                                                                                         @"dictionary": @{@"key":@"val"}}]
                                     error:&error];
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"number": @"2"}]
                                     error:&error];

    [im ensureIndexedWithIndexName:@"string" fieldName:@"string" type:CDTIndexTypeString error:&error];
    [im ensureIndexedWithIndexName:@"number" fieldName:@"number" type:CDTIndexTypeInteger error:&error];
    [im ensureIndexedWithIndexName:@"list" fieldName:@"list" type:CDTIndexTypeString error:&error];
    [im ensureIndexedWithIndexName:@"dictionary" fieldName:@"dictionary" type:CDTIndexTypeString error:&error];
    [im ensureIndexedWithIndexName:@"stringAsInt" fieldName:@"string" type:CDTIndexTypeInteger error:&error];

    // standard string query
    CDTQueryResult *res1 = [im queryWithDictionary:@{@"string": @"Ipsem lorem"}
                                            error:&error];
    STAssertNil(error, @"Error was not nil");
    STAssertEquals([[res1 documentIds] count], (NSUInteger)1, @"Didn't get expected number of results");

    // test that "2" converts to string
    CDTQueryResult *res2 = [im queryWithDictionary:@{@"number": @[@1,@2]}
                                             error:&error];
    STAssertNil(error, @"Error was not nil");
    STAssertEquals([[res2 documentIds] count], (NSUInteger)2, @"Didn't get expected number of results");

    // test that array indexed correctly
    CDTQueryResult *res3 = [im queryWithDictionary:@{@"list": @[@"a",@"b",@"d"]}
                                             error:&error];
    STAssertNil(error, @"Error was not nil");
    STAssertEquals([[res3 documentIds] count], (NSUInteger)2, @"Didn't get expected number of results");

    // nothing should be indexed for a dictionary
    NSArray *res4 = [im uniqueValuesForIndex:@"dictionary" error:&error];
    STAssertNil(error, @"Error was not nil");
    STAssertEquals([res4 count], (NSUInteger)0, @"Didn't get expected number of results");

    // nothing should be indexed since we can't convert string to int
    NSArray *res5 = [im uniqueValuesForIndex:@"stringAsInt" error:&error];
    STAssertNil(error, @"Error was not nil");
    STAssertEquals([res5 count], (NSUInteger)0, @"Didn't get expected number of results");
}

- (void)testQueryingForDeletedItem
{
    NSError *error = nil;
    int count;

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];

    // A matching result
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Zambia", @"area": @(752614)}]
                                                                error:&error];

    // A second matching result
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Zambia", @"area": @(12345)}]
                                                                error:&error];

    // A non-matching result
    [self.datastore createDocumentWithBody:[[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"Zimbabwe", @"area": @(390580)}]
                                     error:&error];

    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:&error];

    error = nil;
    for (CDTDocumentRevision *rev in [im queryWithDictionary:@{@"name": @"Zambia"} error:&error]) {
        // do nothing
    }

    // As of 0.0.4, querying for a deleted item crashed during the forin loop
    [self.datastore deleteDocumentWithId:rev.docId
                                     rev:rev.revId
                                   error:&error];

    count = 0;
    for (CDTDocumentRevision *result in [im queryWithDictionary:@{@"name": @"Zambia"} error:&error]) {
        // Check we don't get a deleted document
        STAssertFalse(result.deleted, @"Query returned deleted document");
        count++;
    }
    STAssertEquals(count, 1, @"Query returned the wrong number of results");
}

- (void)testIndexManagerConcurrentUpdated
{
    int nThreads = 5;
    NSMutableArray *threads = [[NSMutableArray alloc] init];

    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:nil];
    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:nil];

    while(nThreads-- > 0) {
        NSThread *thr = [[NSThread alloc] initWithTarget:self selector:@selector(makeSomeDocuments:) object:[NSNumber numberWithInt:nThreads]];
        [threads addObject:thr];
        [thr start];
    }
    for (NSThread *thr in threads) {
        while([thr isExecuting]) {
            usleep(500*1000);
        }
    }
    STAssertEquals([[[im queryWithDictionary:@{@"name": @"made in thread"} error:nil] documentIds] count], (NSUInteger)500, @"Query returned the wrong number of results");
}


/** Here we want to make sure that ensureIndexed picks up documents added in a new session
 for an index that was defined in a previous session, when ensureIndexed is called.
 */
- (void)testNewIndexManagerPicksUpDocumentsAddedBeforeEnsureIndexedDuringQuery
{
    int resultCount = 0;
    NSObject *_;
    CDTDatastore *datastore;

    NSString *factoryPath = [self createTemporaryDirectoryAndReturnPath];
    CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:nil];

    NSString *name = [@"test_newIndexManagerPicksUpDocumentsAddedBeforeEnsureIndexedDuringQuery" lowercaseString];
    datastore = [factory datastoreNamed:name error:nil];

    // Create and index a single document
    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:datastore error:nil];
    [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:nil];

    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"mike"}];
    STAssertNotNil([datastore createDocumentWithBody:body error:nil], @"Doc not created");

    resultCount = 0;
    CDTQueryResult *result = [im queryWithDictionary:@{@"name": @"mike"}
                                               error:nil];
    for (_ in result) { resultCount++; }
    STAssertEquals(resultCount, 1, @"Query didn't find the document");

    // Tear down the original datastore objects
    [im shutdown];

    // Fire up a new indexManager without the objects
    CDTIndexManager *im2 = [[CDTIndexManager alloc] initWithDatastore:datastore error:nil];

    STAssertNotNil([datastore createDocumentWithBody:body error:nil], @"Doc not created");

    [im2 ensureIndexedWithIndexName:@"name" fieldName:@"name" error:nil];

    body = [[CDTDocumentBody alloc] initWithDictionary:@{@"name": @"fred"}];
    STAssertNotNil([datastore createDocumentWithBody:body error:nil], @"Doc not created");

    resultCount = 0;
    result = [im2 queryWithDictionary:@{@"name": @"mike"}
                                error:nil];
    for (_ in result) { resultCount++; }
    STAssertEquals(resultCount, 2, @"Query didn't find the document");

    resultCount = 0;
    result = [im2 queryWithDictionary:@{@"name": @"fred"}
                                error:nil];
    for (_ in result) { resultCount++; }
    STAssertEquals(resultCount, 1, @"Query didn't find the document");

    // Still broken even if we updateAllIndexes
    [im2 updateAllIndexes:nil];

    resultCount = 0;
    result = [im2 queryWithDictionary:@{@"name": @"mike"}
                                error:nil];
    for (_ in result) { resultCount++; }
    STAssertEquals(resultCount, 2, @"Query didn't find the document");


    [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:nil];
}

#pragma mark Supporting methods

- (void)makeSomeDocuments:(NSNumber*)thread {
//    NSLog(@"makedocs %d", [thread intValue]);
    int i = 100;
    while (i-- > 0) {
        [self.datastore createDocumentWithBody:
         [[CDTDocumentBody alloc] initWithDictionary:
          @{@"name": @"made in thread",
            @"myDocumentId":[NSString stringWithFormat:@"%d-%d", [thread intValue], i]}
          ] error:nil];
    }
}

- (void)initLotsOfData
{
    NSError *error = nil;

    NSArray *array = @[
                       @{@"name": @"Afghanistan", @"area": @(647500), @"elec_consumption": @(652200000),  @"population": @(29928987)},
                       @{@"name": @"Albania",     @"area": @(28748),  @"elec_consumption": @(6760000000), @"population": @(3563112)},
                       @{@"name": @"Algeria",     @"area": @(2381740),@"elec_consumption": @(23610000000),@"population": @(32531853)},
                       @{@"name": @"American Samoa", @"area": @(199), @"elec_consumption": @(120900000),  @"population": @(57881)},
                       @{@"name": @"Angola", @"area": @(1246700), @"elec_consumption": @(1587000000), @"population": @(11190786)},
                       @{@"name": @"Anguilla", @"area": @(102), @"elec_consumption": @(42600000), @"population": @(13254)},
                       @{@"name": @"Antigua and Barbuda", @"area": @(443), @"elec_consumption": @(103000000), @"population": @(68722)},
                       @{@"name": @"Argentina", @"area": @(2766890), @"elec_consumption": @(81650000000), @"population": @(39537943)},
                       @{@"name": @"Armenia", @"area": @(29800), @"elec_consumption": @(5797000000), @"population": @(2982904)},
                       @{@"name": @"Aruba", @"area": @(193), @"elec_consumption": @(751200000), @"population": @(71566)},
                       @{@"name": @"Australia", @"area": @(7686850), @"elec_consumption": @(195600000000), @"population": @(20090437)},
                       @{@"name": @"Austria", @"area": @(83870), @"elec_consumption": @(55090000000), @"population": @(8184691)},
                       @{@"name": @"Azerbaijan", @"area": @(86600), @"elec_consumption": @(17370000000), @"population": @(7911974)},
                       @{@"name": @"Bahamas The", @"area": @(13940), @"elec_consumption": @(1596000000), @"population": @(301790)},
                       @{@"name": @"Bahrain", @"area": @(665), @"elec_consumption": @(6379000000), @"population": @(688345)},
                       @{@"name": @"Bangladesh", @"area": @(144000), @"elec_consumption": @(15300000000), @"population": @(144319628)},
                       @{@"name": @"Barbados", @"area": @(431), @"elec_consumption": @(744000000), @"population": @(279254)},
                       @{@"name": @"Belarus", @"area": @(207600), @"elec_consumption": @(34300000000), @"population": @(10300483)},
                       @{@"name": @"Belgium", @"area": @(30528), @"elec_consumption": @(78820000000), @"population": @(10364388)},
                       @{@"name": @"Belize", @"area": @(22966), @"elec_consumption": @(108800000), @"population": @(279457)},
                       @{@"name": @"Benin", @"area": @(112620), @"elec_consumption": @(565200000), @"population": @(7460025)},
                       @{@"name": @"Bermuda", @"area": @(53), @"elec_consumption": @(598000000), @"population": @(65365)},
                       @{@"name": @"Bhutan", @"area": @(47000), @"elec_consumption": @(312900000), @"population": @(2232291)},
                       @{@"name": @"Bolivia", @"area": @(1098580), @"elec_consumption": @(3848000000), @"population": @(8857870)},
                       @{@"name": @"Bosnia and Herzegovina", @"area": @(51129), @"elec_consumption": @(8318000000), @"population": @(4025476)},
                       @{@"name": @"Botswana", @"area": @(600370), @"elec_consumption": @(1890000000), @"population": @(1640115)},
                       @{@"name": @"Brazil", @"area": @(8511965), @"elec_consumption": @(351900000000), @"population": @(186112794)},
                       @{@"name": @"British Virgin Islands", @"area": @(153), @"elec_consumption": @(33740000), @"population": @(22643)},
                       @{@"name": @"Brunei", @"area": @(5770), @"elec_consumption": @(2286000000), @"population": @(372361)},
                       @{@"name": @"Bulgaria", @"area": @(110910), @"elec_consumption": @(32710000000), @"population": @(7450349)},
                       @{@"name": @"Burkina Faso", @"area": @(274200), @"elec_consumption": @(335700000), @"population": @(13925313)},
                       @{@"name": @"Burma", @"area": @(678500), @"elec_consumption": @(3484000000), @"population": @(42909464)},
                       @{@"name": @"Burundi", @"area": @(27830), @"elec_consumption": @(137800000), @"population": @(6370609)},
                       @{@"name": @"Cambodia", @"area": @(181040), @"elec_consumption": @(100600000), @"population": @(13607069)},
                       @{@"name": @"Cameroon", @"area": @(475440), @"elec_consumption": @(3321000000), @"population": @(16380005)},
                       @{@"name": @"Canada", @"area": @(9984670), @"elec_consumption": @(487300000000), @"population": @(32805041)},
                       @{@"name": @"Cape Verde", @"area": @(4033), @"elec_consumption": @(40060000), @"population": @(418224)},
                       @{@"name": @"Cayman Islands", @"area": @(262), @"elec_consumption": @(382100000), @"population": @(44270)},
                       @{@"name": @"Central African Republic", @"area": @(622984), @"elec_consumption": @(98580000), @"population": @(3799897)},
                       @{@"name": @"Chad", @"area": @(1284000), @"elec_consumption": @(89400000), @"population": @(9826419)},
                       @{@"name": @"Chile", @"area": @(756950), @"elec_consumption": @(41800000000), @"population": @(15980912)},
                       @{@"name": @"China", @"area": @(9596960), @"elec_consumption": @(1630000000000), @"population": @(1306313812)},
                       @{@"name": @"Colombia", @"area": @(1138910), @"elec_consumption": @(41140000000), @"population": @(42954279)},
                       @{@"name": @"Comoros", @"area": @(2170), @"elec_consumption": @(22170000), @"population": @(671247)},
                       @{@"name": @"Congo Democratic Republic of the", @"area": @(2345410), @"elec_consumption": @(4168000000), @"population": @(60085804)},
                       @{@"name": @"Congo Republic of the", @"area": @(342000), @"elec_consumption": @(573600000), @"population": @(3039126)},
                       @{@"name": @"Cook Islands", @"area": @(240), @"elec_consumption": @(25110000), @"population": @(21388)},
                       @{@"name": @"Costa Rica", @"area": @(51100), @"elec_consumption": @(5733000000), @"population": @(4016173)},
                       @{@"name": @"Cote d'Ivoire", @"area": @(322460), @"elec_consumption": @(2976000000), @"population": @(17298040)},
                       @{@"name": @"Croatia", @"area": @(56542), @"elec_consumption": @(15200000000), @"population": @(4495904)},
                       @{@"name": @"Cuba", @"area": @(110860), @"elec_consumption": @(13400000000), @"population": @(11346670)},
                       @{@"name": @"Cyprus", @"area": @(9250), @"elec_consumption": @(602000000), @"population": @(780133)},
                       @{@"name": @"Czech Republic", @"area": @(78866), @"elec_consumption": @(55330000000), @"population": @(10241138)},
                       @{@"name": @"Denmark", @"area": @(43094), @"elec_consumption": @(31630000000), @"population": @(5432335)},
                       @{@"name": @"Djibouti", @"area": @(23000), @"elec_consumption": @(167400000), @"population": @(476703)},
                       @{@"name": @"Dominica", @"area": @(754), @"elec_consumption": @(63620000), @"population": @(69029)},
                       @{@"name": @"Dominican Republic", @"area": @(48730), @"elec_consumption": @(8912000000), @"population": @(8950034)},
                       @{@"name": @"Ecuador", @"area": @(283560), @"elec_consumption": @(75580000000), @"population": @(13363593)},
                       @{@"name": @"Egypt", @"area": @(1001450), @"elec_consumption": @(75580000000), @"population": @(77505756)},
                       @{@"name": @"El Salvador", @"area": @(21040), @"elec_consumption": @(4450000000), @"population": @(6704932)},
                       @{@"name": @"Equatorial Guinea", @"area": @(28051), @"elec_consumption": @(24820000), @"population": @(535881)},
                       @{@"name": @"Eritrea", @"area": @(121320), @"elec_consumption": @(229400000), @"population": @(4561599)},
                       @{@"name": @"Estonia", @"area": @(45226), @"elec_consumption": @(6358000000), @"population": @(1332893)},
                       @{@"name": @"Ethiopia", @"area": @(1127127), @"elec_consumption": @(1998000000), @"population": @(73053286)},
                       @{@"name": @"#European Union", @"area": @(3976372), @"elec_consumption": @(2661000000000), @"population": @(457030418)},
                       @{@"name": @"Falkland Islands (Islas Malvinas)", @"area": @(12173), @"elec_consumption": @(17720000), @"population": @(2967)},
                       @{@"name": @"Faroe Islands", @"area": @(1399), @"elec_consumption": @(204600000), @"population": @(46962)},
                       @{@"name": @"Fiji", @"area": @(18270), @"elec_consumption": @(697500000), @"population": @(893354)},
                       @{@"name": @"Finland", @"area": @(338145), @"elec_consumption": @(78580000000), @"population": @(5223442)},
                       @{@"name": @"France", @"area": @(547030), @"elec_consumption": @(414700000000), @"population": @(60656178)},
                       @{@"name": @"French Guiana", @"area": @(91000), @"elec_consumption": @(427900000), @"population": @(195506)},
                       @{@"name": @"French Polynesia", @"area": @(4167), @"elec_consumption": @(353400000), @"population": @(270485)},
                       @{@"name": @"Gabon", @"area": @(267667), @"elec_consumption": @(1080000000), @"population": @(1389201)},
                       @{@"name": @"Gambia The", @"area": @(11300), @"elec_consumption": @(83990000), @"population": @(1593256)},
                       @{@"name": @"Georgia", @"area": @(69700), @"elec_consumption": @(6811000000), @"population": @(4677401)},
                       @{@"name": @"Germany", @"area": @(357021), @"elec_consumption": @(519500000000), @"population": @(82431390)},
                       @{@"name": @"Ghana", @"area": @(239460), @"elec_consumption": @(6137000000), @"population": @(21029853)},
                       @{@"name": @"Gibraltar", @"area": @(7), @"elec_consumption": @(96760000), @"population": @(27884)},
                       @{@"name": @"Greece", @"area": @(131940), @"elec_consumption": @(47420000000), @"population": @(10668354)},
                       @{@"name": @"Greenland", @"area": @(2166086), @"elec_consumption": @(227900000), @"population": @(56375)},
                       @{@"name": @"Grenada", @"area": @(344), @"elec_consumption": @(138600000), @"population": @(89502)},
                       @{@"name": @"Guadeloupe", @"area": @(1780), @"elec_consumption": @(1079000000), @"population": @(448713)},
                       @{@"name": @"Guam", @"area": @(549), @"elec_consumption": @(776600000), @"population": @(168564)},
                       @{@"name": @"Guatemala", @"area": @(108890), @"elec_consumption": @(5760000000), @"population": @(14655189)},
                       @{@"name": @"Guinea", @"area": @(245857), @"elec_consumption": @(795200000), @"population": @(9467866)},
                       @{@"name": @"Guinea-Bissau", @"area": @(36120), @"elec_consumption": @(51150000), @"population": @(1416027)},
                       @{@"name": @"Guyana", @"area": @(214970), @"elec_consumption": @(751400000), @"population": @(765283)},
                       @{@"name": @"Haiti", @"area": @(27750), @"elec_consumption": @(574700000), @"population": @(8121622)},
                       @{@"name": @"Honduras", @"area": @(112090), @"elec_consumption": @(3771000000), @"population": @(6975204)},
                       @{@"name": @"Hong Kong", @"area": @(1092), @"elec_consumption": @(38450000000), @"population": @(6898686)},
                       @{@"name": @"Hungary", @"area": @(93030), @"elec_consumption": @(35990000000), @"population": @(10006835)},
                       @{@"name": @"Iceland", @"area": @(103000), @"elec_consumption": @(7692000000), @"population": @(296737)},
                       @{@"name": @"India", @"area": @(3287590), @"elec_consumption": @(510100000000), @"population": @(1080264388)},
                       @{@"name": @"Indonesia", @"area": @(1919440), @"elec_consumption": @(92350000000), @"population": @(241973879)},
                       @{@"name": @"Iran", @"area": @(1648000), @"elec_consumption": @(119900000000), @"population": @(68017860)},
                       @{@"name": @"Iraq", @"area": @(437072), @"elec_consumption": @(33700000000), @"population": @(26074906)},
                       @{@"name": @"Ireland", @"area": @(70280), @"elec_consumption": @(21780000000), @"population": @(4015676)},
                       @{@"name": @"Israel", @"area": @(20770), @"elec_consumption": @(38300000000), @"population": @(6276883)},
                       @{@"name": @"Italy", @"area": @(301230), @"elec_consumption": @(293900000000), @"population": @(58103033)},
                       @{@"name": @"Jamaica", @"area": @(10991), @"elec_consumption": @(5849000000), @"population": @(2731832)},
                       @{@"name": @"Japan", @"area": @(377835), @"elec_consumption": @(971000000000), @"population": @(127417244)},
                       @{@"name": @"Jersey", @"area": @(116), @"elec_consumption": @(630100000), @"population": @(90812)},
                       @{@"name": @"Jordan", @"area": @(92300), @"elec_consumption": @(7094000000), @"population": @(5759732)},
                       @{@"name": @"Kazakhstan", @"area": @(2717300), @"elec_consumption": @(62210000000), @"population": @(15185844)},
                       @{@"name": @"Kenya", @"area": @(582650), @"elec_consumption": @(4337000000), @"population": @(33829590)},
                       @{@"name": @"Kiribati", @"area": @(811), @"elec_consumption": @(6510000), @"population": @(103092)},
                       @{@"name": @"Korea North", @"area": @(120540), @"elec_consumption": @(31260000000), @"population": @(22912177)},
                       @{@"name": @"Korea South", @"area": @(98480), @"elec_consumption": @(293600000000), @"population": @(48422644)},
                       @{@"name": @"Kuwait", @"area": @(17820), @"elec_consumption": @(30160000000), @"population": @(2335648)},
                       @{@"name": @"Kyrgyzstan", @"area": @(198500), @"elec_consumption": @(10210000000), @"population": @(5146281)},
                       @{@"name": @"Laos", @"area": @(236800), @"elec_consumption": @(3036000000), @"population": @(6217141)},
                       @{@"name": @"Latvia", @"area": @(64589), @"elec_consumption": @(5829000000), @"population": @(2290237)},
                       @{@"name": @"Lebanon", @"area": @(10400), @"elec_consumption": @(8591000000), @"population": @(3826018)},
                       @{@"name": @"Lesotho", @"area": @(30355), @"elec_consumption": @(308000000), @"population": @(1867035)},
                       @{@"name": @"Liberia", @"area": @(111370), @"elec_consumption": @(454600000), @"population": @(3482211)},
                       @{@"name": @"Libya", @"area": @(1759540), @"elec_consumption": @(19430000000), @"population": @(5765563)},
                       @{@"name": @"Lithuania", @"area": @(65200), @"elec_consumption": @(10170000000), @"population": @(3596617)},
                       @{@"name": @"Luxembourg", @"area": @(2586), @"elec_consumption": @(5735000000), @"population": @(468571)},
                       @{@"name": @"Macau", @"area": @(25), @"elec_consumption": @(1772000000), @"population": @(449198)},
                       @{@"name": @"Macedonia", @"area": @(25333), @"elec_consumption": @(7216000000), @"population": @(2045262)},
                       @{@"name": @"Madagascar", @"area": @(587040), @"elec_consumption": @(781400000), @"population": @(18040341)},
                       @{@"name": @"Malawi", @"area": @(118480), @"elec_consumption": @(1012000000), @"population": @(12158924)},
                       @{@"name": @"Malaysia", @"area": @(329750), @"elec_consumption": @(68400000000), @"population": @(23953136)},
                       @{@"name": @"Maldives", @"area": @(300), @"elec_consumption": @(115700000), @"population": @(349106)},
                       @{@"name": @"Mali", @"area": @(1240000), @"elec_consumption": @(651000000), @"population": @(12291529)},
                       @{@"name": @"Malta", @"area": @(316), @"elec_consumption": @(2000000000), @"population": @(398534)},
                       @{@"name": @"Martinique", @"area": @(1100), @"elec_consumption": @(1095000000), @"population": @(432900)},
                       @{@"name": @"Mauritania", @"area": @(1030700), @"elec_consumption": @(176900000), @"population": @(3086859)},
                       @{@"name": @"Mauritius", @"area": @(2040), @"elec_consumption": @(1707000000), @"population": @(1230602)},
                       @{@"name": @"Mexico", @"area": @(1972550), @"elec_consumption": @(189700000000), @"population": @(106202903)},
                       @{@"name": @"Micronesia Federated States of", @"area": @(702), @"elec_consumption": @(178600000), @"population": @(108105)},
                       @{@"name": @"Moldova", @"area": @(33843), @"elec_consumption": @(4605000000), @"population": @(4455421)},
                       @{@"name": @"Mongolia", @"area": @(1564116), @"elec_consumption": @(2209000000), @"population": @(2791272)},
                       @{@"name": @"Montserrat", @"area": @(102), @"elec_consumption": @(1674000), @"population": @(9341)},
                       @{@"name": @"Morocco", @"area": @(446550), @"elec_consumption": @(14240000000), @"population": @(32725847)},
                       @{@"name": @"Mozambique", @"area": @(801590), @"elec_consumption": @(5046000000), @"population": @(19406703)},
                       @{@"name": @"Namibia", @"area": @(825418), @"elec_consumption": @(1920000000), @"population": @(2030692)},
                       @{@"name": @"Nauru", @"area": @(21), @"elec_consumption": @(27900000), @"population": @(13048)},
                       @{@"name": @"Nepal", @"area": @(140800), @"elec_consumption": @(2005000000), @"population": @(27676547)},
                       @{@"name": @"Netherlands", @"area": @(41526), @"elec_consumption": @(100700000000), @"population": @(16407491)},
                       @{@"name": @"Netherlands Antilles", @"area": @(960), @"elec_consumption": @(934300000), @"population": @(219958)},
                       @{@"name": @"New Caledonia", @"area": @(19060), @"elec_consumption": @(1471000000), @"population": @(216494)},
                       @{@"name": @"New Zealand", @"area": @(268680), @"elec_consumption": @(35710000000), @"population": @(4035461)},
                       @{@"name": @"Nicaragua", @"area": @(129494), @"elec_consumption": @(2318000000), @"population": @(5465100)},
                       @{@"name": @"Niger", @"area": @(1267000), @"elec_consumption": @(327600000), @"population": @(11665937)},
                       @{@"name": @"Nigeria", @"area": @(923768), @"elec_consumption": @(18430000000), @"population": @(128771988)},
                       @{@"name": @"Niue", @"area": @(260), @"elec_consumption": @(2790000), @"population": @(2166)},
                       @{@"name": @"Norway", @"area": @(324220), @"elec_consumption": @(107400000000), @"population": @(4593041)},
                       @{@"name": @"Oman", @"area": @(212460), @"elec_consumption": @(9792000000), @"population": @(3001583)},
                       @{@"name": @"Pakistan", @"area": @(803940), @"elec_consumption": @(52660000000), @"population": @(162419946)},
                       @{@"name": @"Panama", @"area": @(78200), @"elec_consumption": @(4473000000), @"population": @(3039150)},
                       @{@"name": @"Papua New Guinea", @"area": @(462840), @"elec_consumption": @(1561000000), @"population": @(5545268)},
                       @{@"name": @"Paraguay", @"area": @(406750), @"elec_consumption": @(2469000000), @"population": @(6347884)},
                       @{@"name": @"Peru", @"area": @(1285220), @"elec_consumption": @(20220000000), @"population": @(27925628)},
                       @{@"name": @"Philippines", @"area": @(300000), @"elec_consumption": @(46050000000), @"population": @(87857473)},
                       @{@"name": @"Poland", @"area": @(312685), @"elec_consumption": @(117400000000), @"population": @(38635144)},
                       @{@"name": @"Portugal", @"area": @(92391), @"elec_consumption": @(42150000000), @"population": @(10566212)},
                       @{@"name": @"Puerto Rico", @"area": @(9104), @"elec_consumption": @(20540000000), @"population": @(3916632)},
                       @{@"name": @"Qatar", @"area": @(11437), @"elec_consumption": @(9046000000), @"population": @(863051)},
                       @{@"name": @"Reunion", @"area": @(2517), @"elec_consumption": @(1084000000), @"population": @(776948)},
                       @{@"name": @"Romania", @"area": @(237500), @"elec_consumption": @(57500000000), @"population": @(22329977)},
                       @{@"name": @"Russia", @"area": @(17075200), @"elec_consumption": @(894300000000), @"population": @(143420309)},
                       @{@"name": @"Rwanda", @"area": @(26338), @"elec_consumption": @(195000000), @"population": @(8440820)},
                       @{@"name": @"Saint Helena", @"area": @(410), @"elec_consumption": @(4650000), @"population": @(7460)},
                       @{@"name": @"Saint Kitts and Nevis", @"area": @(261), @"elec_consumption": @(98440000), @"population": @(38958)},
                       @{@"name": @"Saint Lucia", @"area": @(616), @"elec_consumption": @(251300000), @"population": @(166312)},
                       @{@"name": @"Saint Pierre and Miquelon", @"area": @(242), @"elec_consumption": @(40060000), @"population": @(7012)},
                       @{@"name": @"Saint Vincent and the Grenadines", @"area": @(389), @"elec_consumption": @(84820000), @"population": @(117534)},
                       @{@"name": @"Samoa", @"area": @(2944), @"elec_consumption": @(113500000), @"population": @(177287)},
                       @{@"name": @"Sao Tome and Principe", @"area": @(1001), @"elec_consumption": @(15810000), @"population": @(187410)},
                       @{@"name": @"Saudi Arabia", @"area": @(1960582), @"elec_consumption": @(128500000000), @"population": @(26417599)},
                       @{@"name": @"Senegal", @"area": @(196190), @"elec_consumption": @(1615000000), @"population": @(11126832)},
                       @{@"name": @"Serbia and Montenegro", @"area": @(102350), @"elec_consumption": @(32330000000), @"population": @(10829175)},
                       @{@"name": @"Seychelles", @"area": @(455), @"elec_consumption": @(202800000), @"population": @(81188)},
                       @{@"name": @"Sierra Leone", @"area": @(71740), @"elec_consumption": @(237400000), @"population": @(6017643)},
                       @{@"name": @"Singapore", @"area": @(693), @"elec_consumption": @(32000000000), @"population": @(4425720)},
                       @{@"name": @"Slovakia", @"area": @(48845), @"elec_consumption": @(28890000000), @"population": @(5431363)},
                       @{@"name": @"Slovenia", @"area": @(20273), @"elec_consumption": @(11800000000), @"population": @(2011070)},
                       @{@"name": @"Solomon Islands", @"area": @(28450), @"elec_consumption": @(29760000), @"population": @(538032)},
                       @{@"name": @"Somalia", @"area": @(637657), @"elec_consumption": @(223500000), @"population": @(8591629)},
                       @{@"name": @"South Africa", @"area": @(1219912), @"elec_consumption": @(189400000000), @"population": @(44344136)},
                       @{@"name": @"Spain", @"area": @(504782), @"elec_consumption": @(218400000000), @"population": @(40341462)},
                       @{@"name": @"Sri Lanka", @"area": @(65610), @"elec_consumption": @(6228000000), @"population": @(20064776)},
                       @{@"name": @"Sudan", @"area": @(2505810), @"elec_consumption": @(2400000000), @"population": @(40187486)},
                       @{@"name": @"Suriname", @"area": @(163270), @"elec_consumption": @(1845000000), @"population": @(438144)},
                       @{@"name": @"Swaziland", @"area": @(17363), @"elec_consumption": @(1173000000), @"population": @(1173900)},
                       @{@"name": @"Sweden", @"area": @(449964), @"elec_consumption": @(138100000000), @"population": @(9001774)},
                       @{@"name": @"Switzerland", @"area": @(41290), @"elec_consumption": @(54530000000), @"population": @(7489370)},
                       @{@"name": @"Syria", @"area": @(185180), @"elec_consumption": @(24320000000), @"population": @(18448752)},
                       @{@"name": @"Taiwan", @"area": @(35980), @"elec_consumption": @(147400000000), @"population": @(22894384)},
                       @{@"name": @"Tajikistan", @"area": @(143100), @"elec_consumption": @(14410000000), @"population": @(7163506)},
                       @{@"name": @"Tanzania", @"area": @(945087), @"elec_consumption": @(2566000000), @"population": @(36766356)},
                       @{@"name": @"Thailand", @"area": @(514000), @"elec_consumption": @(106100000000), @"population": @(65444371)},
                       @{@"name": @"Togo", @"area": @(56785), @"elec_consumption": @(451200000), @"population": @(5681519)},
                       @{@"name": @"Tonga", @"area": @(748), @"elec_consumption": @(23060000), @"population": @(112422)},
                       @{@"name": @"Trinidad and Tobago", @"area": @(5128), @"elec_consumption": @(5341000000), @"population": @(1088644)},
                       @{@"name": @"Tunisia", @"area": @(163610), @"elec_consumption": @(10050000000), @"population": @(10074951)},
                       @{@"name": @"Turkey", @"area": @(780580), @"elec_consumption": @(117900000000), @"population": @(69660559)},
                       @{@"name": @"Turkmenistan", @"area": @(488100), @"elec_consumption": @(8908000000), @"population": @(4952081)},
                       @{@"name": @"Turks and Caicos Islands", @"area": @(430), @"elec_consumption": @(4650000), @"population": @(20556)},
                       @{@"name": @"Uganda", @"area": @(236040), @"elec_consumption": @(1401000000), @"population": @(27269482)},
                       @{@"name": @"Ukraine", @"area": @(603700), @"elec_consumption": @(132000000000), @"population": @(47425336)},
                       @{@"name": @"United Arab Emirates", @"area": @(82880), @"elec_consumption": @(36510000000), @"population": @(2563212)},
                       @{@"name": @"United Kingdom", @"area": @(244820), @"elec_consumption": @(337400000000), @"population": @(60441457)},
                       @{@"name": @"United States", @"area": @(9631418), @"elec_consumption": @(3660000000000), @"population": @(295734134)},
                       @{@"name": @"Uruguay", @"area": @(176220), @"elec_consumption": @(5878000000), @"population": @(3415920)},
                       @{@"name": @"Uzbekistan", @"area": @(447400), @"elec_consumption": @(46660000000), @"population": @(26851195)},
                       @{@"name": @"Vanuatu", @"area": @(12200), @"elec_consumption": @(45030000), @"population": @(205754)},
                       @{@"name": @"Venezuela", @"area": @(912050), @"elec_consumption": @(89300000000), @"population": @(25375281)},
                       @{@"name": @"Vietnam", @"area": @(329560), @"elec_consumption": @(32060000000), @"population": @(83535576)},
                       @{@"name": @"Virgin Islands", @"area": @(352), @"elec_consumption": @(962600000), @"population": @(108708)},
                       @{@"name": @"Western Sahara", @"area": @(266000), @"elec_consumption": @(83700000), @"population": @(273008)},
                       @{@"name": @"Yemen", @"area": @(527970), @"elec_consumption": @(2827000000), @"population": @(20727063)},
                       @{@"name": @"Zambia", @"area": @(752614), @"elec_consumption": @(5345000000), @"population": @(11261795)},
                       @{@"name": @"Zimbabwe", @"area": @(390580), @"elec_consumption": @(11220000000), @"population": @(12746990)},
                       ];
    
    for (NSDictionary *doc in array) {
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];
        [self.datastore createDocumentWithBody:body error:&error];
    }

}

- (int)countResults:(CDTQueryResult*)res
{
    int count=0;
    for(CDTDocumentRevision *doc in res) {
        count++;
    }
    return count;
}

- (void)setUp
{
    [super setUp];
    NSError *error = nil;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    STAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    [super tearDown];
}

@end

#pragma mark Test Indexer Implementation

#import "TD_Revision.h"
#import "TD_Body.h"

@implementation CDTTestIndexer1

-(NSArray*)valuesForRevision:(CDTDocumentRevision*)revision
                   indexName:(NSString*)indexName

{
    NSString *value = [[revision body] valueForKey:indexName];

    NSString *prefix1 = [value substringToIndex:1];
    NSString *prefix2 = [value substringToIndex:2];

    return @[prefix1, prefix2];
}


@end
