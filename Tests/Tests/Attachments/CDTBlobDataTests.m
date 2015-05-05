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

@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSString *pathToExistingFile;
@property (strong, nonatomic) CDTBlobData *blob;

@property (strong, nonatomic) NSString *pathToNonExistingFile;
@property (strong, nonatomic) CDTBlobData *blobForNotPrexistingFile;

@end

@implementation CDTBlobDataTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.data = [@"text" dataUsingEncoding:NSUnicodeStringEncoding];

    self.pathToExistingFile =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataTests.txt"];
    [[NSFileManager defaultManager] createFileAtPath:self.pathToExistingFile
                                            contents:nil
                                          attributes:nil];

    self.blob = [[CDTBlobData alloc] initWithPath:self.pathToExistingFile];

    self.pathToNonExistingFile =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"nonExistingFile.txt"];
    self.blobForNotPrexistingFile = [[CDTBlobData alloc] initWithPath:self.pathToNonExistingFile];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.blobForNotPrexistingFile = nil;
    self.pathToNonExistingFile = nil;

    self.blob = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.pathToExistingFile error:nil];
    self.pathToExistingFile = nil;

    self.data = nil;

    [super tearDown];
}

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

- (void)testBlobIsNotOpenAfterCreation
{
    XCTAssertFalse([self.blob isBlobOpenForWriting], @"After init, blob is not open");
}

- (void)testOpenForWritingFailsIfFileDoesNotExist
{
    XCTAssertFalse([self.blobForNotPrexistingFile openForWriting],
                   @"If the file does not exist yet, it can not be open");
}

- (void)testOpenForWritingSucceedsIfFileExists
{
    XCTAssertTrue([self.blob openForWriting],
                  @"If the file exists, we should be able to open it");
}

- (void)testOpenForWritingSucceedsIfAlreadyOpen
{
    [self.blob openForWriting];

    XCTAssertTrue(
        [self.blob openForWriting],
        @"If the blob is already opened, open it again let the file open, thefore it succeeds");
}

- (void)testOpenForWritingSucceedsAfterClosingBlob
{
    [self.blob openForWriting];
    [self.blob close];

    XCTAssertTrue([self.blob openForWriting],
                  @"As long as the file still exists, we should be able to open it again");
}

- (void)testAppendDataFailsIfBlobIsNotOpen
{
    XCTAssertFalse([self.blob appendData:self.data], @"Open blob before adding data");
}

- (void)testDataWithErrorFailsIfBlobIsOpen
{
    [self.blob openForWriting];

    NSError *error = nil;
    NSData *data = [self.blob dataWithError:&error];

    XCTAssertNil(data, @"Blob can not be read if it is open");
    XCTAssertTrue([error.domain isEqualToString:CDTBlobDataErrorDomain] &&
                      error.code == CDTBlobDataErrorOperationNotPossibleIfBlobIsOpen,
                  @"In this situation the expected error is: (%@, %li)", CDTBlobDataErrorDomain,
                  (long)CDTBlobDataErrorOperationNotPossibleIfBlobIsOpen);
}

- (void)testDataWithErrorFailsIfFileDoesNotExist
{
    NSError *error = nil;
    NSData *data = [self.blobForNotPrexistingFile dataWithError:&error];

    XCTAssertNil(data, @"No data to read if file does not exist");
    XCTAssertNotNil(error, @"An error must be informed");
}

- (void)testInputStreamWithOutputLengthFailsIfBlobIsOpen
{
    [self.blob openForWriting];

    UInt64 length = 0;
    XCTAssertNil([self.blob inputStreamWithOutputLength:&length],
                 @"Close the blob in order to create an input stream bound to the same filea");
}

- (void)testInputStreamWithOutputLengthFailsIfFileDoesNotExist
{
    UInt64 length = 0;
    XCTAssertNil([self.blobForNotPrexistingFile inputStreamWithOutputLength:&length],
                 @"File must exist in order to create an input stream");
}

- (void)testInputStreamWithOutputLengthFailsIfFileDoesNotExistEvenIfIDoNotGetTheLength
{
    XCTAssertNil([self.blobForNotPrexistingFile inputStreamWithOutputLength:nil],
                 @"File must exist in order to create an input stream");
}

- (void)testWriteEntireBlobWithDataFailsIfBlobIsOpen
{
    [self.blob openForWriting];

    NSError *error = nil;
    BOOL success = [self.blob writeEntireBlobWithData:self.data error:&error];

    XCTAssertFalse(success, @"Close the blob in order to overwrite it");
    XCTAssertTrue([error.domain isEqualToString:CDTBlobDataErrorDomain] &&
                      error.code == CDTBlobDataErrorOperationNotPossibleIfBlobIsOpen,
                  @"In this situation the expected error is: (%@, %li)", CDTBlobDataErrorDomain,
                  (long)CDTBlobDataErrorOperationNotPossibleIfBlobIsOpen);
}

- (void)testWriteEntireBlobWithDataSucceedsIfFileExists
{
    XCTAssertTrue([self.blob writeEntireBlobWithData:self.data error:nil],
                  @"The previous data will be overwritten with the next one");
}

- (void)testWriteEntireBlobWithDataSucceedsIfFileDoesNotExist
{
    BOOL success = [self.blobForNotPrexistingFile writeEntireBlobWithData:self.data error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.pathToNonExistingFile error:nil];
    
    XCTAssertTrue(success, @"A new file will be created");
}

@end
