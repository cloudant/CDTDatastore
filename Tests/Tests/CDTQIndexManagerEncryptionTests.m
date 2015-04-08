//
//  CDTQIndexManagerEncryptionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 08/04/2015.
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
#import "CloudantTests+EncryptionTests.h"
#import "CDTDatastoreManager+EncryptionKey.h"
#import "CDTEncryptionKeyNilProvider.h"
#import "FMDatabase+SQLCipher.h"

#import "CDTQIndexManager.h"

@interface CDTQIndexManagerEncryptionTests : CloudantSyncTests

@end

@implementation CDTQIndexManagerEncryptionTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    [super tearDown];
}

- (void)testCreateQueryIndexManagerWithEncryptionKeyNilProvider
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    CDTDatastore *datastore = [self.factory datastoreNamed:@"create_query_index_tests_nilprovider"
                                 withEncryptionKeyProvider:provider
                                                     error:nil];

    NSError *err = nil;
    CDTQIndexManager *im = [[CDTQIndexManager alloc] initUsingDatastore:datastore error:&err];

    XCTAssertNotNil(im, @"indexManager is not nil");
    XCTAssertNil(err, @"error has to be nil");
}

- (void)testCreateQueryIndexManagerWithEncryptionKeyNilProviderDoesNotCipherIndex
{
    // Create index
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    CDTDatastore *datastore =
        [self.factory datastoreNamed:@"create_query_index_tests_nilprovider_notcipher"
            withEncryptionKeyProvider:provider
                                error:nil];

    __unused CDTQIndexManager *im =
        [[CDTQIndexManager alloc] initUsingDatastore:datastore error:nil];

    // Check
    NSString *path = [CloudantSyncTests pathForQueryIndexInDatastore:datastore];

    XCTAssertEqual([FMDatabase isDatabaseUnencryptedAtPath:path],
                   kFMDatabaseUnencryptedIsUnencrypted,
                   @"No encryption library available, database can not be encrypted");
}

- (void)testCreateQueryIndexManagerWithEncryptionKeyNilProviderFailsIfDBExistsAndItIsEncrypted
{
    // Create datastore
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    CDTDatastore *datastore =
        [self.factory datastoreNamed:@"create_query_index_tests_nilprovider_fails_with_cipher_db"
            withEncryptionKeyProvider:provider
                                error:nil];

    // Copy encrypted db to index folder
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *indexDBPath = [CloudantTests pathForQueryIndexInDatastore:datastore];
    NSString *indexDirectoryPath = [indexDBPath stringByDeletingLastPathComponent];
    
    [defaultManager createDirectoryAtPath:indexDirectoryPath
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *assetPath = [bundle pathForResource:@"emptyencryptedindex" ofType:@"sqlite"];
    
    [defaultManager copyItemAtPath:assetPath toPath:indexDBPath error:nil];
    
    // Test
    NSError *err = nil;
    CDTQIndexManager *im = [[CDTQIndexManager alloc] initUsingDatastore:datastore error:&err];

    XCTAssertNil(im, @"indexManager is nil");
    XCTAssertNotNil(err, @"There is an error");
}

@end
