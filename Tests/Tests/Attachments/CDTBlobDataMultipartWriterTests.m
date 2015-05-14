//
//  CDTBlobDataMultipartWriterTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 14/05/2015.
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

#import "CDTBlobDataMultipartWriter.h"

@interface CDTBlobDataMultipartWriterTests : XCTestCase

@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *pathToNonExistingFile;
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) CDTBlobDataMultipartWriter *multipartWriter;

@end

@implementation CDTBlobDataMultipartWriterTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobDataMultipartWriterTests.txt"];
    [[NSFileManager defaultManager] createFileAtPath:self.path contents:nil attributes:nil];

    self.pathToNonExistingFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobDataMultipartWriterTests_noExists.txt"];

    self.data = [@"Lorem ipsum" dataUsingEncoding:NSASCIIStringEncoding];

    self.multipartWriter = [CDTBlobDataMultipartWriter multipartWriter];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.multipartWriter = nil;

    self.data = nil;

    self.pathToNonExistingFile = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
    self.path = nil;

    [super tearDown];
}

- (void)testWriterIsNotOpenAfterCreation
{
    XCTAssertFalse([self.multipartWriter isBlobOpen], @"After init, blob is not open");
}

- (void)testOpenBlobFailsIfFileDoesNotExist
{
    XCTAssertFalse([self.multipartWriter openBlobAtPath:self.pathToNonExistingFile],
                   @"If the file does not exist yet, it can not be open");
}

- (void)testOpenBlobSucceedsIfFileExists
{
    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.path],
                  @"If the file exists, we should be able to open it");
}

- (void)testOpenBlobFailsIfAlreadyOpen
{
    [self.multipartWriter openBlobAtPath:self.path];

    XCTAssertFalse([self.multipartWriter openBlobAtPath:self.path],
                   @"Close the blob before opening it again");
}

- (void)testOpenBlobToAddDataSucceedsAfterClosingBlob
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter closeBlob];

    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.path],
                  @"As long as the file still exists, we should be able to open it again");
}

- (void)testAddDataFailsIfBlobIsNotOpen
{
    XCTAssertFalse([self.multipartWriter addData:self.data], @"Open blob before adding data");
}

- (void)testAddDataTwiceGenerateExpectedResult
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.path];

    NSMutableData *expectedData = [NSMutableData dataWithData:self.data];
    [expectedData appendData:self.data];

    XCTAssertEqualObjects(
        fileData, expectedData,
        @"Add same data twice should be equal to a buffer with that data copied twice");
}

- (void)testAddDataBeforeClosingBlobAndAfterOpeningBlobGenerateExpectedResult
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.path];

    XCTAssertEqualObjects(
        fileData, self.data,
        @"Data is added at the begining of the blob after opening it");
}

@end
