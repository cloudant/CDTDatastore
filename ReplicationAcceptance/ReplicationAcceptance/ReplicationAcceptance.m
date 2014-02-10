//
//  ReplicationAcceptance.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import "ReplicationAcceptance.h"

#import <SenTestingKit/SenTestingKit.h>

#import <CloudantSync.h>
#import <UNIRest.h>
#import <TRVSMonitor.h>

#import "CloudantReplicationBase.h"
#import "CloudantReplicationBase+CompareDb.h"
#import "ReplicationAcceptance+CRUD.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"

@interface ReplicationAcceptance ()

/** This database is used as the primary remote database. Some tests create further
 databases, but all use this one.
 */
@property (nonatomic, strong) NSString *primaryRemoteDatabaseName;

@end

@implementation ReplicationAcceptance

/**
 This is the standard number of documents those tests requiring a number
 of documents to replicate use. 10k takes 50 minutes, 100k much longer,
 as all these documents are read from both local and remote databases
 during the check phase.
 */
static NSUInteger n_docs = 100000;
/**
 Rev tree size for "large rev tree" tests.
 */
static NSUInteger largeRevTreeSize = 1500;

#pragma mark - setUp and tearDown

- (void)setUp
{
    [super setUp];

    // Create local and remote databases, start the replicator

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    STAssertNotNil(self.datastore, @"datastore is nil");

    self.primaryRemoteDatabaseName = [NSString stringWithFormat:@"%@-test-database-%@",
                                    self.remoteDbPrefix,
                                    [CloudantReplicationBase generateRandomString:5]];
    self.primaryRemoteDatabaseURL = [self.remoteRootURL URLByAppendingPathComponent:self.primaryRemoteDatabaseName];
    [self createRemoteDatabase:self.primaryRemoteDatabaseName];

    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    [self.replicatorFactory start];
}

- (void)tearDown
{
    // Tear-down code here.

    // Delete remote database, stop the replicator.
    [self deleteRemoteDatabase:self.primaryRemoteDatabaseName];

    self.datastore = nil;

    [self.replicatorFactory stop];

    self.replicatorFactory = nil;

    [super tearDown];
}


#pragma mark - Replication helpers

-(void) createRemoteDatabase:(NSString*)name
{
    NSURL *remoteDatabaseURL = [self.remoteRootURL URLByAppendingPathComponent:name];

    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSData data]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db create failed");
}

