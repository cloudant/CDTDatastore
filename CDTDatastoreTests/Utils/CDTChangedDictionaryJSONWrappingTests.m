//
//  CDTChangedDictionaryJSONWrappingTests.m
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
#import <CDTDatastore/CDTChangedArray.h>

@interface CDTChangedDictionaryJSONWrappingTests : XCTestCase

@property (nonatomic, strong) CDTChangedDictionary *dictionary;

@end

@implementation CDTChangedDictionaryJSONWrappingTests

- (void)setUp
{
    [super setUp];

    NSDictionary *dictionary = @{
        @"dict" :
            @{@"array" : @[ @"one", @"two" ], @"dict" : @{@"one" : @"two"}, @"hello" : @"world"},

        @"array" : @[ @[ @"foo", @YES ], @{@"foo" : @YES}, @"two" ]
    };

    self.dictionary = [CDTChangedDictionary dictionaryCopyingContents:dictionary];
}

- (void)testUnmodified { XCTAssertFalse(self.dictionary.isChanged); }

- (void)testModifyTopLevelField
{
    self.dictionary[@"dict"] = @[ @1, @2 ];
    XCTAssertTrue(self.dictionary.isChanged);
}

- (void)testModifyNestedArrayFirstLevel
{
    self.dictionary[@"array"][1] = @"two_changed";
    XCTAssertTrue(self.dictionary.isChanged);
}

- (void)testModifyNestedArraySecondLevel
{
    self.dictionary[@"dict"][@"array"] = @"two_changed";
    XCTAssertTrue(self.dictionary.isChanged);
}

- (void)testModifyArrayNestedInDictionary
{
    self.dictionary[@"dict"][@"array"][1] = @"two_changed";
    XCTAssertTrue(self.dictionary.isChanged);
}

- (void)testModifyDictionaryNestedInDictionary
{
    self.dictionary[@"dict"][@"dict"][@"one"] = @"two_changed";
    XCTAssertTrue(self.dictionary.isChanged);
}

- (void)testModifyArrayNestedInArray
{
    self.dictionary[@"array"][0][1] = @"two_changed";
    XCTAssertTrue(self.dictionary.isChanged);
}

- (void)testModifyDictionaryNestedInArray
{
    self.dictionary[@"array"][1][@"foo"] = @"two_changed";
    XCTAssertTrue(self.dictionary.isChanged);
}

@end
