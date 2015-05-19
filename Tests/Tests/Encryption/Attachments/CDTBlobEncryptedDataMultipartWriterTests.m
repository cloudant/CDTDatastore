//
//  CDTBlobEncryptedDataMultipartWriterTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 18/05/2015.
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

#import "CDTBlobEncryptedDataMultipartWriter.h"
#import "CDTBlobEncryptedDataUtils.h"

#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTHelperFixedKeyProvider.h"

#import "TDMisc.h"

@interface CDTBlobEncryptedDataMultipartWriterTests : XCTestCase

@property (strong, nonatomic) NSString *notValidPath;
@property (strong, nonatomic) NSString *pathToExistingFile;
@property (strong, nonatomic) NSString *pathToNonExistingFile;

@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSData *otherData;

@property (strong, nonatomic) CDTEncryptionKey *encryptionKey;

@property (strong, nonatomic) CDTBlobEncryptedDataMultipartWriter *multipartWriter;

@end

@implementation CDTBlobEncryptedDataMultipartWriterTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.notValidPath = @"///This is not a path";

    self.pathToExistingFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataMultipartWriterTests.txt"];
    [[NSFileManager defaultManager] createFileAtPath:self.pathToExistingFile
                                            contents:nil
                                          attributes:nil];

    self.pathToNonExistingFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataMultipartWriterTests_noExists.txt"];

    self.data = [@"摇;摃:xx👹⌚️👽" dataUsingEncoding:NSUnicodeStringEncoding];
    self.otherData = [@"摇;摃:§婘栰" dataUsingEncoding:NSUnicodeStringEncoding];

    CDTHelperFixedKeyProvider *provider = [[CDTHelperFixedKeyProvider alloc] init];
    self.encryptionKey = [provider encryptionKey];

    self.multipartWriter =
        [[CDTBlobEncryptedDataMultipartWriter alloc] initWithEncryptionKey:self.encryptionKey];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    if (self.multipartWriter) {
        [self.multipartWriter closeBlob];
        self.multipartWriter = nil;
    }

    self.encryptionKey = nil;

    self.data = nil;
    self.otherData = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.pathToNonExistingFile error:nil];
    self.pathToNonExistingFile = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.pathToExistingFile error:nil];
    self.pathToExistingFile = nil;

    [super tearDown];
}

- (void)testInitWithEncryptionKeyEqualToNilFails
{
    XCTAssertNil([[CDTBlobEncryptedDataMultipartWriter alloc] initWithEncryptionKey:nil],
                 @"An encryption key is mandatory");
}

- (void)testWriterIsNotOpenAfterCreation
{
    XCTAssertFalse([self.multipartWriter isBlobOpen], @"After init, blob is not open");
}

- (void)testOpenBlobFailsIfPathIsNil
{
    XCTAssertFalse([self.multipartWriter openBlobAtPath:nil], @"Path is mandatory");
}

- (void)testOpenBlobFailsIfPathIsEmpty
{
    XCTAssertFalse([self.multipartWriter openBlobAtPath:@""], @"Path is mandatory");
}

- (void)testOpenBlobSucceedsWithANonValidPath
{
    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.notValidPath],
                  @"Any string is valid as long as it is not empty");
}

- (void)testOpenBlobSuccedsIfFileDoesNotExist
{
    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.pathToNonExistingFile],
                  @"Any path is valid");
}

- (void)testOpenBlobSucceedsIfFileExists
{
    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.pathToExistingFile],
                  @"If the file exists, we should be able to open it");
}

- (void)testOpenBlobFailsIfAlreadyOpen
{
    [self.multipartWriter openBlobAtPath:self.pathToExistingFile];

    XCTAssertFalse([self.multipartWriter openBlobAtPath:self.pathToExistingFile],
                   @"Close the blob before opening it again");
}

- (void)testOpenBlobToAddDataSucceedsAfterClosingBlob
{
    [self.multipartWriter openBlobAtPath:self.pathToExistingFile];
    [self.multipartWriter closeBlob];

    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.pathToExistingFile],
                  @"You can open a blob as many times as you want as long as you close it first");
}

- (void)testAddDataFailsIfBlobIsNotOpen
{
    XCTAssertFalse([self.multipartWriter addData:self.data], @"Open blob before adding data");
}

- (void)testAddDataFailsIfDataIsNil
{
    XCTAssertFalse([self.multipartWriter addData:nil], @"Param is mandatory");
}

- (void)testCloseBlobFailIfBlobIsNotOpen
{
    XCTAssertFalse([self.multipartWriter closeBlob], @"Open blob in order to close it");
}

