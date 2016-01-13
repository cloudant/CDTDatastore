//
//  CDTChangedDictionaryTests.m
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

#import <CDTDatastore/CDTChangedDictionary.h>

@interface CDTChangedDictionaryTests : XCTestCase

@end

@implementation CDTChangedDictionaryTests

- (void)testStartUnchanged
{
    NSMutableDictionary *base = [@{} mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];

    XCTAssertFalse(dictionary.isChanged);
}

- (void)testReadUnchangedNonExistantKey
{
    NSMutableDictionary *base = [@{} mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];

    NSObject *o = dictionary[@"hello"];

    XCTAssertNil(o);
    XCTAssertFalse(dictionary.isChanged);
}

- (void)testReadUnchangedExistantKey
{
    NSMutableDictionary *base = [@{ @"hello" : @"world" } mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];

    NSObject *o = dictionary[@"hello"];

    XCTAssertNotNil(o);
    XCTAssertFalse(dictionary.isChanged);
}

// initWithObjects:forKeys:count:

- (void)testUnchangedCount
{
    NSMutableDictionary *base = [@{ @"hello" : @"world" } mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];

    NSUInteger count = dictionary.count;

    XCTAssertEqual(count, 1);
    XCTAssertFalse(dictionary.isChanged);
}

- (void)testUnchangedKeyEnumerator
{
    NSMutableDictionary *base = [@{ @"hello" : @"world" } mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];

    NSEnumerator *enumerator = [dictionary keyEnumerator];

    XCTAssertNotNil(enumerator);
    XCTAssertFalse(dictionary.isChanged);
}

- (void)testUnchangedInitWithObjects
{
    id keys[1] = { @"hello" };
    id objects[1] = { @"world" };

    CDTChangedDictionary *dictionary =
        [[CDTChangedDictionary alloc] initWithObjects:objects forKeys:keys count:1];
    XCTAssertEqual(dictionary.count, 1);
    XCTAssertFalse(dictionary.isChanged);
}

// Changing with subscript

- (void)testChangedInitWithObjectsSubscript
{
    id keys[1] = { @"hello" };
    id objects[1] = { @"world" };

    CDTChangedDictionary *dictionary =
        [[CDTChangedDictionary alloc] initWithObjects:objects forKeys:keys count:1];
    dictionary[@"foo"] = @"bar";

    XCTAssertEqual(dictionary.count, 2);
    XCTAssertTrue(dictionary.isChanged);
}

- (void)testChangedInitWithDictionarySubscript
{
    NSMutableDictionary *base = [@{} mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];
    dictionary[@"foo"] = @"bar";
    XCTAssertTrue(dictionary.isChanged);
}

// Changing with setObject:forKey:

- (void)testChangedInitWithObjectsSetObjectForKey
{
    id keys[1] = { @"hello" };
    id objects[1] = { @"world" };

    CDTChangedDictionary *dictionary =
        [[CDTChangedDictionary alloc] initWithObjects:objects forKeys:keys count:1];
    [dictionary setObject:@"bar" forKey:@"foo"];

    XCTAssertEqual(dictionary.count, 2);
    XCTAssertTrue(dictionary.isChanged);
}

- (void)testChangedInitWithDictionarySetObjectForKey
{
    NSMutableDictionary *base = [@{} mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];
    [dictionary setObject:@"bar" forKey:@"foo"];
    XCTAssertTrue(dictionary.isChanged);
}

// Removing objects

- (void)testChangedInitWithObjectsRemove
{
    id keys[1] = { @"hello" };
    id objects[1] = { @"world" };

    CDTChangedDictionary *dictionary =
        [[CDTChangedDictionary alloc] initWithObjects:objects forKeys:keys count:1];
    [dictionary removeObjectForKey:@"hello"];

    XCTAssertEqual(dictionary.count, 0);
    XCTAssertTrue(dictionary.isChanged);
}

- (void)testChangedInitWithDictionaryRemove
{
    NSMutableDictionary *base = [@{ @"hello" : @"world" } mutableCopy];
    CDTChangedDictionary *dictionary = [[CDTChangedDictionary alloc] initWithDictionary:base];
    [dictionary removeObjectForKey:@"hello"];
    XCTAssertTrue(dictionary.isChanged);
}

@end
