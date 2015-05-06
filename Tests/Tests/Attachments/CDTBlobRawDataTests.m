//
//  CDTBlobRawDataTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 05/05/2015.
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

#import "CDTBlobRawData.h"

@interface CDTBlobRawDataTests : XCTestCase

@end

@implementation CDTBlobRawDataTests

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

- (void)testSimpleInitFails { XCTAssertNil([[CDTBlobRawData alloc] init], @"A path is mandatory"); }

- (void)testInitWithPathEqualToNilFails
{
    XCTAssertNil([[CDTBlobRawData alloc] initWithPath:nil], @"A path is mandatory");
}

- (void)testInitWithEmptyPathFails
{
    XCTAssertNil([[CDTBlobRawData alloc] initWithPath:@""], @"A path is mandatory");
}

- (void)testInitWithNonEmptyStringSucceeds
{
    XCTAssertNotNil([[CDTBlobRawData alloc] initWithPath:@"This is not a path"],
                    @"Any string is valid as long as it is not empty");
}

@end