-(void) deleteRemoteDatabase:(NSString*)name
{
    NSURL *remoteDatabaseURL = [self.remoteRootURL URLByAppendingPathComponent:name];

    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest delete:^(UNISimpleRequest* request) {
        [request setUrl:[remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db delete failed");
}

/**
 Create a new replicator, and wait for replication from the remote database to complete.
 */
-(void) pullFromRemote {
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:self.primaryRemoteDatabaseURL
                            targetDatastore:self.datastore];

    NSLog(@"Replicating from %@", [self.primaryRemoteDatabaseURL absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}

/**
 Create a new replicator, and wait for replication from the local database to complete.
 */
-(void) pushToRemote {
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:self.datastore
                                        targetURI:self.primaryRemoteDatabaseURL];

    NSLog(@"Replicating to %@", [self.primaryRemoteDatabaseURL absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}


#pragma mark - Tests

/**
 Load up a local database with n_docs with a single rev, then push it to 
 the configured remote database.
 */
-(void)testPushLotsOfOneRevDocuments
{
    // Create docs in local store
    NSLog(@"Creating documents...");
    [self createLocalDocs:n_docs];
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    [self pushToRemote];

    [self assertRemoteDatabaseHasDocCount:[[NSNumber numberWithUnsignedInteger:n_docs] integerValue]
                              deletedDocs:0];

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

/**
 Load up a remote database with n_docs with a single rev, then pull it to
 the local datastore.
 */
-(void) testPullLotsOfOneRevDocuments {

//    NSError *error;

    // Create docs in remote database
    NSLog(@"Creating documents...");

    [self createRemoteDocs:n_docs];

    [self pullFromRemote];

    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

/**
 Push a document with largeRevTreeSize revisions (>1000).
 */
-(void) testPushLargeRevTree {

    // Create the initial rev
    NSString *docId = @"doc-0";
    [self createLocalDocWithId:docId revs:largeRevTreeSize];
    STAssertEquals(self.datastore.documentCount, (NSUInteger)1, @"Incorrect number of documents created");

    [self pushToRemote];

    // Check document count in the remote DB
    [self assertRemoteDatabaseHasDocCount:1
                              deletedDocs:0];

    // Check number of revs
    NSURL *docURL = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:docId];
    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    UNIHTTPJsonResponse *response = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
        [request setParameters:@{@"revs": @"true"}];
    }] asJson];
    NSDictionary *jsonResponse = response.body.object;

    // default couchdb revs_limit is 1000
    STAssertEquals([jsonResponse[@"_revisions"][@"ids"] count], (NSUInteger)1000, @"Wrong number of revs");
    STAssertTrue([jsonResponse[@"_rev"] hasPrefix:@"1500"], @"Not all revs seem to be replicated");

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

/**
 Pull a document with largeRevTreeSize revisions (>1000).
 */
-(void) testPullLargeRevTree {
    NSError *error;

    // Create the initial rev in remote datastore
    NSString *docId = [NSString stringWithFormat:@"doc-0"];

    [self createRemoteDocWithId:docId revs:largeRevTreeSize];

    [self pullFromRemote];

    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:&error];
    STAssertNil(error, @"Error getting replicated doc: %@", error);
    STAssertNotNil(rev, @"Error creating doc: rev was nil, but so was error");

    STAssertTrue([rev.revId hasPrefix:@"1500"], @"Unexpected current rev in local document");

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

/**
 Create n_docs remote documents and pull them into the local datastore. Then
 modify all document with ten revisions. Finally push the changes back and check
 the local and remote databases still match.
 */
-(void) testPullModifySeveralRevsPush
{
    NSError *error;
    NSInteger n_mods = 10;

    // Create docs in remote database
    NSLog(@"Creating documents...");
    [self createRemoteDocs:n_docs];
    [self pullFromRemote];
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    // Modify all the docs -- we know they're going to be doc-1 to doc-<n_docs+1>
    for (int i = 1; i < n_docs+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%i", i];
        CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId error:&error];
        STAssertNil(error, @"Couldn't get document");
        [self addRevsToDocumentRevision:rev count:n_mods];
    }

    // Replicate the changes
    [self pushToRemote];

    [self assertRemoteDatabaseHasDocCount:n_docs
                              deletedDocs:0];

    // Check number of revs for all docs is <n_mods>
    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    for (int i = 1; i < n_docs+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%i", i];
        NSURL *docURL = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:docId];
        UNIHTTPJsonResponse *response = [[UNIRest get:^(UNISimpleRequest* request) {
            [request setUrl:[docURL absoluteString]];
            [request setHeaders:headers];
            [request setParameters:@{@"revs": @"true"}];
        }] asJson];
        NSDictionary *jsonResponse = response.body.object;

        STAssertEquals([jsonResponse[@"_revisions"][@"ids"] count], (NSUInteger)n_mods, @"Wrong number of revs");
        STAssertTrue([jsonResponse[@"_rev"] hasPrefix:@"10"], @"Not all revs seem to be replicated");
    }


    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}


/**
 Create n_docs remote documents and pull them into the local datastore. Then
 delete all the documents in the local database. Finally push the changes back and check
 the local and remote databases still match.
 */
-(void) testPullDeleteAllPush
{
    NSError *error;

    // Create docs in remote database
    NSLog(@"Creating documents...");
    [self createRemoteDocs:n_docs];
    [self pullFromRemote];
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    // Modify all the docs -- we know they're going to be doc-1 to doc-<n_docs+1>
    for (int i = 1; i < n_docs+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%i", i];
        CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId error:&error];

        [self.datastore deleteDocumentWithId:docId
                                         rev:rev.revId
                                       error:&error];
        STAssertNil(error, @"Couldn't delete document");
    }

    // Replicate the changes
    [self pushToRemote];

    [self assertRemoteDatabaseHasDocCount:0
                              deletedDocs:n_docs];


    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

/**
 Fire up two threads:
 
 1. Push revisions to the remote database so long as there are still changes
    in the local database.
 2. Create n_docs single-rev docs in the local datastore.
 
 This tests that the replicator can keep up with a database that's adding docs
 underneath it.
 */
-(void) test_pushDocsAsWritingThem
{
    TRVSMonitor *monitor = [[TRVSMonitor alloc] initWithExpectedSignalCount:2];
    [self performSelectorInBackground:@selector(pushDocsAsWritingThem_pullReplicateThenSignal:)
                           withObject:monitor];
    [self performSelectorInBackground:@selector(pushDocsAsWritingThem_populateLocalDatabaseThenSignal:)
                           withObject:monitor];

    [monitor wait];

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

-(void) pushDocsAsWritingThem_pullReplicateThenSignal:(TRVSMonitor*)monitor
{
    NSInteger count;
    do {
        [self pushToRemote];
        NSDictionary *dbMeta = [self remoteDbMetadata];
        count = [dbMeta[@"doc_count"] integerValue];
        NSLog(@"Remote count: %ld", (long)count);
    } while (count < n_docs);

    [monitor signal];
}

-(void) pushDocsAsWritingThem_populateLocalDatabaseThenSignal:(TRVSMonitor*)monitor
{
    [self createLocalDocs:n_docs];
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");
    [monitor signal];
}

/**
 Create n_docs in the remote database.

 Fire up two threads:

 1. Pull all revisions from the remote database.
 2. Create n_docs single-rev docs in the local datastore, with names that DON'T
    conflict with the ones being pulled.

 This tests that we can add documents concurrently with a replication.
 */
-(void) test_pullDocsWhileWritingOthers
{
    [self createRemoteDocs:n_docs];

    TRVSMonitor *monitor = [[TRVSMonitor alloc] initWithExpectedSignalCount:2];

    // Replicate n_docs from remote
    [self performSelectorInBackground:@selector(pullDocsWhileWritingOthers_pullReplicateThenSignal:)
                           withObject:monitor];

    // Create documents that don't conflict as we pull
    [self performSelectorInBackground:@selector(pullDocsWhileWritingOthers_populateLocalDatabaseThenSignal:)
                           withObject:monitor];

    [monitor wait];

    STAssertEquals(self.datastore.documentCount, (NSUInteger)n_docs*2, @"Wrong number of local docs");

    [self pushToRemote];

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

-(void) pullDocsWhileWritingOthers_pullReplicateThenSignal:(TRVSMonitor*)monitor
{
    [self pullFromRemote];
    [monitor signal];
}

-(void) pullDocsWhileWritingOthers_populateLocalDatabaseThenSignal:(TRVSMonitor*)monitor
{
    [self createLocalDocs:n_docs suffixFrom:n_docs+1];
    [monitor signal];
}

/**
 See test_pullDocsWhileWritingOthers.

 Test replicating all the documents to a third database to make sure we replicate
 both documents added to the local DB via local modifications and replication.
 */
-(void) test_pullDocsWhileWritingOthersWriteToThirdDB
{
    [self createRemoteDocs:n_docs];

    TRVSMonitor *monitor = [[TRVSMonitor alloc] initWithExpectedSignalCount:2];

    // Replicate n_docs from remote
    [self performSelectorInBackground:@selector(pullDocsWhileWritingOthers_pullReplicateThenSignal:)
                           withObject:monitor];

    // Create documents that don't conflict as we pull
    [self performSelectorInBackground:@selector(pullDocsWhileWritingOthers_populateLocalDatabaseThenSignal:)
                           withObject:monitor];

    [monitor wait];


    // Push to a third database and check against it.
    NSString *thirdDatabaseName = [NSString stringWithFormat:@"%@-test-third-database-%@",
                                   self.remoteDbPrefix,
                                   [CloudantReplicationBase generateRandomString:5]];

    [self createRemoteDatabase:thirdDatabaseName];

    NSURL *thirdDatabase = [self.remoteRootURL URLByAppendingPathComponent:thirdDatabaseName];

    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:self.datastore
                                        targetURI:thirdDatabase];

    NSLog(@"Replicating to %@", [thirdDatabase absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:thirdDatabase];
    STAssertTrue(same, @"Remote and local databases differ");

    [self deleteRemoteDatabase:thirdDatabaseName];
}

/**
 Create n_docs in the remote database.

 Fire up two threads:

 1. Pull all revisions from the remote database.
 2. Create documents in the local database with the same name, in reverse order.

 This tests that we can replicate while modifying the same documents locally.
 The docs are created in reverse order locally so we end up with some docs
 conflicted by local modifications, some by remote. In the end all docs
 will be conflicted.
 */
-(void) test_pullDocsWhileWritingSame
{
    [self createLocalDocs:n_docs suffixFrom:0 reverse:NO updates:NO];
    [self createRemoteDocs:n_docs];

    TRVSMonitor *monitor = [[TRVSMonitor alloc] initWithExpectedSignalCount:2];

    // Replicate n_docs from remote
    [self performSelectorInBackground:@selector(pullDocsWhileWritingSame_pullReplicateThenSignal:)
                           withObject:monitor];

    // Create documents that don't conflict as we pull
    [self performSelectorInBackground:@selector(pullDocsWhileWritingSame_populateLocalDatabaseThenSignal:)
                           withObject:monitor];

    [monitor wait];

    [self pushToRemote];

    STAssertEquals(self.datastore.documentCount, (NSUInteger)n_docs, @"Wrong number of local docs");

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

-(void) pullDocsWhileWritingSame_pullReplicateThenSignal:(TRVSMonitor*)monitor
{
    [self pullFromRemote];
    [monitor signal];
}

-(void) pullDocsWhileWritingSame_populateLocalDatabaseThenSignal:(TRVSMonitor*)monitor
{
    // Write in reverse so we'll definitely cross-streams with the concurrent
    // pull replication at some point.
    [self createLocalDocs:n_docs suffixFrom:0 reverse:YES updates:YES];
    [monitor signal];
}

/**
 See test_pullDocsWhileWritingSame.
 
 This test makes sure that we can replicate all the docs and conflicts
 to a third database.
 */
-(void) test_pullDocsWhileWritingSameWriteToThirdDB
{
    [self createLocalDocs:n_docs suffixFrom:0 reverse:NO updates:NO];
    [self createRemoteDocs:n_docs];

    TRVSMonitor *monitor = [[TRVSMonitor alloc] initWithExpectedSignalCount:2];

    // Replicate n_docs from remote
    [self performSelectorInBackground:@selector(pullDocsWhileWritingSame_pullReplicateThenSignal:)
                           withObject:monitor];

    // Create documents that don't conflict as we pull
    [self performSelectorInBackground:@selector(pullDocsWhileWritingSame_populateLocalDatabaseThenSignal:)
                           withObject:monitor];

    [monitor wait];


    // Push to a third database and check against it.
    NSString *thirdDatabaseName = [NSString stringWithFormat:@"%@-test-third-database-%@",
                                      self.remoteDbPrefix,
                                      [CloudantReplicationBase generateRandomString:5]];

    [self createRemoteDatabase:thirdDatabaseName];

    NSURL *thirdDatabase = [self.remoteRootURL URLByAppendingPathComponent:thirdDatabaseName];

    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:self.datastore
                                        targetURI:thirdDatabase];

    NSLog(@"Replicating to %@", [thirdDatabase absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:thirdDatabase];
    STAssertTrue(same, @"Remote and local databases differ");

    [self deleteRemoteDatabase:thirdDatabaseName];
}


@end
