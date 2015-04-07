//
//  DatastoreManagerEncryptionTests.m
//  EncryptionTests
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
#import "TD_Database.h"
#import "CDTHelperFixedKeyProvider.h"
#import "CDTEncryptionKeyNilProvider.h"
#import "CDTDatastoreManager+EncryptionKey.h"

@interface DatastoreManagerEncryptionTests : CloudantSyncTests

@end

@implementation DatastoreManagerEncryptionTests

- (void)testDatastoreNamedThrowsExceptionIfKeyProviderIsNil
{
    XCTAssertThrows([self.factory datastoreNamed:@"testdatastoremanager_throwexception"
                        withEncryptionKeyProvider:nil
                                            error:nil],
                    @"The key is mandatoru. Inform a nil provider for a non-encrypted db");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsAValueAndDBIsNotEncrypted
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *dbName = @"testdatastoremanager_nonencryptdb";
    [TD_Database createEmptyDBAtPath:[self pathForDBName:dbName]
           withEncryptionKeyProvider:nilProvider];

    // Get datastore
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:&error];

    // Test
    XCTAssertTrue(
        !datastore && error,
        @"Non-encrypted db can not be opened with a key, so datastore can not initialised");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsNilAndDBIsEncrypted
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    NSString *dbName = @"testdatastoremanager_encryptdb";
    [TD_Database createEmptyDBAtPath:[self pathForDBName:dbName]
           withEncryptionKeyProvider:fixedProvider];

    // Get datastore
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:nilProvider error:&error];

    // Test
    XCTAssertTrue(!datastore && error,
                  @"No key provided to open the db, the datastore can not be created");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderDoesNotReturnTheKeyUsedToCipherTheDatabase
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    NSString *dbName = @"testdatastoremanager_encryptdbwrongkey";
    [TD_Database createEmptyDBAtPath:[self pathForDBName:dbName]
           withEncryptionKeyProvider:fixedProvider];

    // Get datastore
    NSString *otherKey =
        [fixedProvider.encryptionKey stringByAppendingString:fixedProvider.encryptionKey];
    CDTHelperFixedKeyProvider *otherProvider =
        [[CDTHelperFixedKeyProvider alloc] initWithKey:otherKey];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:otherProvider error:&error];

    // Test
    XCTAssert(!datastore && error,
              @"DB can not be opened with a wrong key so the datastore can not be initialised");
}

- (void)testDatastoreNamedThrowsExceptionIfKeyProviderIsNilAlthoughDBWasOpenedBefore
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *dbName = @"testdatastoremanager_alreadyopen";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:nilProvider error:nil];

    // Test
    XCTAssertThrows([self.factory datastoreNamed:dbName withEncryptionKeyProvider:nil error:nil],
                    @"The key is always mandatory");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsAValueWithAnAlreadyOpenNonEncryptedDB
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *dbName = @"testdatastoremanager_alreadyopennonencryptdb";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:nilProvider error:nil];

    // Get datastore
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:&error];

    // Test
    XCTAssertTrue(
        !datastore && error,
        @"Non-encrypted db can not be opened with a key, so datastore can not initialised");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsNilWithAnAlreadyOpenEncryptedDB
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    NSString *dbName = @"testdatastoremanager_alreadyopenencryptdb";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:nil];

    // Get datastore
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:nilProvider error:&error];

    // Test
    XCTAssertTrue(!datastore && error,
                  @"Encrypted db requires a key, so datastore can not be initialised");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderDoesNotReturnTheKeyUsedToOpenTheDatabase
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [[CDTHelperFixedKeyProvider alloc] init];

    NSString *dbName = @"testdatastoremanager_encryptdbwrongkey_again";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:nil];

    // Get datastore
    NSString *otherKey =
        [fixedProvider.encryptionKey stringByAppendingString:fixedProvider.encryptionKey];
    CDTHelperFixedKeyProvider *otherProvider =
        [[CDTHelperFixedKeyProvider alloc] initWithKey:otherKey];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:otherProvider error:&error];

    // Test
    XCTAssertTrue(!datastore && error,
                  @"DB can not be opened with a wrong key so the datastore can not be initialised");
}

@end
