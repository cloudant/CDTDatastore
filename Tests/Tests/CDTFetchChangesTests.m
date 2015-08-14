//
//  CDTFetchChangesTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 30/06/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <XCTest/XCTest.h>

#import "CloudantSyncTests.h"

#import "CDTFetchChanges.h"
#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"
#import "CDTDocumentRevision.h"

#define CDTFETCHANGESTESTS_TOTALDOCCOUNT 1100
#define CDTFETCHANGESTESTS_DELETEDOCCOUNT 5

@interface CDTFetchChangesTests : CloudantSyncTests

@property (strong, nonatomic) CDTDatastore *datastore;
@property (strong, nonatomic) NSString *startSequenceValue;

@end

@implementation CDTFetchChangesTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    // Prepare datastore
    self.datastore = [self.factory datastoreNamed:@"test_fetchchanges" error:nil];

    // Get first sequence value
    CDTFetchChanges *fetchChanges =
        [[CDTFetchChanges alloc] initWithDatastore:self.datastore startSequenceValue:nil];

    __block NSString *blockStartSequenceValue = nil;
    fetchChanges.fetchRecordChangesCompletionBlock =
        ^(NSString *newSequenceValue, NSString *startSequenceValue, NSError *fetchError) {
          blockStartSequenceValue = newSequenceValue;
        };

    [fetchChanges start];

    self.startSequenceValue = blockStartSequenceValue;

    // Populate datatore
    [CDTFetchChangesTests populateDatastore:self.datastore
                              withDocuments:CDTFETCHANGESTESTS_TOTALDOCCOUNT];

    for (NSInteger index = 0; index < CDTFETCHANGESTESTS_DELETEDOCCOUNT; index++) {
        [self.datastore deleteDocumentWithId:[CDTFetchChangesTests docIdWithIndex:index] error:nil];
    }
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.startSequenceValue = nil;
    self.datastore = nil;

    [super tearDown];
}

- (void)testBasicCaseWorks
{
    CDTFetchChanges *fetchChanges =
        [[CDTFetchChanges alloc] initWithDatastore:self.datastore
                                startSequenceValue:self.startSequenceValue];

    __block NSUInteger blockChangedDocCount = 0;
    fetchChanges.documentChangedBlock = ^(CDTDocumentRevision *revision) {
      blockChangedDocCount++;
    };

    __block NSUInteger blockDeletedDocCount = 0;
    fetchChanges.documentWithIDWasDeletedBlock = ^(NSString *docId) {
      blockDeletedDocCount++;
    };

    [fetchChanges start];

    // Assert
    XCTAssertEqual(blockChangedDocCount,
                   (CDTFETCHANGESTESTS_TOTALDOCCOUNT - CDTFETCHANGESTESTS_DELETEDOCCOUNT),
                   @"%d documents remains in the datastore",
                   (CDTFETCHANGESTESTS_TOTALDOCCOUNT - CDTFETCHANGESTESTS_DELETEDOCCOUNT));
    XCTAssertEqual(blockDeletedDocCount, CDTFETCHANGESTESTS_DELETEDOCCOUNT,
                   @"%i documents were deleted", 0);
}

- (void)testResultLimitSmallerThanTheTotalNumberOfDocuments
{
    CDTFetchChanges *fetchChanges =
        [[CDTFetchChanges alloc] initWithDatastore:self.datastore
                                startSequenceValue:self.startSequenceValue];

    NSUInteger limit = (CDTFETCHANGESTESTS_TOTALDOCCOUNT - 10);
    fetchChanges.resultsLimit = limit;

    __block NSUInteger blockChangedDocCount = 0;
    fetchChanges.documentChangedBlock = ^(CDTDocumentRevision *revision) {
      blockChangedDocCount++;
    };

    __block NSUInteger blockDeletedDocCount = 0;
    fetchChanges.documentWithIDWasDeletedBlock = ^(NSString *docId) {
      blockDeletedDocCount++;
    };

    [fetchChanges start];

    // Assert
    XCTAssertEqual((blockChangedDocCount + blockDeletedDocCount), limit,
                   @"Total number of read documents must be equal to the limit");
    XCTAssertTrue(fetchChanges.moreComing, @"I did not read all the documents in the datastore");
}

