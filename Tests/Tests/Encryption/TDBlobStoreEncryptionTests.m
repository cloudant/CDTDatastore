//
//  TDBlobStoreEncryptionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 22/05/2015.
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

#import "TD_Database.h"

#import "CDTHelperFixedKeyProvider.h"
#import "CDTEncryptionKeyNilProvider.h"

#import "TDMisc.h"

@interface TDBlobStoreEncryptionTests : XCTestCase

@property (strong, nonatomic) TD_Database *db;
@property (strong, nonatomic) NSString *blobStorePath;
@property (strong, nonatomic) TDBlobStore *blobStore;
@property (strong, nonatomic) TDBlobStoreWriter *blobStoreWriter;

@property (strong, nonatomic) TD_Database *otherDB;
@property (strong, nonatomic) NSString *encryptedBlobStorePath;
@property (strong, nonatomic) TDBlobStore *encryptedBlobStore;
@property (strong, nonatomic) TDBlobStoreWriter *encryptedBlobStoreWriter;

@property (strong, nonatomic) NSData *plainData;
@property (strong, nonatomic) NSString *hexExpectedSHA1Digest;

@end

@implementation TDBlobStoreEncryptionTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    id<CDTEncryptionKeyProvider> provider = [[CDTEncryptionKeyNilProvider alloc] init];

    NSString *dbPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"blobStoreEncryptionTests_db"];
    self.db = [TD_Database createEmptyDBAtPath:dbPath withEncryptionKeyProvider:provider];

    self.blobStorePath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"blobStoreEncryptionTests_plainData"];
    self.blobStore = [[TDBlobStore alloc] initWithPath:self.blobStorePath
                                 encryptionKeyProvider:provider
                                                 error:nil];
    self.blobStoreWriter = [[TDBlobStoreWriter alloc] initWithStore:self.blobStore];

    dbPath = [NSTemporaryDirectory()
              stringByAppendingPathComponent:@"blobStoreEncryptionTests_encryptedDB"];
    self.otherDB = [TD_Database createEmptyDBAtPath:dbPath withEncryptionKeyProvider:provider];
    
    provider = [CDTHelperFixedKeyProvider provider];

    self.encryptedBlobStorePath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"blobStoreEncryptionTests_encryptedData"];
    self.encryptedBlobStore = [[TDBlobStore alloc] initWithPath:self.encryptedBlobStorePath
                                          encryptionKeyProvider:provider
                                                          error:nil];
    self.encryptedBlobStoreWriter =
        [[TDBlobStoreWriter alloc] initWithStore:self.encryptedBlobStore];

    self.plainData = [@"摇;摃:§婘栰" dataUsingEncoding:NSUTF8StringEncoding];
    self.hexExpectedSHA1Digest = @"0cb5ad21ca38f03ccc1139223019af3623394976";
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    self.hexExpectedSHA1Digest = nil;
    self.plainData = nil;

    self.encryptedBlobStoreWriter = nil;
    self.encryptedBlobStore = nil;

    [defaultManager removeItemAtPath:self.encryptedBlobStorePath error:nil];
    self.encryptedBlobStorePath = nil;
    
    [self.otherDB deleteDatabase:nil];
    self.otherDB = nil;

    self.blobStoreWriter = nil;
    self.blobStore = nil;

    [defaultManager removeItemAtPath:self.blobStorePath error:nil];
    self.blobStorePath = nil;
    
    [self.db deleteDatabase:nil];
    self.db = nil;

    [super tearDown];
}

- (void)testStoreBlobSucceedsIfKeyIsAlreadySaved
{
#warning TODO
}

- (void)testStoreBlobDoNotUpdateDBIfDataIsNotSavedToDisk
{
#warning TODO
}

- (void)testStoreBlobReturnsExpectedKey
{
    __block NSString *hexEncryptedBlobKey = nil;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey encryptedBlobKey;
      [_encryptedBlobStore storeBlob:_plainData
                         creatingKey:&encryptedBlobKey
                        withDatabase:db
                               error:nil];
      hexEncryptedBlobKey = TDHexFromBytes(encryptedBlobKey.bytes, sizeof(encryptedBlobKey.bytes));
    }];

    XCTAssertEqualObjects(hexEncryptedBlobKey, self.hexExpectedSHA1Digest,
                          @"Both should be the same");
}

- (void)testStoreBlobSavesEncryptedData
{
    [self.db.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey blobKey;
      [_blobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];
    }];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSArray *fileArray = [defaultManager contentsOfDirectoryAtPath:self.blobStorePath error:nil];
    NSData *fileData = [NSData
        dataWithContentsOfFile:[self.blobStorePath stringByAppendingPathComponent:fileArray[0]]];

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey blobKey;
      [_encryptedBlobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];
    }];

    fileArray = [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    NSData *fileEncryptedData =
        [NSData dataWithContentsOfFile:[self.encryptedBlobStorePath
                                           stringByAppendingPathComponent:fileArray[0]]];

    XCTAssertNotEqualObjects(fileData, fileEncryptedData,
                             @"Same plain data but the content of the files should be different");
}

