//
//  CDTChangedArrayTests.m
//  Tests
//
//  Created by Michael Rhodes on 17/08/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <XCTest/XCTest.h>

#import <CDTDatastore/CDTChangedArray.h>

@interface CDTChangedArrayTests : XCTestCase

@end

@implementation CDTChangedArrayTests

- (void)testUnchangedNewArray
{
    NSMutableArray *base = [@[] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    XCTAssertFalse(array.isChanged);
}

- (void)testUnchangedNonEmptyArray
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    XCTAssertFalse(array.isChanged);
}

- (void)testUnchangedRead
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    XCTAssertNotNil(array[1]);
    XCTAssertFalse(array.isChanged);
}

- (void)testUnchangedCount
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    XCTAssertEqual(2, array.count);
    XCTAssertFalse(array.isChanged);
}

- (void)testChangedSubscriptInsert
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    array[1] = @"parrot";
    XCTAssertTrue(array.isChanged);
}

- (void)testChangedInsertObjectAtIndex
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    [array insertObject:@"parrot" atIndex:1];
    XCTAssertTrue(array.isChanged);
}

- (void)testChangedRemoveObjectAtIndex
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    [array removeObjectAtIndex:1];
    XCTAssertTrue(array.isChanged);
}

- (void)testChangedAddObject
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    [array addObject:@"parrot"];
    XCTAssertTrue(array.isChanged);
}

- (void)testChangedRemoveLastObject
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    [array removeLastObject];
    XCTAssertTrue(array.isChanged);
}

- (void)testChangedReplaceObjectAtIndexWithObject
{
    NSMutableArray *base = [@[ @"cat", @"dog" ] mutableCopy];
    CDTChangedArray *array = [[CDTChangedArray alloc] initWithMutableArray:base];
    [array replaceObjectAtIndex:1 withObject:@"parrot"];
    XCTAssertTrue(array.isChanged);
}

@end
