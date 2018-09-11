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

#import "TDBlobStore+Internal.h"

#import "TD_Database+BlobFilenames.h"

#import "CDTEncryptionKeyNilProvider.h"
#import "CDTHelperFixedKeyProvider.h"

#import "CDTMisc.h"
#import "TDMisc.h"

#define TDBLOBSTOREENCRYPTIONTESTS_DBFILENAME @"schema100_1Bonsai_2Lorem.touchdb"
#define TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE @"lorem.txt"
#define TDBLOBSTOREENCRYPTIONTESTS_LOREM_SHA1DIGEST @"3ff2989bccf52150bba806bae1db2e0b06ad6f88"

@interface TDFixedFilenameBlobStore : TDBlobStoreWriter

@end

@interface TDBlobStoreEncryptionTests : XCTestCase

@property (strong, nonatomic) TD_Database *db;
@property (strong, nonatomic) NSString *blobStorePath;
@property (strong, nonatomic) TDBlobStore *blobStore;
@property (strong, nonatomic) TDBlobStoreWriter *blobStoreWriter;

@property (strong, nonatomic) TD_Database *otherDB;
@property (strong, nonatomic) NSString *encryptedBlobStorePath;
@property (strong, nonatomic) TDBlobStore *encryptedBlobStore;
@property (strong, nonatomic) TDBlobStoreWriter *encryptedBlobStoreWriter;

@property (strong, nonatomic) TD_Database *nonEmptyDB;

@property (strong, nonatomic) NSData *plainData;
@property (strong, nonatomic) NSString *hexExpectedSHA1Digest;

@property (strong, nonatomic) NSData *otherPlainData;

@end

@implementation TDBlobStoreEncryptionTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.

    // Empty non-encrypted db
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

    // Non-emtpy non-encrypted db
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *assetPath = [bundle
        pathForResource:[TDBLOBSTOREENCRYPTIONTESTS_DBFILENAME stringByDeletingPathExtension]
                 ofType:[TDBLOBSTOREENCRYPTIONTESTS_DBFILENAME pathExtension]];

    dbPath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:TDBLOBSTOREENCRYPTIONTESTS_DBFILENAME];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager copyItemAtPath:assetPath toPath:dbPath error:nil];

    self.nonEmptyDB = [[TD_Database alloc] initWithPath:dbPath];
    [self.nonEmptyDB openWithEncryptionKeyProvider:provider];

    // Empty encrypted db
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

    // Test data
    self.plainData = [@"摇;摃:§婘栰" dataUsingEncoding:NSUTF8StringEncoding];
    self.hexExpectedSHA1Digest = @"0cb5ad21ca38f03ccc1139223019af3623394976";

    self.otherPlainData = [@"a1s2d3f4g5" dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    // Test data
    self.otherPlainData = nil;

    self.hexExpectedSHA1Digest = nil;
    self.plainData = nil;

    // Empty encrypted db
    self.encryptedBlobStoreWriter = nil;
    self.encryptedBlobStore = nil;

    [defaultManager removeItemAtPath:self.encryptedBlobStorePath error:nil];
    self.encryptedBlobStorePath = nil;

    [self.otherDB deleteDatabase:nil];
    self.otherDB = nil;

    // Non-emtpy non-encrypted db
    [self.nonEmptyDB deleteDatabase:nil];
    self.nonEmptyDB = nil;

    // Empty non-encrypted db
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
    // Blobs before
    __block NSUInteger countBefore = 0;
    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countBefore = [_blobStore countWithDatabase:db];
    }];

    // Store blob
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *loremPath = [bundle
        pathForResource:[TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE stringByDeletingPathExtension]
                 ofType:[TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE pathExtension]];
    NSData *loremBlob = [NSData dataWithContentsOfFile:loremPath];

    __block BOOL success = NO;
    __block NSString *loremHexKey;
    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey loremKey;
      success = [_blobStore storeBlob:loremBlob creatingKey:&loremKey withDatabase:db error:nil];

      loremHexKey = TDHexFromBytes(loremKey.bytes, sizeof(loremKey.bytes));
    }];

    // Blobs after
    __block NSUInteger countAfter = 0;
    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countAfter = [_blobStore countWithDatabase:db];
    }];

    // Assert
    XCTAssertTrue(success, @"You can save the same data twice");
    XCTAssertEqualObjects(loremHexKey, TDBLOBSTOREENCRYPTIONTESTS_LOREM_SHA1DIGEST,
                          @"It always return the same key");
    XCTAssertEqual(countBefore, countAfter, @"But no blob is saved to disk or database");
}

