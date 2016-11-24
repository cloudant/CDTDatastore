//
//  CDTBlobEncryptedDataTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 21/05/2015.
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

#import "CDTBlobEncryptedData+Internal.h"
// common crypto must be included before encrypted data constants
#import <CommonCrypto/CommonCryptor.h>
#import "CDTBlobEncryptedDataConstants.h"

#import "CDTHelperFixedKeyProvider.h"

#import "CDTMisc.h"
#import "TDBase64.h"

@interface CDTBlobCustomEncryptedData : CDTBlobEncryptedData

@property (strong, nonatomic) NSData *iv;

- (instancetype)initWithPath:(NSString *)path
               encryptionKey:(CDTEncryptionKey *)encryptionKey
                          iv:(NSData *)iv NS_DESIGNATED_INITIALIZER;

@end

@interface CDTBlobEncryptedDataTests : XCTestCase

@property (strong, nonatomic) NSData *ivData;
@property (strong, nonatomic) NSData *otherIVData;

@property (strong, nonatomic) CDTEncryptionKey *encryptionKey;

@property (strong, nonatomic) NSData *plainData;
@property (strong, nonatomic) NSData *encryptedData;
@property (strong, nonatomic) NSData *otherPlainData;
@property (strong, nonatomic) NSData *otherEncryptedData;
@property (strong, nonatomic) NSData *headerData;
@property (strong, nonatomic) NSMutableData *headerPlusEncryptedData;

@property (strong, nonatomic) NSString *pathToNotEmptyFile;
@property (strong, nonatomic) CDTBlobCustomEncryptedData *blobForNotEmptyFile;

@property (strong, nonatomic) NSString *pathToNonExistingFile;
@property (strong, nonatomic) CDTBlobCustomEncryptedData *blobForNotPrexistingFile;

@end

@implementation CDTBlobEncryptedDataTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    NSString *keyStr = @"3271b0b2ae09cf10128893abba0871b64ea933253378d0c65bcbe05befe636c3";
    NSData *keyData = dataFromHexadecimalString(keyStr);

    NSString *ivStr = @"10327cc29f13539f8ce5378318f46137";
    self.ivData = dataFromHexadecimalString(ivStr);

    ivStr = @"00000cc00f00000f0ce0000000f00000";
    self.otherIVData = dataFromHexadecimalString(ivStr);

    CDTHelperFixedKeyProvider *provider = [CDTHelperFixedKeyProvider providerWithKey:keyData];
    self.encryptionKey = [provider encryptionKey];

    self.plainData = [@"摇;摃:xx👹⌚️👽" dataUsingEncoding:NSUnicodeStringEncoding];
    self.encryptedData = [TDBase64 decode:@"H6nWVwfuGB8hDv/dFVUXbU2yb07NzE2vf3HttPF/qps="];

    self.otherPlainData = [@"摇;摃:§婘栰" dataUsingEncoding:NSUnicodeStringEncoding];
    self.otherEncryptedData = [TDBase64 decode:@"+B/AXr0PQrxQSAdMnE8BKKUymEak2akCuGGHIY99lNU="];

    char buffer[sizeof(CDTBLOBENCRYPTEDDATA_VERSION_TYPE) + self.ivData.length];
    memset(buffer + CDTBLOBENCRYPTEDDATA_VERSION_LOCATION, CDTBLOBENCRYPTEDDATA_VERSION_VALUE,
           sizeof(CDTBLOBENCRYPTEDDATA_VERSION_TYPE));
    memcpy(buffer + CDTBLOBENCRYPTEDDATA_IV_LOCATION, self.ivData.bytes, self.ivData.length);
    self.headerData = [NSData dataWithBytes:buffer length:sizeof(buffer)];

    self.headerPlusEncryptedData = [NSMutableData dataWithData:self.headerData];
    [self.headerPlusEncryptedData appendData:self.encryptedData];

    self.pathToNotEmptyFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataTests_notEmpty.txt"];
    [self.headerPlusEncryptedData writeToFile:self.pathToNotEmptyFile atomically:YES];

    self.blobForNotEmptyFile =
        [[CDTBlobCustomEncryptedData alloc] initWithPath:self.pathToNotEmptyFile
                                           encryptionKey:self.encryptionKey
                                                      iv:self.ivData];

    self.pathToNonExistingFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataTests_noExists.txt"];

    self.blobForNotPrexistingFile =
        [[CDTBlobCustomEncryptedData alloc] initWithPath:self.pathToNonExistingFile
                                           encryptionKey:self.encryptionKey
                                                      iv:self.ivData];
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

    self.headerPlusEncryptedData = nil;
    self.headerData = nil;
    self.otherEncryptedData = nil;
    self.otherPlainData = nil;
    self.encryptedData = nil;
    self.plainData = nil;

    self.encryptionKey = nil;

    self.otherIVData = nil;
    self.ivData = nil;

    [super tearDown];
}

