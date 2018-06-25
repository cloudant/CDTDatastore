//
//  DatastoreManagerEncryptionTests.m
//  EncryptionTests
//
//  Created by Enrique de la Torre Fernandez on 13/03/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//  Copyright © 2018 IBM Corporation. All rights reserved.
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

#import "CDTDatastoreManager+EncryptionKey.h"
#import "CDTEncryptionKeyNilProvider.h"
#import "CDTHelperFixedKeyProvider.h"
#import "CloudantSyncTests.h"
#import "TD_Database.h"

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
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:&error];

    // Test
    XCTAssertTrue(
        !datastore && error,
        @"Non-encrypted db can not be opened with a key, so datastore can not initialised");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsAValueAndDBIsEncrypted
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"emptyencrypteddb" ofType:@"touchdb"];

    // Prepare factory
    CDTDatastoreManager *customFactory =
        [[CDTDatastoreManager alloc] initWithDirectory:[path stringByDeletingLastPathComponent]
                                                 error:nil];

    // Get datastore
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [customFactory datastoreNamed:[[path lastPathComponent] stringByDeletingPathExtension]
            withEncryptionKeyProvider:fixedProvider
                                error:&error];

    // Test
    XCTAssertTrue(!datastore && error, @"Encrypted db can not be opened with key (although it is "
                                       @"the same key used to encrypt it) because there is not an "
                                       @"encryption library available, so datastore can not "
                                       @"initialised");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsNilAndDBIsEncrypted
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"emptyencrypteddb" ofType:@"touchdb"];

    // Prepare factory
    CDTDatastoreManager *customFactory =
        [[CDTDatastoreManager alloc] initWithDirectory:[path stringByDeletingLastPathComponent]
                                                 error:nil];

    // Get datastore
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [customFactory datastoreNamed:[[path lastPathComponent] stringByDeletingPathExtension]
            withEncryptionKeyProvider:nilProvider
                                error:&error];

    // Test
    XCTAssertTrue(!datastore && error, @"An encrypted db can not be opened with or without key "
                                       @"because there is not an encryption library available, so "
                                       @"datastore can not initialised");
}

- (void)testDatastoreNamedThrowsExceptionIfKeyProviderIsNilAlthoughDBWasOpenedBefore
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *dbName = @"testdatastoremanager_alreadyopen";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:nilProvider error:nil];
    
    // Close
    [self.factory closeDatastoreNamed:dbName];

    // Test
    XCTAssertThrows([self.factory datastoreNamed:dbName withEncryptionKeyProvider:nil error:nil],
                    @"The key is always mandatory");
}

- (void)
    testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsAValueWithAnAlreadyOpenNonEncryptedDB
{
    // Create non-encrypted db
    CDTEncryptionKeyNilProvider *nilProvider = [CDTEncryptionKeyNilProvider provider];

    NSString *dbName = @"testdatastoremanager_alreadyopennonencryptdb";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:nilProvider error:nil];
    
    // Close
    [self.factory closeDatastoreNamed:dbName];

    // Get datastore
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:&error];

    // Test
    XCTAssertTrue(
        !datastore && error,
        @"Non-encrypted db can not be opened with a key, so datastore can not initialised");
}

#if defined ENCRYPT_DATABASE
- (void)
    testDatastoreNamedReturnsNilIfEncryptionKeyProviderDoesNotReturnTheKeyUsedToCipherTheDatabase
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSString *dbName = @"testdatastoremanager_encryptdbwrongkey";
    [TD_Database createEmptyDBAtPath:[self pathForDBName:dbName]
           withEncryptionKeyProvider:fixedProvider];

    // Get datastore
    CDTHelperFixedKeyProvider *otherProvider = [fixedProvider negatedProvider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:otherProvider error:&error];

    // Test
    XCTAssert(!datastore && error,
              @"DB can not be opened with a wrong key so the datastore can not be initialised");
}

- (void)testDatastoreNamedReturnsNilIfEncryptionKeyProviderReturnsNilWithAnAlreadyOpenEncryptedDB
{
    // Create encrypted db
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSString *dbName = @"testdatastoremanager_alreadyopenencryptdb";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:nil];

    // Close
    [self.factory closeDatastoreNamed:dbName];
    
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
    CDTHelperFixedKeyProvider *fixedProvider = [CDTHelperFixedKeyProvider provider];

    NSString *dbName = @"testdatastoremanager_encryptdbwrongkey_again";
    [self.factory datastoreNamed:dbName withEncryptionKeyProvider:fixedProvider error:nil];

    // Close
    [self.factory closeDatastoreNamed:dbName];
    
    // Get datastore
    CDTHelperFixedKeyProvider *otherProvider = [fixedProvider negatedProvider];

    NSError *error = nil;
    CDTDatastore *datastore =
        [self.factory datastoreNamed:dbName withEncryptionKeyProvider:otherProvider error:&error];

    // Test
    XCTAssertTrue(!datastore && error,
                  @"DB can not be opened with a wrong key so the datastore can not be initialised");
}
#endif

@end
