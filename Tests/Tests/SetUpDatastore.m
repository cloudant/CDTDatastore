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
    CDTDatastore *datastore = [self.factory datastoreNamed:@"test"];
    STAssertNotNil(datastore, @"datastore is nil");
}

/**
 * Make sure we can create several datastores.
 */
- (void)testSetupAndTeardownSeveralDatastores
{
    CDTDatastore *datastore1 = [self.factory datastoreNamed:@"test"];
    CDTDatastore *datastore2 = [self.factory datastoreNamed:@"test2"];
    STAssertNotNil(datastore1, @"datastore1 is nil");
    STAssertNotNil(datastore2, @"datastore2 is nil");
}

@end