- (void)testInitWithPathEqualToNilFails
{
    XCTAssertNil([[CDTBlobEncryptedData alloc] initWithPath:nil encryptionKey:self.encryptionKey],
                 @"A path is mandatory");
}

- (void)testInitWithEmptyPathFails
{
    XCTAssertNil([[CDTBlobEncryptedData alloc] initWithPath:@"" encryptionKey:self.encryptionKey],
                 @"A path is mandatory");
}

- (void)testInitWithNotValidPathSucceeds
{
    XCTAssertNotNil([[CDTBlobEncryptedData alloc] initWithPath:@"///This is not a path"
                                                 encryptionKey:self.encryptionKey],
                    @"Any string is valid as long as it is not empty");
}

- (void)testInitWithEncryptionKeyEqualToNilFails
{
    XCTAssertNil(
        [[CDTBlobEncryptedData alloc] initWithPath:self.pathToNonExistingFile encryptionKey:nil],
        @"An encryption key is mandatory");
}

- (void)testDataWithErrorFailsIfBlobIsOpen
{
    [self.blobForNotEmptyFile openForWriting];

    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

    XCTAssertNil(data, @"Blob can not be read if it is open");
    XCTAssertNotNil(error, @"An error is expected in this case");
}

- (void)testDataWithErrorFailsIfFileDoesNotExist
{
    NSError *error = nil;
    NSData *data = [self.blobForNotPrexistingFile dataWithError:&error];

    XCTAssertNil(data, @"No data to read if file does not exist");
    XCTAssertNotNil(error, @"An error must be informed");
}

- (void)testDataWithErrorFailsIfFileDoesNotHaveTheMinimumSize
{
    NSData *fileData =
        [self.headerData subdataWithRange:NSMakeRange(0, self.headerData.length - 1)];
    [fileData writeToFile:self.pathToNotEmptyFile atomically:YES];

    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

    XCTAssertNil(data, @"Data is not encrypted or is corrupted");
    XCTAssertTrue(error && [error.domain isEqualToString:CDTBlobEncryptedDataErrorDomain] &&
                      (error.code == CDTBlobEncryptedDataErrorFileTooSmall),
                  @"In this situation the expected error is: (%@, %li)",
                  CDTBlobEncryptedDataErrorDomain, (long)CDTBlobEncryptedDataErrorFileTooSmall);
}

- (void)testDataWithErrorFailsIfFileStartsWithVersion0
{
    NSMutableData *fileData = [NSMutableData dataWithData:self.headerData];

    CDTBLOBENCRYPTEDDATA_VERSION_TYPE wrongVersion = 0;
    [fileData replaceBytesInRange:NSMakeRange(CDTBLOBENCRYPTEDDATA_VERSION_LOCATION,
                                              sizeof(CDTBLOBENCRYPTEDDATA_VERSION_TYPE))
                        withBytes:&wrongVersion];

    [fileData writeToFile:self.pathToNotEmptyFile atomically:YES];

    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

    XCTAssertNil(data, @"Data is not encrypted, is corrupted or the version is wrong");
    XCTAssertTrue(error && [error.domain isEqualToString:CDTBlobEncryptedDataErrorDomain] &&
                      (error.code == CDTBlobEncryptedDataErrorWrongVersion),
                  @"In this situation the expected error is: (%@, %li)",
                  CDTBlobEncryptedDataErrorDomain, (long)CDTBlobEncryptedDataErrorWrongVersion);
}

- (void)testDataWithErrorFailsIfFileDoesNotStartWithCorrectVersion
{
    NSMutableData *fileData = [NSMutableData dataWithData:self.headerData];

    CDTBLOBENCRYPTEDDATA_VERSION_TYPE wrongVersion = (CDTBLOBENCRYPTEDDATA_VERSION_VALUE + 1);
    [fileData replaceBytesInRange:NSMakeRange(CDTBLOBENCRYPTEDDATA_VERSION_LOCATION,
                                              sizeof(CDTBLOBENCRYPTEDDATA_VERSION_TYPE))
                        withBytes:&wrongVersion];

    [fileData writeToFile:self.pathToNotEmptyFile atomically:YES];

    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

    XCTAssertNil(data, @"Data is not encrypted, is corrupted or the version is wrong");
    XCTAssertTrue(error && [error.domain isEqualToString:CDTBlobEncryptedDataErrorDomain] &&
                      (error.code == CDTBlobEncryptedDataErrorWrongVersion),
                  @"In this situation the expected error is: (%@, %li)",
                  CDTBlobEncryptedDataErrorDomain, (long)CDTBlobEncryptedDataErrorWrongVersion);
}