- (void)testStoreBlobDoNotUpdateDBIfDataIsNotSavedToDisk
{
    // Blobs before
    __block NSUInteger countBefore = 0;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countBefore = [_encryptedBlobStore countWithDatabase:db];
    }];

    // Store blob
    [[NSFileManager defaultManager] removeItemAtPath:self.encryptedBlobStorePath error:nil];

    __block BOOL success = NO;
    __block NSError *error = nil;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey key;
      success =
          [_encryptedBlobStore storeBlob:_plainData creatingKey:&key withDatabase:db error:&error];
    }];

    // Blobs after
    __block NSUInteger countAfter = 0;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countAfter = [_encryptedBlobStore countWithDatabase:db];
    }];

    // Assert
    XCTAssertFalse(success, @"It should fail because we removed the directory");
    XCTAssertNotNil(error, @"It should return an error");
    XCTAssertEqual(countBefore, countAfter, @"And no blob is saved to disk or database");
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
    __block id<CDTBlobReader> reader = nil;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      TDBlobKey key;
      memset(key.bytes, '*', sizeof(key.bytes));

      reader = [_encryptedBlobStore blobForKey:key withDatabase:db];
    }];

    XCTAssertNil(reader, @"If the key does not exist, it should return nil");
}

- (void)testBlobForKeySucceedsIfKeyIsAMigratedKey
{
    __block id<CDTBlobReader> reader = nil;

    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      NSData *data = dataFromHexadecimalString(TDBLOBSTOREENCRYPTIONTESTS_LOREM_SHA1DIGEST);

      TDBlobKey key;
      [data getBytes:key.bytes length:CC_SHA1_DIGEST_LENGTH];

      reader = [_blobStore blobForKey:key withDatabase:db];
    }];

    XCTAssertNotNil(reader, @"It should return a reader even if the attachment was migrated");
}

- (void)testBlobForKeyReturnsReaderAbleToReadDataPreviouslySaved
{
    __block TDBlobKey blobKey;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [_encryptedBlobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];
    }];

    __block id<CDTBlobReader> reader = nil;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      reader = [_encryptedBlobStore blobForKey:blobKey withDatabase:db];
    }];

    XCTAssertEqualObjects(self.plainData, [reader dataWithError:nil],
                          @"It has to return the same data previously saved");
}

- (void)testDeleteBlobsExceptWithKeysRemovesExpectedRowsFromDBAndDisk
{
    // Insert
    __block TDBlobKey blobKey;
    __block TDBlobKey otherBlobKey;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [_encryptedBlobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];
      [_encryptedBlobStore storeBlob:_otherPlainData
                         creatingKey:&otherBlobKey
                        withDatabase:db
                               error:nil];
    }];

    // Delete
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      NSSet *set =
          [NSSet setWithObject:[NSData dataWithBytes:blobKey.bytes length:sizeof(blobKey.bytes)]];
      [_encryptedBlobStore deleteBlobsExceptWithKeys:set withDatabase:db];
    }];

    // Get
    __block NSUInteger blobCount = 0;
    __block NSString *filename = nil;
    __block NSString *otherFilename = nil;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      blobCount = [TD_Database countRowsInBlobFilenamesTableInDatabase:db];
      filename = [TD_Database filenameForKey:blobKey inBlobFilenamesTableInDatabase:db];
      otherFilename = [TD_Database filenameForKey:otherBlobKey inBlobFilenamesTableInDatabase:db];
    }];

    // Assert
    XCTAssertEqual(blobCount, 1, @"After deleting one, there should be only 1 row");
    XCTAssertNotNil(filename, @"This should not be nil, this was an exception");
    XCTAssertNil(otherFilename, @"This should be nil because we deleted it");

    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSArray *allFilenames =
        [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    XCTAssertEqual(allFilenames.count, 1, @"Only 1 file should remain");

    NSString *filePath = [self.encryptedBlobStorePath stringByAppendingPathComponent:filename];
    XCTAssertTrue([defaultManager fileExistsAtPath:filePath],
                  @"There should be a file at this path");
}

