//
//  CDTBlobDataWriterTests.m
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

#import "CDTBlobDataWriter.h"

@interface CDTBlobDataWriterTests : XCTestCase

@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *otherPath;
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSData *otherData;
@property (strong, nonatomic) CDTBlobDataWriter *writer;

@end

@implementation CDTBlobDataWriterTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataWriterTests_01.txt"];
    self.otherPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataWriterTests_02.txt"];

    self.data = [@"Lorem ipsum 01" dataUsingEncoding:NSASCIIStringEncoding];
    self.otherData = [@"Lorem ipsum 02" dataUsingEncoding:NSASCIIStringEncoding];

    self.writer = [CDTBlobDataWriter writer];
    [self.writer useData:self.data];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.writer = nil;

    self.data = nil;
    self.otherData = nil;

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:self.path error:nil];
    self.path = nil;

    [defaultManager removeItemAtPath:self.otherPath error:nil];
    self.otherPath = nil;

    [super tearDown];
}

- (void)testWriteToFileFailsIfNoDataIsSupplied
{
    [self.writer useData:nil];

    NSError *error = nil;
    BOOL success = [self.writer writeToFile:self.path error:&error];

    XCTAssertFalse(success, @"Op. can not succeed if there is no data");
    XCTAssertNotNil(error, @"An error must be informed if the op. fails");
}

- (void)testWriteToFileFailsIfPathIsNil
{
    NSError *error = nil;
    BOOL success = [self.writer writeToFile:nil error:&error];

    XCTAssertFalse(success, @"Op. can not succeed if we do not know where to create the file");
    XCTAssertNotNil(error, @"An error must be informed if the op. fails");
}

- (void)testWriteToFileFailsIfPathIsEmpty
{
    NSError *error = nil;
    BOOL success = [self.writer writeToFile:@"" error:&error];

    XCTAssertFalse(success, @"Op. can not succeed if we do not know where to create the file");
    XCTAssertNotNil(error, @"An error must be informed if the op. fails");
}

- (void)testWriteToFileSucceedsIfDataAndPathAreSupplied
{
    NSError *error = nil;
    BOOL success = [self.writer writeToFile:self.path error:&error];

    NSData *fileData = [NSData dataWithContentsOfFile:self.path];
    BOOL isExpectedData = (fileData && [fileData isEqualToData:self.data]);

    XCTAssertTrue(success && isExpectedData, @"Operation should succeed");
    XCTAssertNil(error, @"There is no error to inform");
}

- (void)testWriteToFileSucceedsIfItIsCalledASecondTimeWithADifferentPath
{
    [self.writer writeToFile:self.path error:nil];
    
    NSError *error = nil;
    BOOL success = [self.writer writeToFile:self.otherPath error:&error];
    
    NSData *fileData = [NSData dataWithContentsOfFile:self.otherPath];
    BOOL isExpectedData = (fileData && [fileData isEqualToData:self.data]);
    
    XCTAssertTrue(success && isExpectedData, @"Operation should succeed");
    XCTAssertNil(error, @"There is no error to inform");
}

- (void)testWriteToFileSucceedsIfItIsCalledASecondTimeWithTheSamePathAndDifferentData
{
    [self.writer writeToFile:self.path error:nil];
    
    [self.writer useData:self.otherData];
    
    NSError *error = nil;
    BOOL success = [self.writer writeToFile:self.path error:&error];
    
    NSData *fileData = [NSData dataWithContentsOfFile:self.path];
    BOOL isExpectedData = (fileData && [fileData isEqualToData:self.otherData]);
    
    XCTAssertTrue(success && isExpectedData, @"Operation should succeed");
    XCTAssertNil(error, @"There is no error to inform");
}

@end