- (void)testDataWithErrorReturnsEmptyIfThereIsNotEncryptedData
{
    [self.headerData writeToFile:self.pathToNotEmptyFile atomically:YES];

    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

    XCTAssertTrue(data && (data.length == 0),
                  @"It is OK is there is not encrypted data but it has to return an empty buffer");
    XCTAssertNil(error, @"No error to report");
}

- (void)testDataWithErrorReturnsExpectedData
{
    NSError *error = nil;
    NSData *data = [self.blobForNotEmptyFile dataWithError:&error];

    XCTAssertEqualObjects(data, self.plainData, @"Unexpected result");
    XCTAssertNil(error, @"No error to report");
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
    BOOL success =
        [self.blobForNotEmptyFile writeEntireBlobWithData:self.otherPlainData error:&error];

    XCTAssertFalse(success, @"Close the blob in order to overwrite it");
    XCTAssertNotNil(error, @"An error is expected in this situation");
}

- (void)testWriteEntireBlobWithDataSucceedsIfFileExists
{
    NSError *error = nil;
    BOOL success =
        [self.blobForNotEmptyFile writeEntireBlobWithData:self.otherPlainData error:&error];

    XCTAssertTrue(success, @"The previous data will be overwritten with the next one");
    XCTAssertNil(error, @"No error to report");
}

- (void)testWriteEntireBlobWithDataSucceedsIfFileDoesNotExist
{
    NSError *error = nil;
    BOOL success =
        [self.blobForNotPrexistingFile writeEntireBlobWithData:self.plainData error:&error];

    XCTAssertTrue(success, @"A new file will be created");
    XCTAssertNil(error, @"No error to report");
}

- (void)testWriteEntireBlobWithDataFailsIfDataIsNil
{
    NSError *error = nil;
    BOOL success = [self.blobForNotEmptyFile writeEntireBlobWithData:nil error:&error];

    XCTAssertFalse(success, @"Provide some data to create the blob");
    XCTAssertTrue(error && [error.domain isEqualToString:CDTBlobEncryptedDataErrorDomain] &&
                      error.code == CDTBlobEncryptedDataErrorNoDataProvided,
                  @"In this situation the expected error is: (%@, %li)",
                  CDTBlobEncryptedDataErrorDomain, (long)CDTBlobEncryptedDataErrorNoDataProvided);
}

- (void)testWriteEntireBlobWithDataSucceedsIfDataIsEmpty
{
    NSError *error = nil;
    BOOL success =
        [self.blobForNotPrexistingFile writeEntireBlobWithData:[NSData data] error:&error];

    XCTAssertTrue(success, @"A new file will be created");
    XCTAssertNil(error, @"No error to report");
}

- (void)testWriteEntireBlobWithDataCreatesFileWithExpectedData
{
    [self.blobForNotPrexistingFile writeEntireBlobWithData:self.plainData error:nil];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertEqualObjects(fileData, self.headerPlusEncryptedData, @"Unexpected result");
}

- (void)testwriteEntireBlobWithEmptyDataCreatesFileWithExpectedData
{
    [self.blobForNotPrexistingFile writeEntireBlobWithData:[NSData data] error:nil];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertEqualObjects(fileData, self.headerData, @"Unexpected result");
}

- (void)testWriteEntireBlobWithDataOverwritesThePreviousContent
{
    [self.blobForNotEmptyFile writeEntireBlobWithData:self.otherPlainData error:nil];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    NSMutableData *expectedData = [NSMutableData dataWithData:self.headerData];
    [expectedData appendData:self.otherEncryptedData];

    XCTAssertEqualObjects(fileData, expectedData, @"Unexpected result");
}

- (void)testWriteEntireBlobWithDataGeneratesDifferentFileDatas
{
    [self.blobForNotPrexistingFile writeEntireBlobWithData:self.plainData error:nil];
    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    self.blobForNotPrexistingFile.iv = self.otherIVData;

    [self.blobForNotPrexistingFile writeEntireBlobWithData:self.plainData error:nil];
    NSData *otherFileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertNotEqualObjects(fileData, otherFileData,
                             @"Different IVs should generate different encrypted data");
}

- (void)testOpenForWritingSucceedsIfFileDoesNotExist
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
    CDTBlobEncryptedData *blob = [[CDTBlobEncryptedData alloc] initWithPath:@"///This is not a path"
                                                              encryptionKey:self.encryptionKey];

    XCTAssertFalse([blob openForWriting], @"It should fail if the path is not valid");
}

- (void)testOpenForWritingCreatesFileOnlyWithHeader
{
    [self.blobForNotPrexistingFile openForWriting];

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.pathToNonExistingFile];
    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertTrue(fileExists, @"A file is created after opening the blob");
    XCTAssertEqualObjects(fileData, self.headerData,
                          @"The only content in the file should be the header");
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

    XCTAssertEqualObjects(fileData, self.headerData,
                          @"The only content in the file should be the header");
}

