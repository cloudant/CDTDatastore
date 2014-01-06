//
//  CDTReplicatorTests.m
//  Tests
//
//  Created by Michael Rhodes on 23/12/2013.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantSyncIOSTests.h"
#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"
#import "CDTDocumentBody.h"
#import "CDTReplicator.h"
#import "CDTDocumentRevision.h"

@interface CDTReplicatorTests : CloudantSyncIOSTests

@property (nonatomic,strong) CDTDatastore *replicatorDb;

@end

@implementation CDTReplicatorTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.

    NSError *error;

    // As we pass this into the CDTReplicator objects under test, no reason for
    // it to be called the same thing as the standard _replicator database.
    self.replicatorDb = [self.factory datastoreNamed:@"test_replicator" error:&error];

    STAssertNotNil(self.replicatorDb, @"replicatorDb nil, setUp failed");
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testDocumentNotAddedImmediately
{
    NSString *sentinal = @"testDocumentNotAddedImmediately";

    // replicator doesn't mind what the data is.
    NSDictionary *content = @{@"test": sentinal};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:content];

    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:self.replicatorDb
                                                           replicationDocumentBody:body];

    STAssertEquals(replicator.state, CDTReplicatorStatePending, @"replicator not pending");

    NSArray *docs = [self.replicatorDb getAllDocumentsOffset:0
                                                       limit:[self.replicatorDb documentCount]
                                                  descending:NO];

    for (CDTDocumentRevision *rev in docs) {
        NSDictionary *doc = [rev documentAsDictionary];
        NSString *type = doc[@"test"];
        STAssertFalse([type isEqualToString:sentinal],
                      @"replicator document was added before start");
    }
}

- (void)testDocumentAddedOnStart
{
    NSString *sentinal = @"testDocumentAddedOnStart";

    // replicator doesn't mind what the data is.
    NSDictionary *content = @{@"test": sentinal};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:content];

    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:self.replicatorDb
                                                           replicationDocumentBody:body];

    STAssertEquals(replicator.state, CDTReplicatorStatePending, @"replicator not pending");

    [replicator start];

    NSArray *docs = [self.replicatorDb getAllDocumentsOffset:0
                                                       limit:[self.replicatorDb documentCount]
                                                  descending:NO];

    BOOL found = NO;
    for (CDTDocumentRevision *rev in docs) {
        NSDictionary *doc = [rev documentAsDictionary];
        NSString *type = doc[@"test"];
        if ([type isEqualToString:sentinal]) {
            found = YES;
            break;
        }
    }
    STAssertTrue(found, @"document not found after start");

    // Still pending until replicator starts
    STAssertEquals(replicator.state, CDTReplicatorStatePending, @"replicator not pending");
}

- (void)testDocumentDeletedOnStop
{
    NSString *sentinal = @"testDocumentDeletedOnStop";

    // replicator doesn't mind what the data is.
    NSDictionary *content = @{@"test": sentinal};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:content];

    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:self.replicatorDb
                                                           replicationDocumentBody:body];

    STAssertEquals(replicator.state, CDTReplicatorStatePending, @"replicator not pending");

    [replicator start];

    [replicator stop];

    NSArray *docs = [self.replicatorDb getAllDocumentsOffset:0
                                                       limit:[self.replicatorDb documentCount]
                                                  descending:NO];

    for (CDTDocumentRevision *rev in docs) {
        NSDictionary *doc = [rev documentAsDictionary];
        NSString *type = doc[@"test"];
        STAssertFalse([type isEqualToString:sentinal],
                      @"replicator document was added before start");
    }

    // Still pending until replicator starts
    STAssertEquals(replicator.state, CDTReplicatorStatePending, @"replicator not pending");
}

@end