- (void)testDeleteBlobsExceptWithKeysSucceedIfFileDoesNotExistOnDisk
{
    // Insert
    __block TDBlobKey blobKey;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [_encryptedBlobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];
    }];

    // Delete file
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSArray *fileArray =
        [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    [defaultManager
        removeItemAtPath:[self.encryptedBlobStorePath stringByAppendingPathComponent:fileArray[0]]
                   error:nil];

    // Delete
    __block BOOL success = NO;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      success = [_encryptedBlobStore deleteBlobsExceptWithKeys:[NSSet set] withDatabase:db];
    }];

    // Assert
    XCTAssertTrue(
        success, @"If the file does not exist, simply delete the row in the database and carry on");
}

- (void)testDeleteBlobsExceptWithKeysRemovesFilesNotRelatedToAnAttachment
{
    // Insert
    __block TDBlobKey blobKey;

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [_encryptedBlobStore storeBlob:_plainData creatingKey:&blobKey withDatabase:db error:nil];

      for (NSUInteger i = 0; i < 20; i++) {
          NSString *otherStr = [NSString stringWithFormat:@"摇;摃:%lu", (unsigned long)i];

          TDBlobKey otherBlobKey;
          [_encryptedBlobStore storeBlob:[otherStr dataUsingEncoding:NSUTF8StringEncoding]
                             creatingKey:&otherBlobKey
                            withDatabase:db
                                   error:nil];
      }
    }];

    // Insert garbage
    for (NSInteger i = 0; i < 20; i++) {
        NSString *filename = [[NSString stringWithFormat:@"file%lu", (unsigned long)i]
            stringByAppendingPathExtension:TDDatabaseBlobFilenamesFileExtension];
        NSString *filePath = [self.encryptedBlobStorePath stringByAppendingPathComponent:filename];
        [self.plainData writeToFile:filePath atomically:YES];
    }

    // Delete
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      NSSet *set =
          [NSSet setWithObject:[NSData dataWithBytes:blobKey.bytes length:sizeof(blobKey.bytes)]];
      [_encryptedBlobStore deleteBlobsExceptWithKeys:set withDatabase:db];
    }];

    // Get remaining filename
    __block NSString *filename = nil;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      filename = [TD_Database filenameForKey:blobKey inBlobFilenamesTableInDatabase:db];
    }];

    // Assert
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSArray *allFilenames =
        [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    XCTAssertEqual(allFilenames.count, 1, @"Only 1 file should remain");

    NSString *filePath = [self.encryptedBlobStorePath stringByAppendingPathComponent:filename];
    XCTAssertTrue([defaultManager fileExistsAtPath:filePath],
                  @"There should be a file at this path");
}

- (void)testBlobStoreWriterDoesNotUpdateDBIfInstallFails
{
    // Blobs before
    __block NSUInteger countBefore = 0;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countBefore = [_encryptedBlobStore countWithDatabase:db];
    }];

    // Store blob
    [[NSFileManager defaultManager] removeItemAtPath:self.encryptedBlobStorePath error:nil];

    [self.encryptedBlobStoreWriter appendData:self.plainData];
    [self.encryptedBlobStoreWriter finish];

    __block BOOL success = NO;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      success = [_encryptedBlobStoreWriter installWithDatabase:db];
    }];

    // Blobs after
    __block NSUInteger countAfter = 0;
    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countAfter = [_encryptedBlobStore countWithDatabase:db];
    }];

    // Assert
    XCTAssertFalse(success, @"It should fail because we removed the directory");
    XCTAssertEqual(countBefore, countAfter, @"And no blob is saved to disk or database");
}