- (void)testOpenForWritingDoesNotClearTheContentOfTheFileIfItIsAlreadyOpen
{
    [self.blobForNotPrexistingFile openForWriting];
    [self.blobForNotPrexistingFile appendData:self.plainData];

    [self.blobForNotPrexistingFile openForWriting];

    [self.blobForNotPrexistingFile close];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertEqualObjects(fileData, self.headerPlusEncryptedData,
                          @"If it is already open, do not clear it");
}

- (void)testOpenForWritingSucceedsAfterClosingBlob
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile close];

    XCTAssertTrue([self.blobForNotEmptyFile openForWriting],
                  @"As long as the file still exists, we should be able to open it again");
}

- (void)testBlobIsNotOpenAfterCreatingIt
{
    XCTAssertFalse([self.blobForNotEmptyFile isBlobOpenForWriting],
                   @"After init, blob is not open");
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
    XCTAssertFalse([self.blobForNotEmptyFile appendData:self.plainData],
                   @"Open blob before adding data");
}

- (void)testAppendDataFailsIfDataIsNil
{
    [self.blobForNotEmptyFile openForWriting];

    XCTAssertFalse([self.blobForNotEmptyFile appendData:nil],
                   @"It should fail if there is no data to add");
}

- (void)testAppendDataDoesNotIncreasesTheSizeOfTheFile
{
    [self.blobForNotEmptyFile openForWriting];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];
    NSUInteger previousFileDataLength = fileData.length;

    [self.blobForNotEmptyFile appendData:self.otherPlainData];

    fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertEqual(fileData.length, previousFileDataLength,
                   @"'addData:' does not update the file, 'closeBlob' does it");
}

- (void)testCloseBlobWithoutAddingDataGeneratesOnlyAHeader
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile close];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertEqualObjects(fileData, self.headerData, @"Unexpected result");
}

- (void)testAppendDataOverwritesThePreviousContent
{
    [self.blobForNotEmptyFile openForWriting];
    [self.blobForNotEmptyFile appendData:self.otherPlainData];
    [self.blobForNotEmptyFile close];

    NSMutableData *expectedData = [NSMutableData dataWithData:self.headerData];
    [expectedData appendData:self.otherEncryptedData];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNotEmptyFile];

    XCTAssertEqualObjects(fileData, expectedData, @"Only the added data should be in the file");
}

- (void)testCloseBlobGeneratesDifferentFileDatas
{
    [self.blobForNotPrexistingFile openForWriting];
    [self.blobForNotPrexistingFile appendData:self.plainData];
    [self.blobForNotPrexistingFile close];
    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    self.blobForNotPrexistingFile.iv = self.otherIVData;

    [self.blobForNotPrexistingFile openForWriting];
    [self.blobForNotPrexistingFile appendData:self.plainData];
    [self.blobForNotPrexistingFile close];
    NSData *otherFileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertNotEqualObjects(fileData, otherFileData,
                             @"Different IVs should generate different encrypted data");
}

- (void)testOpenBlobTwiceDoesNotChangeTheIV
{
    [self.blobForNotPrexistingFile openForWriting];

    self.blobForNotPrexistingFile.iv = self.otherIVData;
    [self.blobForNotPrexistingFile openForWriting];

    [self.blobForNotPrexistingFile appendData:self.plainData];
    [self.blobForNotPrexistingFile close];

    NSData *fileData = [NSData dataWithContentsOfFile:self.pathToNonExistingFile];

    XCTAssertEqualObjects(
        fileData, self.headerPlusEncryptedData,
        @"Once the blob is open, the IV does not change until it is closed and open again ");
}

- (void)testFileCreatedAfterOpeningABlobIsNotDeletedAfterClosingEvenIfNoDataIsAdded
{
    [self.blobForNotPrexistingFile openForWriting];
    [self.blobForNotPrexistingFile close];

    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.pathToNonExistingFile],
                  @"The blob creates a file, it is user responsability to delete it");
}

@end

@implementation CDTBlobCustomEncryptedData

#pragma mark - Init object
- (instancetype)initWithPath:(NSString *)path encryptionKey:(CDTEncryptionKey *)encryptionKey
{
    return [self initWithPath:path encryptionKey:encryptionKey iv:nil];
}

- (instancetype)initWithPath:(NSString *)path
               encryptionKey:(CDTEncryptionKey *)encryptionKey
                          iv:(NSData *)iv
{
    self = [super initWithPath:path encryptionKey:encryptionKey];
    if (self) {
        _iv = iv;
    }

    return self;
}

#pragma mark - CDTBlobEncryptedData+Internal methods
- (NSData *)generateAESIv { return (self.iv ? self.iv : [super generateAESIv]); }
@end
