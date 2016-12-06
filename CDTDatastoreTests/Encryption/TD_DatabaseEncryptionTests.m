//
//  TD_DatabaseEncryptionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 20/02/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

#import "CDTEncryptionKeyNilProvider.h"
#import "CDTHelperFixedKeyProvider.h"
#import "CloudantSyncTests.h"
#import "CloudantTests+EncryptionTests.h"
#import "FMDatabase+SQLCipher.h"

#import "TD_Database.h"

@interface TD_DatabaseEncryptionTests : CloudantSyncTests

@end

@implementation TD_DatabaseEncryptionTests

- (void)testCreateEmptyWithEncryptionKeyNilProviderDoesNotCipherDatabase
{
    // Create db
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_NilNotCipher"];
    [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:provider];

    // Check
    XCTAssertEqual([FMDatabase isDatabaseUnencryptedAtPath:path],
                   kFMDatabaseUnencryptedIsUnencrypted,
                   @"If no key is provided, db should not be encrypted. Also encyption library is "
                   @"not included");
}

#ifndef ENCRYPT_DATABASE
- (void)testCreateEmptyWithFixedKeyProviderFails
{
    // Create db
    CDTHelperFixedKeyProvider *provider = [CDTHelperFixedKeyProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_DoCipherDb"];
    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:provider];

    // Check
    XCTAssertNil(db,
                 @"It is not possible to create an encrypted db without the corresponding library");
}

- (void)testOpenFailsIfEncryptionKeyProviderReturnsAValue
{
    CDTHelperFixedKeyProvider *provider = [CDTHelperFixedKeyProvider provider];
    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_OpenFails"];

    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    XCTAssertFalse([db openWithEncryptionKeyProvider:provider],
                   @"DB can't be opened with key because encription library is not available");
}
#endif

- (void)testOpenWithoutEncryptionKeyThrowsException
{
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests"];

    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    XCTAssertThrows([db openWithEncryptionKeyProvider:nil],
                    @"The key is mandatory. Inform a nil provider to not cipher the database");
}

- (void)testOpenFailsIfEncryptionKeyProviderReturnsAValueWithANonEncryptedDatabase
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_nonEncryptDB"];
    [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:nilProvider];

    // Reload db
    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    // Open with fixed key provider
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:fixedProvider],
                   @"A non-encrypted db can not be open with an encryption key");
}

- (void)testOpenFailsIfEncryptionKeyProviderReturnsAValueWithAnEncryptedDatabase
{
    // Load db
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"emptyencrypteddb" ofType:@"touchdb"];

    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    // Open with fixed key provider
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:fixedProvider],
                   @"Although the key provided is the key used to encrypt the database, the db can "
                   @"not be opened without the encryption libary");
}

- (void)testOpenFailsIfEncryptionKeyProviderReturnsNilWithAnEncryptedDatabase
{
    // Load db
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"emptyencrypteddb" ofType:@"touchdb"];

    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    // Open with nil provider
    CDTEncryptionKeyNilProvider *fixedProvider = [CDTEncryptionKeyNilProvider provider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:fixedProvider],
                   @"An encrypted db can not be opened with or without key because there is not an "
                   @"encryption library available");
}

- (void)testReopenWithoutEncryptionKeyThrowsException
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_reOpen"];
    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:nilProvider];

    // Re-open without provider
    XCTAssertThrows([db openWithEncryptionKeyProvider:nil],
                    @"The key is mandatory. Inform a nil provider to not cipher the database");
}

- (void)testReopenFailsIfEncryptionKeyProviderReturnsAValueWithANonEncryptedDatabase
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_reOpenNonEncryptDB"];
    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:nilProvider];

    // Re-open with fixed key provider
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:fixedProvider],
                   @"A non-encrypted db can not be open with an encryption key");
}

#if defined ENCRYPT_DATABASE
- (void)testCreateEmptyWithFixedKeyProviderCiphersDatabase
{
    // Create db
    CDTHelperFixedKeyProvider *provider = [CDTHelperFixedKeyProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_DoCipherDb"];
    [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:provider];

    // Check
    XCTAssertEqual([FMDatabase isDatabaseUnencryptedAtPath:path], kFMDatabaseUnencryptedIsEncrypted,
                   @"If a key is provided, db has to be encrypted");
}

- (void)testOpenDoesNotFailIfEncryptionKeyProviderReturnsAValue
{
    CDTHelperFixedKeyProvider *provider = [CDTHelperFixedKeyProvider provider];
    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_openNotFail"];

    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    XCTAssertTrue([db openWithEncryptionKeyProvider:provider],
                  @"DB can be opened with a key with the encryption library available");
}

- (void)testOpenFailsIfEncryptionKeyProviderDoesNotReturnTheKeyUsedToCipherTheDatabase
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_encryptDBWrongKey"];
    [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:fixedProvider];

    // Reload db
    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    // Open with another fixed provider
    CDTHelperFixedKeyProvider *otherProvider = [fixedProvider negatedProvider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:otherProvider],
                   @"An encrypted db can only be open with the same key it was created");
}

- (void)testReopenFailsIfEncryptionKeyProviderReturnsNilWithAnEncryptedDatabase
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_reOpenEncryptDB"];
    TD_Database *db =
        [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:fixedProvider];

    // Re-open with nil provider
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:nilProvider],
                   @"An encrypted db requires a key to be open");
}

- (void)testReopenFailsIfEncryptionKeyProviderDoesNotReturnTheKeyUsedToCipherTheDatabase
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSString *path = [[self createTemporaryDirectoryAndReturnPath]
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_reOpenEncryptDBWrongKey"];
    TD_Database *db =
        [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:fixedProvider];

    // Open with another fixed provider
    CDTHelperFixedKeyProvider *otherProvider = [fixedProvider negatedProvider];

    XCTAssertFalse([db openWithEncryptionKeyProvider:otherProvider],
                   @"An encrypted db can only be open with the same key it was created");
}
#endif

@end
