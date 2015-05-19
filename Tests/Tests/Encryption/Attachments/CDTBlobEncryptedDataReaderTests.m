//
//  CDTBlobEncryptedDataReaderTests.m
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

#import "CDTBlobEncryptedDataReader.h"
#import "CDTBlobEncryptedDataUtils.h"

#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTHelperFixedKeyProvider.h"

#import "TDBase64.h"

@interface CDTBlobEncryptedDataReaderTests : XCTestCase

@property (strong, nonatomic) NSString *pathToNonExistingFile;

@property (strong, nonatomic) CDTEncryptionKey *encryptionKey;

@property (strong, nonatomic) CDTBlobEncryptedDataReader *readerForNonExistingFile;

@end

@implementation CDTBlobEncryptedDataReaderTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.pathToNonExistingFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobEncryptedDataReaderTests.txt"];

    CDTHelperFixedKeyProvider *provider = [[CDTHelperFixedKeyProvider alloc] init];
    self.encryptionKey = [provider encryptionKey];

    self.readerForNonExistingFile =
        [CDTBlobEncryptedDataReader readerWithPath:self.pathToNonExistingFile
                                     encryptionKey:self.encryptionKey];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.readerForNonExistingFile = nil;

    self.encryptionKey = nil;

    self.pathToNonExistingFile = nil;

    [super tearDown];
}

- (void)testInitWithPathEqualToNilFails
{
    XCTAssertNil(
        [[CDTBlobEncryptedDataReader alloc] initWithPath:nil encryptionKey:self.encryptionKey],
        @"A path is mandatory");
}

- (void)testInitWithEmptyPathFails
{
    XCTAssertNil(
        [[CDTBlobEncryptedDataReader alloc] initWithPath:@"" encryptionKey:self.encryptionKey],
        @"A path is mandatory");
}

- (void)testInitWithNotValidPathSucceeds
{
    XCTAssertNotNil([[CDTBlobEncryptedDataReader alloc] initWithPath:@"///This is not a path"
                                                       encryptionKey:self.encryptionKey],
                    @"Any string is valid as long as it is not empty");
}

- (void)testInitWithEncryptionKeyEqualToNilFails
{
    XCTAssertNil([[CDTBlobEncryptedDataReader alloc] initWithPath:self.pathToNonExistingFile
                                                    encryptionKey:nil],
                 @"An encryption key is mandatory");
}

- (void)testDataWithErrorFailsIfFileDoesNotExist
{
    NSError *error = nil;
    NSData *data = [self.readerForNonExistingFile dataWithError:&error];

    XCTAssertNil(data, @"No data to read if file does not exist");
    XCTAssertNotNil(error, @"An error must be informed");
}

- (void)testInputStreamWithOutputLengthFailsIfFileDoesNotExist
{
    UInt64 length = 0;
    XCTAssertNil([self.readerForNonExistingFile inputStreamWithOutputLength:&length],
                 @"File must exist in order to create an input stream");
}

- (void)testInputStreamWithOutputLengthFailsIfFileDoesNotExistEvenIfIDoNotGetTheLength
{
    XCTAssertNil([self.readerForNonExistingFile inputStreamWithOutputLength:nil],
                 @"File must exist in order to create an input stream");
}

- (void)testDataWithErrorReturnsExpectedValue
{
    NSString *plainText = @"摇;摃:xx👹⌚️👽";
    NSData *plainData = [plainText dataUsingEncoding:NSUnicodeStringEncoding];

    NSData *encryptedData = [CDTEncryptionKeychainUtils doEncrypt:plainData
                                                          withKey:self.encryptionKey.data
                                                               iv:CDTBlobEncryptedDataDefaultIV()];
    [encryptedData writeToFile:self.pathToNonExistingFile atomically:YES];
    
    NSData *readData = [self.readerForNonExistingFile dataWithError:nil];
    
    [[NSFileManager defaultManager] removeItemAtPath:self.pathToNonExistingFile error:nil];
    
    XCTAssertEqualObjects(plainData, readData, @"Unexpected result");
}

@end
