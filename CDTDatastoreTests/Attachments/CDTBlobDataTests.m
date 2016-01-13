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
@property (strong, nonatomic) NSString *pathToNotEmptyFile;
@property (strong, nonatomic) CDTBlobData *blobForNotEmptyFile;

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

    self.pathToNotEmptyFile =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDTBlobDataTests.txt"];

    NSData *otherData = [@"Lorem ipsum" dataUsingEncoding:NSASCIIStringEncoding];
    [otherData writeToFile:self.pathToNotEmptyFile atomically:YES];

    self.blobForNotEmptyFile = [[CDTBlobData alloc] initWithPath:self.pathToNotEmptyFile];

    self.pathToNonExistingFile =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"nonExistingFile.txt"];
    self.blobForNotPrexistingFile = [[CDTBlobData alloc] initWithPath:self.pathToNonExistingFile];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.blobForNotPrexistingFile = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.pathToNonExistingFile error:nil];
    self.pathToNonExistingFile = nil;

    self.blobForNotEmptyFile = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.pathToNotEmptyFile error:nil];
    self.pathToNotEmptyFile = nil;

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
    XCTAssertNotNil([[CDTBlobData alloc] initWithPath:@"///This is not a path"],
                    @"Any string is valid as long as it is not empty");
}

- (void)testOpenBlobToAddDataSucceedsIfFileDoesNotExist
{
    XCTAssertTrue(
        [self.blobForNotPrexistingFile openForWriting],
        @"It does not matter if the file does not exist, it will be created before opening it");
}

- (void)testOpenForWritingSucceedsIfFileExists
{
    XCTAssertTrue([self.blobForNotEmptyFile openForWriting],
                  @"If the file exists, we should be able to open it");
}

- (void)testOpenForWritingFailsIfPathIsNotValid
{
    CDTBlobData *blob = [[CDTBlobData alloc] initWithPath:@"///This is not a path"];

    XCTAssertFalse([blob openForWriting], @"It should fail if the path is not valid");
}

- (void)testOpenForWritingCreatesEmptyFile
{
    [self.blobForNotPrexistingFile openForWriting];

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.pathToNonExistingFile];
    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertTrue(fileExists && (fileData.length == 0),
                  @"An empty file is created after opening the blob");
}

- (void)testOpenForWritingSucceedsIfAlreadyOpen
{
    [self.blobForNotEmptyFile openForWriting];

    XCTAssertTrue(
        [self.blobForNotEmptyFile openForWriting],
        @"If the blob is already opened, open it again let the file open, thefore it succeeds");
}

- (void)testOpenForWritingClearTheContentOfTheFile
{
    [self.blobForNotEmptyFile openForWriting];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertEqual(fileData.length, 0, @"The file should be empty after opening the blob");
}

- (void)testOpenForWritingDoesNotClearTheContentOfTheFileIfItIsAlreadyOpen
{
    [self.blobForNotPrexistingFile openForWriting];
    [self.blobForNotPrexistingFile appendData:self.data];

    [self.blobForNotPrexistingFile openForWriting];

    [self.blobForNotPrexistingFile close];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertTrue(fileData.length > 0, @"If it is already open, do not clear it");
}

- (void)testOpenBlobToAddDataSucceedsAfterClosingBlob
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile close];

    XCTAssertTrue([self.blobForNotEmptyFile openForWriting],
                  @"As long as the file still exists, we should be able to open it again");
}

- (void)testBlobIsNotOpenAfterCreatingIt
{
    XCTAssertFalse([self.blobForNotEmptyFile isBlobOpenForWriting], @"After init, blob is not open");
}

- (void)testBlobIsOpenAfterOpeningIt
{
    [self.blobForNotEmptyFile openForWriting];

    XCTAssertTrue([self.blobForNotEmptyFile isBlobOpenForWriting], @"Obviously, it is open");
}

- (void)testBlobIsNotOpenAfterClosingIt
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile close];

    XCTAssertFalse([self.blobForNotEmptyFile isBlobOpenForWriting], @"Obviously, it is closed");
}

- (void)testAppendDataFailsIfBlobIsNotOpen
{
    XCTAssertFalse([self.blobForNotEmptyFile appendData:self.data],
                   @"Open blob before adding data");
}

