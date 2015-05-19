//
//  CDTBlobEncryptedDataWriterTests.m
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

#import "CDTBlobEncryptedDataWriter.h"
#import "CDTBlobEncryptedDataUtils.h"

#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTHelperFixedKeyProvider.h"

#import "TDMisc.h"

@interface CDTBlobEncryptedDataWriterTests : XCTestCase

@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *otherPath;

@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSData *otherData;

@property (strong, nonatomic) CDTEncryptionKey *encryptionKey;

@property (strong, nonatomic) CDTBlobEncryptedDataWriter *writer;

@end

@implementation CDTBlobEncryptedDataWriterTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataWriterTests_01.txt"];
    self.otherPath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataWriterTests_02.txt"];

    self.data = [@"摇;摃:xx👹⌚️👽" dataUsingEncoding:NSUnicodeStringEncoding];
    self.otherData = [@"摇;摃:§婘栰" dataUsingEncoding:NSUnicodeStringEncoding];

    CDTHelperFixedKeyProvider *provider = [[CDTHelperFixedKeyProvider alloc] init];
    self.encryptionKey = [provider encryptionKey];

    self.writer = [CDTBlobEncryptedDataWriter writerWithEncryptionKey:self.encryptionKey];
    [self.writer useData:self.data];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.writer = nil;

    self.encryptionKey = nil;

    self.data = nil;
    self.otherData = nil;

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:self.path error:nil];
    self.path = nil;

    [defaultManager removeItemAtPath:self.otherPath error:nil];
    self.otherPath = nil;

    [super tearDown];
}

- (void)testInitWithEncryptionKeyEqualToNilFails
{
    XCTAssertNil([[CDTBlobEncryptedDataWriter alloc] initWithEncryptionKey:nil],
                 @"An encryption key is mandatory");
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
    NSData *decryptedData =
        (fileData ? [CDTEncryptionKeychainUtils doDecrypt:fileData
                                                  withKey:self.encryptionKey.data
                                                       iv:CDTBlobEncryptedDataDefaultIV()]
                  : nil);
    BOOL isExpectedData = (decryptedData && [decryptedData isEqualToData:self.data]);

    XCTAssertTrue(success, @"Operation should succeed");
    XCTAssertNil(error, @"There is no error to inform");
    XCTAssertTrue(isExpectedData, @"Data as expected");
}

- (void)testWriteToFileSucceedsIfItIsCalledASecondTimeWithADifferentPath
{
    [self.writer writeToFile:self.path error:nil];

    NSError *error = nil;
    BOOL success = [self.writer writeToFile:self.otherPath error:&error];

    NSData *fileData = [NSData dataWithContentsOfFile:self.otherPath];
    NSData *decryptedData =
        (fileData ? [CDTEncryptionKeychainUtils doDecrypt:fileData
                                                  withKey:self.encryptionKey.data
                                                       iv:CDTBlobEncryptedDataDefaultIV()]
                  : nil);
    BOOL isExpectedData = (decryptedData && [decryptedData isEqualToData:self.data]);

    XCTAssertTrue(success, @"Operation should succeed");
    XCTAssertNil(error, @"There is no error to inform");
    XCTAssertTrue(isExpectedData, @"Data as expected");
}

- (void)testWriteToFileSucceedsIfItIsCalledASecondTimeWithTheSamePathAndDifferentData
{
    [self.writer writeToFile:self.path error:nil];

    [self.writer useData:self.otherData];

    NSError *error = nil;
    BOOL success = [self.writer writeToFile:self.path error:&error];

    NSData *fileData = [NSData dataWithContentsOfFile:self.path];
    NSData *decryptedData =
        (fileData ? [CDTEncryptionKeychainUtils doDecrypt:fileData
                                                  withKey:self.encryptionKey.data
                                                       iv:CDTBlobEncryptedDataDefaultIV()]
                  : nil);
    BOOL isExpectedData = (decryptedData && [decryptedData isEqualToData:self.otherData]);

    XCTAssertTrue(success, @"Operation should succeed");
    XCTAssertNil(error, @"There is no error to inform");
    XCTAssertTrue(isExpectedData, @"Data as expected");
}

- (void)testSHA1DigestIsNilIfThereIsNoData
{
    [self.writer useData:nil];

    XCTAssertNil(self.writer.sha1Digest, @"No data, no digest");
}

- (void)testSHA1DigestReturnsExpectedValues
{
    [self.writer useData:self.data];
    [self.writer writeToFile:self.path error:nil];
    
    NSData *fileData = [NSData dataWithContentsOfFile:self.path];
    NSData *expectedDigest = (fileData ? TDSHA1Digest(fileData) : nil);

    XCTAssertEqualObjects(self.writer.sha1Digest, expectedDigest, @"Unexpected result");

    [self.writer useData:self.otherData];
    [self.writer writeToFile:self.path error:nil];
    
    fileData = [NSData dataWithContentsOfFile:self.path];
    expectedDigest = (fileData ? TDSHA1Digest(fileData) : nil);

    XCTAssertEqualObjects(self.writer.sha1Digest, expectedDigest, @"Unexpected result");
}

@end
