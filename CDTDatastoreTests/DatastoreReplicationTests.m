//
// Created by Rhys Short on 02/09/2016.
// Copyright (c) 2016 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.


#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "CloudantSyncTests.h"
#import "CDTDatastore.h"
#import "CDTDatastore+Replication.h"
#import "CDTReplicatorDelegate.h"
#import "CDTReplicator.h"

@interface ReplicatorDelegate: NSObject<CDTReplicatorDelegate>
@end

@implementation ReplicatorDelegate
@end

@interface DatastoreReplicationTests : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;

@end


@implementation DatastoreReplicationTests

- (void)setUp
{
    [super setUp];

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];

    XCTAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.

    self.datastore = nil;

    [super tearDown];
}

- (void) testPullReplicatorCreatedViaCategory
{
    NSError * error = nil;
    ReplicatorDelegate *delegate = [[ReplicatorDelegate alloc] init];
    CDTReplicator *replicator = [self.datastore
        pullReplicationSource:[[NSURL alloc] initWithString:@"http://exmaple.example"]
                     username:nil
                     password:nil
                 withDelegate:delegate
                        error:&error];
    XCTAssertNil(error, "An error should not have been encountered.");
    XCTAssertNotNil(replicator, "replicator should not be nil");
    XCTAssertEqual(replicator.delegate, delegate, "the replicator's delegate should be the same as the delegate passed into");
}

- (void) testPushReplicatorCreatedViaCategory
{
    NSError * error = nil;
    ReplicatorDelegate *delegate = [[ReplicatorDelegate alloc] init];
    CDTReplicator *replicator = [self.datastore
        pushReplicationTarget:[[NSURL alloc] initWithString:@"http://example.example"]
                     username:nil
                     password:nil
                 withDelegate:delegate
                        error:&error];
    XCTAssertNil(error, "An error should not have been encountered.");
    XCTAssertNotNil(replicator, "replicator should not be nil");
    XCTAssertEqual(replicator.delegate, delegate, "the replicator's delegate should be the same as the delegate passed into");
}

@end

