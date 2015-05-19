//
//  TDBlobStoreEncryptionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 19/05/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>

#import "TDBlobStore.h"

#import "CDTBlobEncryptedDataUtils.h"

#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTHelperFixedKeyProvider.h"

#import "TDMisc.h"

@interface TDBlobStoreEncryptionTests : XCTestCase

@property (strong, nonatomic) NSString *blobStorePath;
@property (strong, nonatomic) CDTHelperFixedKeyProvider *provider;
@property (strong, nonatomic) TDBlobStore *blobStore;
@property (strong, nonatomic) TDBlobStoreWriter *blobStoreWriter;

@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSData *encryptedData;
@property (strong, nonatomic) NSData *expectedDigest;

@end

@implementation TDBlobStoreEncryptionTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.blobStorePath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"blobStoreEncryptionTests"];

    self.provider = [[CDTHelperFixedKeyProvider alloc] init];

    self.blobStore = [[TDBlobStore alloc] initWithPath:self.blobStorePath
                                 encryptionKeyProvider:self.provider
                                                 error:nil];

    self.blobStoreWriter = [[TDBlobStoreWriter alloc] initWithStore:self.blobStore];

    self.data = [@"摇;摃:xx👹⌚️👽" dataUsingEncoding:NSUnicodeStringEncoding];
    self.encryptedData = [CDTEncryptionKeychainUtils doEncrypt:self.data
                                                       withKey:self.provider.fixedKey.data
                                                            iv:CDTBlobEncryptedDataDefaultIV()];
    self.expectedDigest = TDSHA1Digest(self.encryptedData);
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.expectedDigest = nil;
    self.encryptedData = nil;
    self.data = nil;

    self.blobStoreWriter = nil;

    self.blobStore = nil;

    self.provider = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.blobStorePath error:nil];
    self.blobStorePath = nil;

    [super tearDown];
}

- (void)testStoreBlobReturnsExpectedKey
{
    TDBlobKey blobKey;
    [self.blobStore storeBlob:self.data creatingKey:&blobKey];

    NSData *key = [NSData dataWithBytes:blobKey.bytes length:sizeof(blobKey.bytes)];

    XCTAssertEqualObjects(key, self.expectedDigest, @"Key must be based on encrypted data");
}

- (void)testStoreBlobSavesEncryptedData
{
    TDBlobKey blobKey;
    [self.blobStore storeBlob:self.data creatingKey:&blobKey];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSArray *fileArray = [defaultManager contentsOfDirectoryAtPath:self.blobStorePath error:nil];
    NSData *fileData = [NSData
        dataWithContentsOfFile:[self.blobStorePath stringByAppendingPathComponent:fileArray[0]]];

    XCTAssertEqualObjects(self.encryptedData, fileData, @"Store only encrypted data");
}

- (void)testBlobForKeyReturnsReaderAbleToReadDataPreviouslySaved
{
    TDBlobKey blobKey;
    [self.blobStore storeBlob:self.data creatingKey:&blobKey];

    id<CDTBlobReader> reader = [self.blobStore blobForKey:blobKey];

    XCTAssertEqualObjects(self.data, [reader dataWithError:nil],
                          @"It has to return the same data previously saved");
}

- (void)testBlobStoreWriterReturnsExpectedKey
{
    NSData *subData01 = [self.data subdataWithRange:NSMakeRange(0, self.data.length / 2)];
    NSData *subData02 = [self.data
        subdataWithRange:NSMakeRange(subData01.length, self.data.length - subData01.length)];

    [self.blobStoreWriter appendData:subData01];
    [self.blobStoreWriter appendData:subData02];
    [self.blobStoreWriter finish];
    [self.blobStoreWriter install];

    NSData *key = [NSData dataWithBytes:self.blobStoreWriter.blobKey.bytes
                                 length:sizeof(self.blobStoreWriter.blobKey.bytes)];

    XCTAssertEqualObjects(self.expectedDigest, key, @"Key must be based on encrypted data");
}

- (void)testBlobStoreWriterSavesEncryptedData
{
    NSData *subData01 = [self.data subdataWithRange:NSMakeRange(0, self.data.length / 2)];
    NSData *subData02 = [self.data
        subdataWithRange:NSMakeRange(subData01.length, self.data.length - subData01.length)];

    [self.blobStoreWriter appendData:subData01];
    [self.blobStoreWriter appendData:subData02];
    [self.blobStoreWriter finish];
    [self.blobStoreWriter install];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSArray *fileArray = [defaultManager contentsOfDirectoryAtPath:self.blobStorePath error:nil];
    NSData *fileData = [NSData
        dataWithContentsOfFile:[self.blobStorePath stringByAppendingPathComponent:fileArray[0]]];

    XCTAssertEqualObjects(self.encryptedData, fileData, @"Store only encrypted data");
}

- (void)testBlobForKeyReturnsReaderAbleToReadDataSavedWithABlobStoreWriter
{
    NSData *subData01 = [self.data subdataWithRange:NSMakeRange(0, self.data.length / 2)];
    NSData *subData02 = [self.data
        subdataWithRange:NSMakeRange(subData01.length, self.data.length - subData01.length)];

    [self.blobStoreWriter appendData:subData01];
    [self.blobStoreWriter appendData:subData02];
    [self.blobStoreWriter finish];
    [self.blobStoreWriter install];

    id<CDTBlobReader> reader = [self.blobStore blobForKey:self.blobStoreWriter.blobKey];

    XCTAssertEqualObjects(self.data, [reader dataWithError:nil],
                          @"It has to return the same data previously saved");
}

@end