- (void)testBlobStoreWriterSucceedsIfTheBlobAlreadyExists
{
    // Blobs before
    __block NSUInteger countBefore = 0;
    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countBefore = [_blobStore countWithDatabase:db];
    }];

    // Store blob
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *loremPath = [bundle
        pathForResource:[TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE stringByDeletingPathExtension]
                 ofType:[TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE pathExtension]];
    NSData *loremBlob = [NSData dataWithContentsOfFile:loremPath];

    [self.blobStoreWriter appendData:loremBlob];
    [self.blobStoreWriter finish];

    __block BOOL success = NO;
    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      success = [_blobStoreWriter installWithDatabase:db];
    }];

    NSString *loremHexKey = TDHexFromBytes(self.blobStoreWriter.blobKey.bytes,
                                           sizeof(self.blobStoreWriter.blobKey.bytes));

    // Blobs after
    __block NSUInteger countAfter = 0;
    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      countAfter = [_blobStore countWithDatabase:db];
    }];

    // Assert
    XCTAssertTrue(success, @"You can save the same data twice");
    XCTAssertEqualObjects(loremHexKey, TDBLOBSTOREENCRYPTIONTESTS_LOREM_SHA1DIGEST,
                          @"It always return the same key");
    XCTAssertEqual(countBefore, countAfter, @"But no blob is saved to disk or database");
}

- (void)testBlobStoreWriterDeletesTmpFileIfTheBlobAlreadyExists
{
    // Get path
    NSString *tempPath = [self.blobStoreWriter tempPath];

    // Store blob
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *loremPath = [bundle
        pathForResource:[TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE stringByDeletingPathExtension]
                 ofType:[TDBLOBSTOREENCRYPTIONTESTS_LOREM_FILE pathExtension]];
    NSData *loremBlob = [NSData dataWithContentsOfFile:loremPath];

    [self.blobStoreWriter appendData:loremBlob];
    [self.blobStoreWriter finish];

    [self.nonEmptyDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [_blobStoreWriter installWithDatabase:db];
    }];

    // Assert
    XCTAssertNil([self.blobStoreWriter tempPath], @"Temp. path is set to nil after installing");
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempPath],
                   @"The temp. file should be removed from disk");
}

- (void)testBlobStoreWriterDeletesTmpFileIfInstallFails
{
    // Get path
    NSString *tempPath = [self.encryptedBlobStoreWriter tempPath];

    // Store blob
    [[NSFileManager defaultManager] removeItemAtPath:self.encryptedBlobStorePath error:nil];

    [self.encryptedBlobStoreWriter appendData:self.plainData];
    [self.encryptedBlobStoreWriter finish];

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [_encryptedBlobStoreWriter installWithDatabase:db];
    }];

    // Assert
    XCTAssertNil([self.encryptedBlobStoreWriter tempPath],
                 @"Temp. path is set to nil after installing");
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempPath],
                   @"The temp. file should be removed from disk");
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

- (void)testBlobStoreWriterOverwriteFileWithSameName
{
    // Create file
    TDFixedFilenameBlobStore *writer =
        [[TDFixedFilenameBlobStore alloc] initWithStore:self.encryptedBlobStore];

    [writer appendData:self.plainData];
    [writer finish];

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [writer installWithDatabase:db];
    }];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSArray *fileArray =
        [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    NSData *fileData =
        [NSData dataWithContentsOfFile:[self.encryptedBlobStorePath
                                           stringByAppendingPathComponent:fileArray[0]]];

    // Overwrite file
    writer = [[TDFixedFilenameBlobStore alloc] initWithStore:self.encryptedBlobStore];

    [writer appendData:self.otherPlainData];
    [writer finish];

    [self.otherDB.fmdbQueue inDatabase:^(FMDatabase *db) {
      [writer installWithDatabase:db];
    }];

    fileArray = [defaultManager contentsOfDirectoryAtPath:self.encryptedBlobStorePath error:nil];
    NSData *otherFileData =
        [NSData dataWithContentsOfFile:[self.encryptedBlobStorePath
                                           stringByAppendingPathComponent:fileArray[0]]];

    // Assert
    XCTAssertNotEqualObjects(fileData, otherFileData,
                             @"File should be overwritten with the new data");
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

@implementation TDFixedFilenameBlobStore

#pragma mark - TDBlobStore+Internal methods
- (NSString *)generateAndInsertRandomFilenameInDatabase:(FMDatabase *)db
{
    return [@"fixedFilename" stringByAppendingPathExtension:TDDatabaseBlobFilenamesFileExtension];
}

@end
