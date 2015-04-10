//
//  DatastoreEncryptionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 13/03/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
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

#import "CloudantSyncTests.h"
#import "CDTHelperFixedKeyProvider.h"
#import "CDTEncryptionKeyNilProvider.h"
#import "TD_Database.h"

#import "CDTDatastoreManager+EncryptionKey.h"
#import "CDTDatastore+EncryptionKey.h"

@interface DatastoreEncryptionTests : CloudantSyncTests

@end

@implementation DatastoreEncryptionTests

- (void)testEncryptionKeyProviderReturnsTheSameProviderUsedToCreateTheDatastore
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];

    CDTDatastore *datastore = [self.factory datastoreNamed:@"test_copyprovider"
                                 withEncryptionKeyProvider:provider
                                                     error:nil];

    XCTAssertEqualObjects([datastore encryptionKeyProvider], provider,
                          @"Return the same provider used to create this instance");
}

- (void)testInitWithoutEncryptionKeyThrowsException
{
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"datastoreEncryptionTests_exception"];

    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    XCTAssertThrows([[CDTDatastore alloc] initWithDatabase:db encryptionKeyProvider:nil],
                    @"The key is mandatory. Inform a nil provider.");
}

- (void)testInitReturnsNilIfEncryptionKeyProviderReturnsAValueAndDBIsNotEncrypted
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"datastoreEncryptionTests_nonEncryptDB"];
    [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:nilProvider];

    // Reload db
    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    // Init with fixed key provider
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    XCTAssertNil(
        [[CDTDatastore alloc] initWithDatabase:db encryptionKeyProvider:fixedProvider],
        @"Non-encrypted db can not be opened with a key, so datastore can not initialised");
}

- (void)testInitReturnsNilIfEncryptionKeyProviderReturnsAValueAndDBIsEncrypted
{
    // Load db
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"emptyencrypteddb" ofType:@"touchdb"];
    
    TD_Database *db = [[TD_Database alloc] initWithPath:path];
    
    // Init with fixed key provider
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];
    
    XCTAssertNil(
                 [[CDTDatastore alloc] initWithDatabase:db encryptionKeyProvider:fixedProvider],
                 @"Although the key provided is the key used to encrypt the database, the db can "
                 @"not be opened without the encryption libary");
}

- (void)testInitReturnsNilIfEncryptionKeyProviderReturnsNilAndDBIsEncrypted
{
    // Load db
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"emptyencrypteddb" ofType:@"touchdb"];
    
    TD_Database *db = [[TD_Database alloc] initWithPath:path];
    
    // Init with fixed key provider
    CDTEncryptionKeyNilProvider *fixedProvider = [CDTEncryptionKeyNilProvider provider];
    
    XCTAssertNil(
                 [[CDTDatastore alloc] initWithDatabase:db encryptionKeyProvider:fixedProvider],
                 @"An encrypted db can not be opened with or without key because there is not an "
                 @"encryption library available");
}

- (void)testInitWithoutEncryptionKeyThrowsExceptionAlthoughDBIsAlreadyOpen
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"datastoreEncryptionTests_alreadyOpen"];
    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:nilProvider];

    // Init without provider
    XCTAssertThrows([[CDTDatastore alloc] initWithDatabase:db encryptionKeyProvider:nil],
                    @"The key is mandatory. Inform a nil provider to not cipher the database");
}

- (void)testInitReturnsNilIfEncryptionKeyProviderReturnsAValueWithAnAlreadyOpenNonEncryptedDB
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"datastoreEncryptionTests_alreadyOpenNonEncryptDB"];
    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyProvider:nilProvider];

    // Init with fixed key provider
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    XCTAssertNil(
        [[CDTDatastore alloc] initWithDatabase:db encryptionKeyProvider:fixedProvider],
        @"Non-encrypted db can not be opened with a key, so datastore can not initialised");
}

@end
