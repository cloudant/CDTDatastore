//
//  SetUpDatastore.m
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"

#import "CDTIndexManager.h"

#import "CDTDatastore.h"

#import "TD_Database.h"
#import "TD_DatabaseManager.h"

@interface SetUpDatastore : CloudantSyncTests

@end

@implementation SetUpDatastore

/**
 * This test makes sure we're able to setup and
 * teardown a datastore factory correctly. To help
 * debug issues in other tests where the datastore 
 * factory can't be created.
 */
- (void)testSetupAndTeardownDatastoreFactory
{
    XCTAssertNotNil(self.factory, @"Factory is nil");
}

/**
 * This test makes sure we're able to get a datastore
 * from a factory. To help debug issues in other tests
 * where the datastore can't be created.
 */
- (void)testSetupAndTeardownDatastore
{
    NSError *error;
    CDTDatastore *datastore = [self.factory datastoreNamed:@"test" error:&error];
    XCTAssertNotNil(datastore, @"datastore is nil");
}

/**
 * Make sure we can create several datastores.
 */
- (void)testSetupAndTeardownSeveralDatastores
{
    NSError *error;
    CDTDatastore *datastore1 = [self.factory datastoreNamed:@"test" error:&error];
    CDTDatastore *datastore2 = [self.factory datastoreNamed:@"test2" error:&error];
    XCTAssertNotNil(datastore1, @"datastore1 is nil");
    XCTAssertNotNil(datastore2, @"datastore2 is nil");
}

/**
 * Check there's an error for _name datastores.
 */
- (void)testUnderscoreNonReplicatorDbGivesError
{
    NSError *error;
    CDTDatastore *datastore = [self.factory datastoreNamed:@"_test" error:&error];
    XCTAssertNil(datastore, @"datastore is not nil");
    XCTAssertNotNil(error, @"error is nil");
}

/**
 * Check we can't create a datastore with suffix _extensions
 */
- (void)testSetupDatastoreExtensionsSuffix
{
    NSError *error;
    
    NSString *dbName = @"test_extensions";
    
    // setup datastore and indexmanager
    CDTDatastore *datastore = [self.factory datastoreNamed:dbName error:&error];
    XCTAssertNil(datastore, @"datastore is not nil");
}

/**
 * This test makes sure we cleanly delete all database files
 */
- (void)testSetupAndDeleteDatastore
{
    NSError *error;
    
    NSString *dbName = @"test";
    NSString *dbNameFull = [dbName stringByAppendingString:@".touchdb"];
    NSString *dbNameExtensions = [dbName stringByAppendingString:@"_extensions"];
    NSString *dbNameAttachments = [dbName stringByAppendingString:@" attachments"];

    // setup datastore and indexmanager
    CDTDatastore *datastore = [self.factory datastoreNamed:dbName error:&error];
    __unused CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:datastore error:&error];

    // for checking files
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [[[datastore database] path] stringByDeletingLastPathComponent];
    
    // check various files/dirs exist
    XCTAssertTrue([fm fileExistsAtPath:[dir stringByAppendingPathComponent:dbNameFull]], @"db file does not exist");
    XCTAssertTrue([fm fileExistsAtPath:[dir stringByAppendingPathComponent:dbNameExtensions]], @"extensions dir does not exist");
    XCTAssertTrue([fm fileExistsAtPath:[dir stringByAppendingPathComponent:dbNameAttachments]], @"attachments dir does not exist");
    
    // delete datastore
    XCTAssertTrue([self.factory deleteDatastoreNamed:dbName error:&error], @"deleteDatastoreNamed did not return true");

    // check various files/dirs have been deleted
    XCTAssertFalse([fm fileExistsAtPath:[dir stringByAppendingPathComponent:dbNameFull]], @"db file was not deleted");
    XCTAssertFalse([fm fileExistsAtPath:[dir stringByAppendingPathComponent:dbNameExtensions]], @"extensions dir was not deleted");
    XCTAssertFalse([fm fileExistsAtPath:[dir stringByAppendingPathComponent:dbNameAttachments]], @"attachments dir was not deleted");
}

- (void)testDeleteDatastoreReturnsErrorIfNameIsNotValid
{
    NSError *error = nil;
    BOOL deletionSucceeded = [self.factory deleteDatastoreNamed:@"-.-" error:&error];
    BOOL isExpectedError = (error &&
                            ([error.domain isEqualToString:CDTDatastoreErrorDomain]) &&
                            (error.code == 404));
    
    XCTAssertTrue(!deletionSucceeded && isExpectedError,
                  @"There is only one possible error if the name is not valid (%@, %i)",
                  CDTDatastoreErrorDomain, 404);
}

- (void)testDeleteDatastoreReleaseMemory
{
    CDTDatastore *datastore = [self.factory datastoreNamed:@"deletiontest" error:nil];
    
    NSUInteger databasesCounter = [[self.factory.manager allOpenDatabases] count];
    
    [self.factory deleteDatastoreNamed:datastore.name error:nil];
    
    XCTAssertEqual([[self.factory.manager allOpenDatabases] count], databasesCounter - 1,
                   @"Datastore must be removed from disk and released from memory");
}

@end
