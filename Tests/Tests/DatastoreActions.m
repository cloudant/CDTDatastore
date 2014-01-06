//
//  DatastoreActions.m
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantSyncTests.h"

#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"

@interface DatastoreActions : CloudantSyncTests

@end

@implementation DatastoreActions

- (void)testGetADatabase
{
    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    STAssertNotNil(tmp, @"Could not create test database");
    STAssertTrue([tmp isKindOfClass:[CDTDatastore class]], @"Returned database not CDTDatastore");
}

@end