- (void)testBlobForKeyFailsIfKeyDoesNotExist
{
#warning TODO
}

- (void)testBlobForKeySucceedsIfKeyExists
{
#warning TODO
}

- (void)testBlobForKeySucceedsIfKeyIsAMigratedKey
{
#warning TODO
}

- (void)testBlobForKeyReturnsReaderAbleToReadDataPreviouslySaved
{
    __block id<CDTBlobReader> reader = nil;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey blobKey;
      [_encryptedBlobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];

      reader = [_encryptedBlobStore blobForKey:blobKey withDatabase:db];
    }];

    XCTAssertEqualObjects(self.plainData, [reader dataWithError:nil],
                          @"It has to return the same data previously saved");
}

- (void)testDeleteBlobsExceptWithKeysRemovesExpectedFiles
{
#warning TODO
}

- (void)testDeleteBlobsExceptWithKeysRemovesExpectedRowsFromDB
{
#warning TODO
}

- (void)testBlobStoreWriterDoesNotUpdateDBIfInstallFails
{
#warning TODO
}

- (void)testBlobStoreWriterSucceedsIfTheBlobAlreadyExists
{
#warning TODO
}

- (void)testBlobStoreWriterDeletesTmpFileIfTheBlobAlreadyExists
{
#warning TODO
}

- (void)testBlobStoreWriterDeletesTmpFileIfInstallFails
{
#warning TODO
}

- (void)testBlobStoreWriterReturnsExpectedKey
{
    NSData *subData01 = [self.plainData subdataWithRange:NSMakeRange(0, self.plainData.length / 2)];
    NSData *subData02 = [self.plainData
        subdataWithRange:NSMakeRange(subData01.length, self.plainData.length - subData01.length)];

    [self.encryptedBlobStoreWriter appendData:subData01];
    [self.encryptedBlobStoreWriter appendData:subData02];
    [self.encryptedBlobStoreWriter finish];
    
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
        [_encryptedBlobStoreWriter installWithDatabase:db];
    }];

    NSString *hexEncryptedBlobKey =
        TDHexFromBytes(self.encryptedBlobStoreWriter.blobKey.bytes,
                       sizeof(self.encryptedBlobStoreWriter.blobKey.bytes));

    XCTAssertEqualObjects(hexEncryptedBlobKey, self.hexExpectedSHA1Digest,
                          @"Both should be the same");
}

- (void)testBlobStoreWriterSavesEncryptedData
{
    NSData *subData01 = [self.plainData subdataWithRange:NSMakeRange(0, self.plainData.length / 2)];
    NSData *subData02 = [self.plainData
        subdataWithRange:NSMakeRange(subData01.length, self.plainData.length - subData01.length)];

    [self.encryptedBlobStoreWriter appendData:subData01];
    [self.encryptedBlobStoreWriter appendData:subData02];
    [self.encryptedBlobStoreWriter finish];
    
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
        [_encryptedBlobStoreWriter installWithDatabase:db];
    }];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSArray *fileArray =
        [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    NSData *fileEncryptedData =
        [NSData dataWithContentsOfFile:[self.encryptedBlobStorePath
                                           stringByAppendingPathComponent:fileArray[0]]];

    [self.db.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey blobKey;
      [self.blobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];
    }];

    fileArray = [defaultManager contentsOfDirectoryAtPath:self.blobStorePath error:nil];
    NSData *fileData = [NSData
        dataWithContentsOfFile:[self.blobStorePath stringByAppendingPathComponent:fileArray[0]]];

    XCTAssertNotEqualObjects(fileData, fileEncryptedData,
                             @"Same plain data but the content of the files should be different");
}

- (void)testBlobForKeyReturnsReaderAbleToReadDataSavedWithABlobStoreWriter
{
    NSData *subData01 = [self.plainData subdataWithRange:NSMakeRange(0, self.plainData.length / 2)];
    NSData *subData02 = [self.plainData
        subdataWithRange:NSMakeRange(subData01.length, self.plainData.length - subData01.length)];

    [self.encryptedBlobStoreWriter appendData:subData01];
    [self.encryptedBlobStoreWriter appendData:subData02];
    [self.encryptedBlobStoreWriter finish];
    
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
        [_encryptedBlobStoreWriter installWithDatabase:db];
    }];

    __block id<CDTBlobReader> reader = nil;
    
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
        reader = [_encryptedBlobStore blobForKey:_encryptedBlobStoreWriter.blobKey withDatabase:db];
    }];

    XCTAssertEqualObjects(self.plainData, [reader dataWithError:nil],
                          @"It has to return the same data previously saved");
}

@end
