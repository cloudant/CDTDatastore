//
//  SetUpDatastore.m
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "SetUpDatastore.h"
#import "CDTDatastoreManager.h"

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