- (void)testAppendDataFailsIfDataIsNil
{
    [self.blobForNotEmptyFile openForWriting];

    XCTAssertFalse([self.blobForNotEmptyFile appendData:nil],
                   @"It should fail if there is no data to add");
}

- (void)testAppendDataIncreasesTheSizeOfTheFile
{
    [self.blobForNotEmptyFile openForWriting];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];
    NSUInteger previousFileDataLength = fileData.length;

    [self.blobForNotEmptyFile appendData:self.data];

    fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertTrue(fileData.length > previousFileDataLength,
                  @"'addData:' add the new data to the file straight away");
}

- (void)testCloseBlobWithoutAddingDataGeneratesAnEmptyFile
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile close];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertEqual(fileData.length, 0, @"The file should remain empty if no data is added");
}

- (void)testDataWithErrorFailsIfBlobIsOpen
{
    [self.blobForNotEmptyFile openForWriting];

    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

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
    [self.blobForNotEmptyFile openForWriting];

    UInt64 length = 0;
    XCTAssertNil([self.blobForNotEmptyFile inputStreamWithOutputLength:&length],
                 @"Close the blob in order to create an input stream bound to the same file");
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
    [self.blobForNotEmptyFile openForWriting];

    NSError *error = nil;
    BOOL success = [self.blobForNotEmptyFile writeEntireBlobWithData:self.data error:&error];

    XCTAssertFalse(success, @"Close the blob in order to overwrite it");
    XCTAssertTrue([error.domain isEqualToString:CDTBlobDataErrorDomain] &&
                      error.code == CDTBlobDataErrorOperationNotPossibleIfBlobIsOpen,
                  @"In this situation the expected error is: (%@, %li)", CDTBlobDataErrorDomain,
                  (long)CDTBlobDataErrorOperationNotPossibleIfBlobIsOpen);
}

- (void)testWriteEntireBlobWithDataSucceedsIfFileExists
{
    XCTAssertTrue([self.blobForNotEmptyFile writeEntireBlobWithData:self.data error:nil],
                  @"The previous data will be overwritten with the next one");
}

- (void)testWriteEntireBlobWithDataSucceedsIfFileDoesNotExist
{
    BOOL success = [self.blobForNotPrexistingFile writeEntireBlobWithData:self.data error:nil];

    XCTAssertTrue(success, @"A new file will be created");
}

- (void)testWriteEntireBlobWithDataFailsIfDataIsNil
{
    NSError *error = nil;
    BOOL success = [self.blobForNotEmptyFile writeEntireBlobWithData:nil error:&error];

    XCTAssertFalse(success, @"Provide some data to create the blob");
    XCTAssertTrue([error.domain isEqualToString:CDTBlobDataErrorDomain] &&
                      error.code == CDTBlobDataErrorNoDataProvided,
                  @"In this situation the expected error is: (%@, %li)", CDTBlobDataErrorDomain,
                  (long)CDTBlobDataErrorNoDataProvided);
}

- (void)testWriteEntireBlobWithDataSucceedsIfDataIsEmpty
{
    NSError *error = nil;
    BOOL success = [self.blobForNotPrexistingFile writeEntireBlobWithData:[NSData data] error:&error];

    XCTAssertTrue(success, @"A new file will be created");
    XCTAssertNil(error, @"No error to report");
}

- (void)testWriteEntireBlobWithDataOverwritesThePreviousContent
{
    [self.blobForNotEmptyFile writeEntireBlobWithData:self.data error:nil];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertEqualObjects(
        fileData, self.data,
        @"After creating a blob, the only content in the file should be the data we just provided");
}

- (void)testAppendDataOverwritesThePreviousContent
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile appendData:self.data];
    [self.blobForNotEmptyFile appendData:self.data];
    [self.blobForNotEmptyFile close];

    NSMutableData *expectedData = [NSMutableData dataWithData:self.data];
    [expectedData appendData:self.data];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertEqualObjects(fileData, expectedData, @"Only the added data should be in the file");
}

- (void)testFileCreatedAfterOpeningABlobIsNotDeletedAfterClosingEvenIfNoDataIsAdded
{
    [self.blobForNotPrexistingFile openForWriting];
    [self.blobForNotPrexistingFile close];

    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.pathToNonExistingFile],
                  @"The blob creates a file, it is user responsability to delete it");
}

@end
