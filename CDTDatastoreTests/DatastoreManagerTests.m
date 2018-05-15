//
//  DatastoreManagerTests.m
//  Tests
//
//  Created by Rhys Short on 17/12/2014.
//
//  Copyright © 2016 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import <CDTDatastore/CloudantSync.h>
#import "CloudantSyncTests.h"
#import "TDInternal.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import <libproc.h>
#import <sys/proc_info.h>
@interface DatastoreManagerTests : CloudantSyncTests

@end

@implementation DatastoreManagerTests



- (void)testList5Datastores {
    
    NSArray * array = @[@"datastore0",@"datastore1",@"datastore2",@"datastore3",@"datastore4"];
    
    for(NSString * dsName in array){
        [self.factory datastoreNamed:dsName error:nil];
    }
    
    NSArray * datastores = [self.factory allDatastores];
    XCTAssertEqual((NSUInteger)5, [datastores count],
                   @"Wrong number of datastores returned, expected 5 got %lu",
                   (unsigned long)[datastores count]);

    for(NSString * dsname in array){
        XCTAssertTrue([datastores containsObject:dsname], @"Object missing from datastores list");
    }
    
}

- (void) testListDatastoresWithSlash {
    
    [self.factory datastoreNamed:@"adatabase/withaslash" error:nil];
    NSArray * datastores = [self.factory allDatastores];
    XCTAssertEqual((NSUInteger)1, [datastores count],
                   @"Wrong number of datastores returned, expected 1 got %lu",
                   (unsigned long)[datastores count]);
    XCTAssertEqualObjects(@"adatabase/withaslash",
                         [datastores objectAtIndex:0],
                         @"Datastore names do not match");
    
}

-(void) testListEmptyDatastores {
    NSArray * datastores = [self.factory allDatastores];
    XCTAssertEqual((NSUInteger)0, [datastores count],
                   @"Wrong number of datastores returned, expected 0 got %lu",
                   (unsigned long)[datastores count]);
}

-(void) testSchema6ToSchema100Upgrade {
    NSError *err;
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *dbPath = [bundle pathForResource:@"schema6to7upgrade" ofType:@"touchdb"];
    CDTDatastoreManager *customFactory = [[CDTDatastoreManager alloc ]initWithDirectory:[dbPath stringByDeletingLastPathComponent] error:&err];
    CDTDatastore *store = [customFactory datastoreNamed:[[dbPath lastPathComponent] stringByDeletingPathExtension] error:&err];
    
    NSMutableArray *remotes = [NSMutableArray array];
    [[[store database] fmdbQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet *replicators = [db executeQuery:@"SELECT remote FROM replicators"];
        while ([replicators next]) {
            NSString *remoteId = [replicators stringForColumn:@"remote"];
            [remotes addObject:remoteId];
        }
    }];

    // check that we get back the upgraded sequence numbers
    for (NSString *remote in remotes) {
        __block NSData *lastSequenceJson;
        [[[store database] fmdbQueue] inDatabase:^(FMDatabase *db) {
          lastSequenceJson =
              [db dataForQuery:@"SELECT last_sequence FROM replicators WHERE remote=?", remote];
        }];

        XCTAssertNotNil(lastSequenceJson);
    }
}

- (void) testDatastoreClosesFilehandles {
    // repeatedly obtain the same datastore in a loop, adding documents to it and calling ensureIndexed
    // on each iteration, check that we have not excessively leaked filehandles, which would  indicate that the datastore and indexmanager are not being dealloc'd correctly
    int n = 1000;
    CDTDatastore *ds;
    for (int i=0; i<n; i++) {
        @autoreleasepool {
            CDTDocumentRevision *rev = [CDTDocumentRevision revision];
            rev.body = [NSMutableDictionary dictionaryWithDictionary: @{@"hello": @"world"}];
            NSError *err;
            ds = [self.factory datastoreNamed:@"test" error:&err];
            XCTAssertNil(err);
            [ds createDocumentFromRevision:rev error:&err];
            XCTAssertNil(err);
            [ds ensureIndexed:@[@"hello"] withName:@"index"];
            // if the datastore has been properly released, we will not run out of filehandles
            int pid = [[NSProcessInfo processInfo] processIdentifier];
            // first we call with a null pointer to see what the minimum buffer size needed is
            int bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, 0, 0);
            // buffer size is bytes, we want number of processes
            struct proc_fdinfo *fdInfo = (struct proc_fdinfo *)malloc(bufferSize);
            int fdCount = bufferSize / PROC_PIDLISTFD_SIZE;
            // now call with the buffer to get the actual number of processes (may be lower than buffer size)
            bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fdInfo, fdCount);
            // buffer size is bytes, we want number of processes
            fdCount = bufferSize / PROC_PIDLISTFD_SIZE;
            // as observed in testing, this should never go above 8, but we'll set a conservative limit of 100 to allow some breathing room
            XCTAssertTrue(fdCount < 100);
        }
    }
    XCTAssertEqual([ds documentCount], n);
}

@end


