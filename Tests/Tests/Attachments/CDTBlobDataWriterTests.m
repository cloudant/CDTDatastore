//
//  CDTBlobDataWriterTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 06/05/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
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

#import "CDTBlobDataWriter.h"

@interface CDTBlobDataWriterTests : XCTestCase

@end

@implementation CDTBlobDataWriterTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.

    [super tearDown];
}

- (void)testSimpleInitFails
{
    XCTAssertNil([[CDTBlobDataWriter alloc] init], @"A path is mandatory");
}

- (void)testInitWithPathEqualToNilFails
{
    XCTAssertNil([[CDTBlobDataWriter alloc] initWithPath:nil], @"A path is mandatory");
}

- (void)testInitWithEmptyPathFails
{
    XCTAssertNil([[CDTBlobDataWriter alloc] initWithPath:@""], @"A path is mandatory");
}

- (void)testInitWithNotValidPathFails
{
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataWriterTests.txt"];

    XCTAssertNil([[CDTBlobDataWriter alloc] initWithPath:path], @"File must exist");
}

@end
