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

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"

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
    STAssertNotNil(self.factory, @"Factory is nil");
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
    STAssertNotNil(datastore, @"datastore is nil");
}

/**
 * Make sure we can create several datastores.
 */
- (void)testSetupAndTeardownSeveralDatastores
{
    NSError *error;
    CDTDatastore *datastore1 = [self.factory datastoreNamed:@"test" error:&error];
    CDTDatastore *datastore2 = [self.factory datastoreNamed:@"test2" error:&error];
    STAssertNotNil(datastore1, @"datastore1 is nil");
    STAssertNotNil(datastore2, @"datastore2 is nil");
}

/**
 * Check there's an error for _name datastores.
 */
- (void)testUnderscoreNonReplicatorDbGivesError
{
    NSError *error;
    CDTDatastore *datastore = [self.factory datastoreNamed:@"_test" error:&error];
    STAssertNil(datastore, @"datastore is not nil");
    STAssertNotNil(error, @"error is nil");
}

@end
