//
//  Attachments.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 20/03/2014.
//
//

#import "CloudantReplicationBase.h"

#import <SenTestingKit/SenTestingKit.h>
#import <CloudantSync.h>

@interface Attachments : CloudantReplicationBase

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) NSURL *remoteDatabase;
@property (nonatomic,strong) CDTReplicatorFactory *replicatorFactory;

@end

@implementation Attachments

- (void)setUp
{
    [super setUp];

    // Create local and remote databases, start the replicator

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    STAssertNotNil(self.datastore, @"datastore is nil");

    // This is a database with a read-only API key so we should be
    // able to use this in automated tests -- for now.
    // TODO: replace with a test that creates a doc with attachments
    //       first like the other tests.
    NSString *cloudant_account = @"mikerhodescloudant";
    NSString *db_name = @"attachments-test";
    NSString *username = @"minstrutlyagenintleahtio";
    NSString *password = @"ABIhugOtrCyfPHxeOFK81rIB";
    NSString *url = [NSString stringWithFormat:@"https://%@:%@@%@.cloudant.com",
                     username, password, cloudant_account];

    self.remoteRootURL = [NSURL URLWithString:url];
    self.remoteDatabase = [self.remoteRootURL URLByAppendingPathComponent:db_name];

    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    [self.replicatorFactory start];
}

- (void)tearDown
{
    // Tear-down code here.

    self.datastore = nil;

    [self.replicatorFactory stop];

    self.replicatorFactory = nil;
    
    [super tearDown];
}

- (void)testReplicateAttachmentDb
{
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:self.remoteDatabase
                            targetDatastore:self.datastore];

    NSLog(@"Replicating from %@", [self.remoteDatabase absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}

@end