- (void)testCloseBlobFailsIfPathIsNotValid
{
    [self.multipartWriter openBlobAtPath:self.notValidPath];
    [self.multipartWriter addData:self.data];

    XCTAssertFalse([self.multipartWriter closeBlob],
                   @"Data can not be saved is the path is not valid");
}

- (void)testCloseBlobSucceedsIfFileDidNoExistBefore
{
    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:self.data];

    XCTAssertTrue([self.multipartWriter closeBlob], @"Operation should succeed");
}

- (void)testCloseBlobSucceedsIfNoDataAdded
{
    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    XCTAssertTrue([self.multipartWriter closeBlob], @"Operation should succeed");
}

- (void)testCloseBlobDoesNotCreateAFileIfNoDataAdded
{
    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter closeBlob];

    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.pathToNonExistingFile],
                   @"Do not create a file if there is no data to save");
}

- (void)testAddDataTwiceGenerateExpectedResult
{
    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    NSMutableData *addedData = [NSMutableData dataWithData:self.data];
    [addedData appendData:self.data];
    NSData *cipheredData = [CDTEncryptionKeychainUtils doEncrypt:addedData
                                                         withKey:self.encryptionKey.data
                                                              iv:CDTBlobEncryptedDataDefaultIV()];

    XCTAssertEqualObjects(
        fileData, cipheredData,
        @"Add same data twice should be equal to a buffer with that data copied twice");
}

- (void)testAddDataBeforeClosingBlobAndAfterOpeningBlobGenerateExpectedResult
{
    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:self.otherData];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    NSData *cipheredData = [CDTEncryptionKeychainUtils doEncrypt:self.otherData
                                                         withKey:self.encryptionKey.data
                                                              iv:CDTBlobEncryptedDataDefaultIV()];

    XCTAssertEqualObjects(fileData, cipheredData,
                          @"Data is added at the begining of the blob after opening it");
}

- (void)testSHA1DigestIsNilAfterInitialisation
{
    XCTAssertNil(self.multipartWriter.sha1Digest, @"No data after init so it has to be nil");
}

- (void)testSHA1DigestIsNilAfterOpeningABlob
{
    [self.multipartWriter openBlobAtPath:self.pathToExistingFile];

    XCTAssertNil(self.multipartWriter.sha1Digest,
                 @"No data after opening the blob, so it has to be nil");
}

- (void)testSHA1DigestIsNilBeforeClosingTheBlob
{
    [self.multipartWriter openBlobAtPath:self.pathToExistingFile];
    [self.multipartWriter addData:self.data];

    XCTAssertNil(self.multipartWriter.sha1Digest,
                 @"No digest will be generated unti the blob is closed");
}

- (void)testSHA1DigestIsNilIfNoDataIsAdded
{
    [self.multipartWriter openBlobAtPath:self.pathToExistingFile];
    [self.multipartWriter closeBlob];

    XCTAssertNil(self.multipartWriter.sha1Digest, @"No data added so it has to be nil");
}

- (void)testSHA1DigestReturnsExpectedValues
{
    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];
    NSData *expectedDigest = TDSHA1Digest(fileData);

    XCTAssertEqualObjects(self.multipartWriter.sha1Digest, expectedDigest, @"Unexpected result");

    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:self.otherData];
    [self.multipartWriter closeBlob];

    fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];
    expectedDigest = TDSHA1Digest(fileData);

    XCTAssertEqualObjects(self.multipartWriter.sha1Digest, expectedDigest, @"Unexpected result");
}

- (void)testSHA1DigestReturnsExpectedValuesIfDataAddedByPieces
{
    NSData *subData01 = [self.data subdataWithRange:NSMakeRange(0, self.data.length / 2)];
    NSData *subData02 = [self.data
        subdataWithRange:NSMakeRange(subData01.length, self.data.length - subData01.length)];

    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:subData01];
    [self.multipartWriter addData:subData02];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];
    NSData *expectedDigest = TDSHA1Digest(fileData);

    XCTAssertEqualObjects(self.multipartWriter.sha1Digest, expectedDigest, @"Unexpected result");

    subData01 = [self.otherData subdataWithRange:NSMakeRange(0, self.otherData.length / 2)];
    subData02 = [self.otherData
        subdataWithRange:NSMakeRange(subData01.length, self.otherData.length - subData01.length)];

    [self.multipartWriter openBlobAtPath:self.pathToNonExistingFile];
    [self.multipartWriter addData:subData01];
    [self.multipartWriter addData:subData02];
    [self.multipartWriter closeBlob];

    fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];
    expectedDigest = TDSHA1Digest(fileData);

    XCTAssertEqualObjects(self.multipartWriter.sha1Digest, expectedDigest, @"Unexpected result");
}

@end
