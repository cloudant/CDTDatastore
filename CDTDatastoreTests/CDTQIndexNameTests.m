//
//  CDTQIndexNameTests.m
//  CDTDatastoreTests
//
//  Created by tomblench on 27/04/2018.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "CloudantSyncTests.h"
#import "CDTDatastore.h"
#import "CDTDatastore+Query.h"
#import "CDTDatastoreManager.h"
#import "CDTDocumentRevision.h"
#import "CDTQResultSet.h"

// tests for "unusual" index names
@interface CDTQIndexNameTests : CloudantSyncTests
@end

@implementation CDTQIndexNameTests

// regression test for bug seen by customer when index name contains dashes and numbers
- (void)testDashesAndNumbersInIndexName {
    NSString *dbName = @"db";
    NSString *indexName = @"zyx-zz0123-20180426-abc-def";
    NSError *error;
    CDTDatastore *ds = [self.factory datastoreNamed:dbName error:&error];
    XCTAssertNil(error);
    [ds ensureIndexed:@[@"type", @"number", @"name"] withName:indexName];
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [NSMutableDictionary dictionaryWithDictionary:@{@"type":@"temp", @"number": @0, @"name": @"abc0"}];
    [ds createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error);
    CDTQResultSet *rs = [ds find:@{@"type":@"temp"} skip:0 limit:1000 fields:nil sort:@[@{@"number": @"desc"}]];
    __block int resultCount = 0;
    [rs enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop) {
        resultCount++;
    }];
    XCTAssertTrue(resultCount == 1);
}

// test that we can use unicode in index names
- (void)testUnicodeIndexName {
    NSString *dbName = @"db";
    NSString *indexName = @"日本";
    NSError *error;
    CDTDatastore *ds = [self.factory datastoreNamed:dbName error:&error];
    XCTAssertNil(error);
    [ds ensureIndexed:@[@"type", @"number", @"name"] withName:indexName];
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [NSMutableDictionary dictionaryWithDictionary:@{@"type":@"temp", @"number": @0, @"name": @"abc0"}];
    [ds createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error);
    CDTQResultSet *rs = [ds find:@{@"type":@"temp"} skip:0 limit:1000 fields:nil sort:@[@{@"number": @"desc"}]];
    __block int resultCount = 0;
    [rs enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop) {
        resultCount++;
    }];
    XCTAssertTrue(resultCount == 1);
}

// test that we can use unicode in index fields
- (void)testUnicodeIndexField {
    NSString *dbName = @"db";
    NSString *indexName = @"index";
    NSError *error;
    CDTDatastore *ds = [self.factory datastoreNamed:dbName error:&error];
    XCTAssertNil(error);
    [ds ensureIndexed:@[@"type", @"number", @"日本"] withName:indexName];
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [NSMutableDictionary dictionaryWithDictionary:@{@"type":@"temp", @"number": @0, @"日本": @"abc0"}];
    [ds createDocumentFromRevision:rev error:&error];
    XCTAssertNil(error);
    CDTQResultSet *rs = [ds find:@{@"日本":@"abc0"} skip:0 limit:1000 fields:nil sort:@[@{@"number": @"desc"}]];
    __block int resultCount = 0;
    [rs enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop) {
        resultCount++;
    }];
    XCTAssertTrue(resultCount == 1);
}

@end
