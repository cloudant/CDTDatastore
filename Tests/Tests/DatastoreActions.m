//
//  DatastoreActions.m
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "DatastoreActions.h"

#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"

@implementation DatastoreActions

- (void)testGetADatabase
{
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database"];
    STAssertNotNil(tmp, @"Could not create test database");
    STAssertTrue([tmp isKindOfClass:[CDTDatastore class]], @"Returned database not CDTDatastore");
}

@end
