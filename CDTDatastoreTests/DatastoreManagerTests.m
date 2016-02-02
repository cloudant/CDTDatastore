//
//  DatastoreManagerTests.m
//  Tests
//
//  Created by Rhys Short on 17/12/2014.
//
//

#import <Foundation/Foundation.h>
#import <CDTDatastore/CloudantSync.h>
#import "CloudantSyncTests.h"
#import "TDInternal.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

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
                   @"Wrong number of datastores returned, expected 5 got %d",
                   [datastores count]);
    
    for(NSString * dsname in array){
        XCTAssertTrue([datastores containsObject:dsname], @"Object missing from datastores list");
    }
    
}

- (void) testListDatastoresWithSlash {
    
    [self.factory datastoreNamed:@"adatabase/withaslash" error:nil];
    NSArray * datastores = [self.factory allDatastores];
    XCTAssertEqual((NSUInteger)1,
                   [datastores count],
                   @"Wrong number of datastores returned, expected 1 got %d",
                   [datastores count]);
    XCTAssertEqualObjects(@"adatabase/withaslash",
                         [datastores objectAtIndex:0],
                         @"Datastore names do not match");
    
}

-(void) testListEmptyDatastores {
    NSArray * datastores = [self.factory allDatastores];
    XCTAssertEqual((NSUInteger)0, [datastores count],
                   @"Wrong number of datastores returned, expected 0 got %d",
                   [datastores count]);

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
        NSObject *sequence = [[store database] lastSequenceWithCheckpointID:remote];
        XCTAssertNotNil(sequence);
    }
}

@end


