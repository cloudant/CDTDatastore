//
//  CDTBlobDataTests.m
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

#import "CDTBlobData.h"

@interface CDTBlobDataTests : XCTestCase

@property (strong, nonatomic) NSString *pathToExistingFile;

@end

@implementation CDTBlobDataTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.pathToExistingFile =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataTests.txt"];
    [[NSFileManager defaultManager] createFileAtPath:self.pathToExistingFile
                                            contents:nil
                                          attributes:nil];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    [[NSFileManager defaultManager] removeItemAtPath:self.pathToExistingFile error:nil];
    self.pathToExistingFile = nil;

    [super tearDown];
}

- (void)testSimpleInitFails { XCTAssertNil([[CDTBlobData alloc] init], @"A path is mandatory"); }

- (void)testInitWithPathEqualToNilFails
{
    XCTAssertNil([[CDTBlobData alloc] initWithPath:nil], @"A path is mandatory");
}

- (void)testInitWithEmptyPathFails
{
    XCTAssertNil([[CDTBlobData alloc] initWithPath:@""], @"A path is mandatory");
}

- (void)testInitWithNotValidPathSucceeds
{
    XCTAssertNotNil([[CDTBlobData alloc] initWithPath:@"This is not a path"],
                    @"Any string is valid as long as it is not empty");
}

- (void)testWriterReturnNilIfPathIsNotValid
{
    CDTBlobData *blob = [[CDTBlobData alloc] initWithPath:@"This is not a path"];

    XCTAssertNil([blob writer], @"A writer can not be created without a valid path");
}

- (void)testWriterReturnNilIfFileDoesNotExist
{
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataTests-nofile.txt"];

    CDTBlobData *blob = [[CDTBlobData alloc] initWithPath:path];

    XCTAssertNil([blob writer], @"The file must exist before creating the writer");
}

- (void)testWriterReturnAValueIfFileExists
{
    CDTBlobData *blob = [[CDTBlobData alloc] initWithPath:self.pathToExistingFile];
    
    XCTAssertNotNil([blob writer], @"It should return an object if the file exists");
}

- (void)testWriterAlwaysReturnsADifferentObject
{
    CDTBlobData *blob = [[CDTBlobData alloc] initWithPath:self.pathToExistingFile];
    
    id<CDTBlobWriter> writer01 = [blob writer];
    id<CDTBlobWriter> writer02 = [blob writer];
    
    XCTAssertNotEqual(writer01, writer02, @"A new writer is created each time");
}

@end