- (void)testResultLimitEqualToTheTotalNumberOfDocuments
{
    CDTFetchChanges *fetchChanges =
        [[CDTFetchChanges alloc] initWithDatastore:self.datastore
                                startSequenceValue:self.startSequenceValue];

    fetchChanges.resultsLimit = CDTFETCHANGESTESTS_TOTALDOCCOUNT;

    __block NSUInteger blockChangedDocCount = 0;
    fetchChanges.documentChangedBlock = ^(CDTDocumentRevision *revision) {
      blockChangedDocCount++;
    };

    __block NSUInteger blockDeletedDocCount = 0;
    fetchChanges.documentWithIDWasDeletedBlock = ^(NSString *docId) {
      blockDeletedDocCount++;
    };

    [fetchChanges start];

    // Assert
    XCTAssertEqual((blockChangedDocCount + blockDeletedDocCount), CDTFETCHANGESTESTS_TOTALDOCCOUNT,
                   @"Total number of read documents must be equal to the limit");
    XCTAssertFalse(fetchChanges.moreComing, @"I did read all documents, there are no more coming");
}

- (void)testResultLimitBiggerThanTheTotalNumberOfDocuments
{
    CDTFetchChanges *fetchChanges =
        [[CDTFetchChanges alloc] initWithDatastore:self.datastore
                                startSequenceValue:self.startSequenceValue];

    NSUInteger limit = (CDTFETCHANGESTESTS_TOTALDOCCOUNT + 10);
    fetchChanges.resultsLimit = limit;

    __block NSUInteger blockChangedDocCount = 0;
    fetchChanges.documentChangedBlock = ^(CDTDocumentRevision *revision) {
      blockChangedDocCount++;
    };

    __block NSUInteger blockDeletedDocCount = 0;
    fetchChanges.documentWithIDWasDeletedBlock = ^(NSString *docId) {
      blockDeletedDocCount++;
    };

    [fetchChanges start];

    // Assert
    XCTAssertEqual((blockChangedDocCount + blockDeletedDocCount), CDTFETCHANGESTESTS_TOTALDOCCOUNT,
                   @"We can only read the documents present in the datastore");
    XCTAssertFalse(fetchChanges.moreComing, @"I did read all documents, there are no more coming");
}

- (void)testFetchAllChangesWithALimitWorks
{
    NSUInteger limit = (CDTFETCHANGESTESTS_TOTALDOCCOUNT - 10);

    // First read
    CDTFetchChanges *fetchChanges =
        [[CDTFetchChanges alloc] initWithDatastore:self.datastore
                                startSequenceValue:self.startSequenceValue];

    fetchChanges.resultsLimit = limit;

    __block NSUInteger blockChangedDocCount = 0;
    fetchChanges.documentChangedBlock = ^(CDTDocumentRevision *revision) {
      blockChangedDocCount++;
    };

    __block NSUInteger blockDeletedDocCount = 0;
    fetchChanges.documentWithIDWasDeletedBlock = ^(NSString *docId) {
      blockDeletedDocCount++;
    };

    __block NSString *blockStartSequenceValue = nil;
    fetchChanges.fetchRecordChangesCompletionBlock =
        ^(NSString *newSequenceValue, NSString *startSequenceValue, NSError *fetchError) {
          blockStartSequenceValue = newSequenceValue;
        };

    [fetchChanges start];

    // Second read
    fetchChanges = [[CDTFetchChanges alloc] initWithDatastore:self.datastore
                                           startSequenceValue:blockStartSequenceValue];

    fetchChanges.resultsLimit = limit;

    fetchChanges.documentChangedBlock = ^(CDTDocumentRevision *revision) {
      blockChangedDocCount++;
    };

    fetchChanges.documentWithIDWasDeletedBlock = ^(NSString *docId) {
      blockDeletedDocCount++;
    };

    [fetchChanges start];

    // Assert
    XCTAssertEqual(blockChangedDocCount,
                   (CDTFETCHANGESTESTS_TOTALDOCCOUNT - CDTFETCHANGESTESTS_DELETEDOCCOUNT),
                   @"%d documents remains in the datastore",
                   (CDTFETCHANGESTESTS_TOTALDOCCOUNT - CDTFETCHANGESTESTS_DELETEDOCCOUNT));
    XCTAssertEqual(blockDeletedDocCount, CDTFETCHANGESTESTS_DELETEDOCCOUNT,
                   @"%i documents were deleted", 0);
}

#pragma mark - Private class methods
+ (void)populateDatastore:(CDTDatastore *)datastore withDocuments:(NSUInteger)counter
{
    for (NSUInteger i = 0; i < counter; i++) {
        CDTDocumentRevision *rev =
            [CDTDocumentRevision revisionWithDocId:[CDTFetchChangesTests docIdWithIndex:i]];
        rev.body = @{ [NSString stringWithFormat:@"hello-%lu", (unsigned long)i] : @"world" };

        [datastore createDocumentFromRevision:rev error:nil];
    }
}

+ (NSString *)docIdWithIndex:(NSUInteger)index
{
    return [NSString stringWithFormat:@"docId-%lu", (unsigned long)index];
}

@end
