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
#import "ReplicatorDelegates.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"
#import "CDTPullReplication.h"
#import "CDTPushReplication.h"
#import "TDReplicatorManager.h"
#import "TDReplicator.h"
#import "CDTReplicator.h"

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
static NSUInteger n_docs = 1000;
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
    [self createRemoteDatabase:self.primaryRemoteDatabaseName instanceURL:self.remoteRootURL];

    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    [self.replicatorFactory start];
}

- (void)tearDown
{
    // Tear-down code here.

    // Delete remote database, stop the replicator.
    [self deleteRemoteDatabase:self.primaryRemoteDatabaseName instanceURL:self.remoteRootURL];

    self.datastore = nil;

    [self.replicatorFactory stop];

    self.replicatorFactory = nil;

    [super tearDown];
}

/**
 Create a new replicator, and wait for replication from the remote database to complete.
 */
-(CDTReplicator *) pullFromRemote {
    return [self pullFromRemoteWithFilter:nil params:nil clientFilterDocIds:nil];
}

-(CDTReplicator *) pullFromRemoteWithFilter:(NSString*)filterName
                                     params:(NSDictionary*)params
{
    return [self pullFromRemoteWithFilter:filterName params:params clientFilterDocIds:nil];
}

-(CDTReplicator *) pullFromRemoteWithFilter:(NSString*)filterName
                                     params:(NSDictionary*)params
                         clientFilterDocIds:(NSArray*)filterDocIds
{
    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:self.primaryRemoteDatabaseURL
                                                                  target:self.datastore];
    
    pull.filter = filterName;
    pull.filterParams = params;
    pull.clientFilterDocIds = filterDocIds;
    
    NSError *error;
    CDTReplicator *replicator =  [self.replicatorFactory oneWay:pull error:&error];
    STAssertNil(error, @"%@",error);
    STAssertNotNil(replicator, @"CDTReplicator is nil");
    
    NSLog(@"Replicating from %@", [pull.source absoluteString]);
    if (![replicator startWithError:&error]) {
        STFail(@"CDTReplicator -startWithError: %@", error);
    }
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    return replicator;
}

-(CDTReplicator *) pullFromRemoteWithClientFilterDocIds:(NSArray*)clientFilterDocIds {
    return [self pullFromRemoteWithFilter:nil params:nil clientFilterDocIds:clientFilterDocIds];
}



/**
 Create a new replicator, and wait for replication from the local database to complete.
 */
-(CDTReplicator *) pushToRemote {
    return [self pushToRemoteWithFilter:nil params:nil];
}

/**
 Create a new replicator, and wait for replication from the local database to complete.
 */
-(CDTReplicator *) pushToRemoteWithFilter:(CDTFilterBlock)filter params:(NSDictionary*)params{
    
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:self.datastore
                                                                  target:self.primaryRemoteDatabaseURL];
    push.filter = filter;
    push.filterParams = params;
    
    NSError *error;
    CDTReplicator *replicator =  [self.replicatorFactory oneWay:push error:&error];
    STAssertNil(error, @"%@",error);
    STAssertNotNil(replicator, @"CDTReplicator is nil");
    
    NSLog(@"Replicating to %@", [self.primaryRemoteDatabaseURL absoluteString]);
    if (![replicator startWithError:&error]) {
        STFail(@"CDTReplicator -startWithError: %@", error);
    }
   
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }

    return replicator;
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

    CDTReplicator *replicator = [self pushToRemote];

    [self assertRemoteDatabaseHasDocCount:[[NSNumber numberWithUnsignedInteger:n_docs] integerValue]
                              deletedDocs:0];

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");

    STAssertEquals(n_docs, (NSUInteger)replicator.changesTotal, @"total number of changes mismatch");
    STAssertEquals(n_docs, (NSUInteger)replicator.changesProcessed, @"processed number of changes mismatch");
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

    CDTReplicator *replicator = [self pullFromRemote];

    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
    
    STAssertEquals(n_docs, (NSUInteger)replicator.changesTotal, @"total number of changes mismatch");
    
    STAssertEquals(n_docs, (NSUInteger)replicator.changesProcessed, @"processed number of changes mismatch");
}

-(void) testPullErrorsWhenLocalDatabaseIsDeleted
{
    
    [self createRemoteDocs:n_docs];
    
    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:self.primaryRemoteDatabaseURL
                                                                  target:self.datastore];
    
    NSError *error;
    CDTReplicator *replicator =  [self.replicatorFactory oneWay:pull error:&error];
    CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart *mydel =
                                            [[CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart alloc] init];
    mydel.databaseToDelete = self.datastore.name;
    mydel.dsManager = self.factory;
    
    replicator.delegate = mydel;
    
    error = nil;
    STAssertTrue([replicator startWithError:&error], @"CDTReplicator -startWithError: %@", error);
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }

    
    STAssertTrue(n_docs != (NSUInteger)replicator.changesTotal, @"changesTotal: %ld, n_docs %ld",
                 replicator.changesTotal, n_docs);
    
    STAssertTrue(n_docs != (NSUInteger)replicator.changesProcessed, @"changesProcessed: %ld, n_docs %ld",
                   replicator.changesProcessed, n_docs);
    
    STAssertEquals(replicator.state, CDTReplicatorStateError, @"Found: %@, expected: (%@)",
                   [CDTReplicator stringForReplicatorState:replicator.state],
                   [CDTReplicator stringForReplicatorState:CDTReplicatorStateError]);

    STAssertEquals(mydel.error.code, CDTReplicatorErrorLocalDatabaseDeleted,
                   @"Wrong error code: %ld", mydel.error.code);
    
}

-(void) testPushErrorsWhenLocalDatabaseIsDeleted
{
    
    [self createLocalDocs:n_docs];
    
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:self.datastore
                                                                  target:self.primaryRemoteDatabaseURL];
    
    NSError *error;
    CDTReplicator *replicator =  [self.replicatorFactory oneWay:push error:&error];
    CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart *mydel =
                                            [[CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart alloc] init];
    mydel.databaseToDelete = self.datastore.name;
    mydel.dsManager = self.factory;
    
    replicator.delegate = mydel;
    
    error = nil;
    if (![replicator startWithError:&error]) {
        STFail(@"CDTReplicator -startWithError: %@", error);
    }
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    
    STAssertTrue(n_docs != (NSUInteger)replicator.changesTotal, @"changesTotal: %ld, n_docs %ld",
                 replicator.changesTotal, n_docs);
    
    STAssertTrue(n_docs != (NSUInteger)replicator.changesProcessed, @"changesProcessed: %ld, n_docs %ld",
                 replicator.changesProcessed, n_docs);
    
    STAssertEquals(replicator.state, CDTReplicatorStateError, @"Found: %@, expected: (%@)",
                   [CDTReplicator stringForReplicatorState:replicator.state],
                   [CDTReplicator stringForReplicatorState:CDTReplicatorStateError]);

    STAssertEquals(mydel.error.code, CDTReplicatorErrorLocalDatabaseDeleted,
                   @"Wrong error code: %ld", mydel.error.code);
}

/**
 As per testPullLotsOfOneRevDocuments but ensuring indexes are updated.
 NB this currently about twice as slow as without indexing.
 */
-(void) testPullLotsOfOneRevDocumentsIndexed {
    
    NSError *error;
    
    // set up indexing
    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];
    [im ensureIndexedWithIndexName:@"hello" fieldName:@"hello" error:&error];
    
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    [self createRemoteDocs:n_docs];
    
    [self pullFromRemote];
    
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");
    
    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
    
    CDTQueryResult *res = [im queryWithDictionary:@{@"hello":@"world"} error:&error];
    STAssertEquals([[res documentIds] count], n_docs, @"Index does not return correct count");
}

-(void) testPullFilteredReplication {
    
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    int ndocs = 50; //don't need 100k docs
    
    [self createRemoteDocs:ndocs];
    
    //create remote filter
    NSString *ddoc = [NSString stringWithFormat:@"ddoc-%@",
                      [CloudantReplicationBase generateRandomString:5]];
    NSString *filterKey = @"docnum_by_range";
    NSString *filterName = [ddoc stringByAppendingFormat:@"/%@", filterKey];
    
    NSString *filterFunction = @"function(doc, req) {"
                               @"  if (doc.docnum >= req.query.min && doc.docnum < req.query.max)"
                               @"    return true;"
                               @"  else return false;"
                               @"}";
    
    NSDictionary *body = @{@"filters": @{ filterKey:filterFunction}};
    
    [self createRemoteDocWithId:[NSString stringWithFormat:@"_design/%@", ddoc] body:body];
    
    
    //replicate over a few individial docs - the filter range is [min, max).
    [self pullFromRemoteWithFilter:filterName params:@{@"min":@1, @"max":@2}];
    [self pullFromRemoteWithFilter:filterName params:@{@"min":@3, @"max":@4}];
    [self pullFromRemoteWithFilter:filterName params:@{@"min":@13, @"max":@14}];
    [self pullFromRemoteWithFilter:filterName params:@{@"min":@23, @"max":@24}];
    
    unsigned int totalReplicated = 4;
    
    //check for each doc
    NSArray *docids = @[[NSString stringWithFormat:@"doc-%i", 1],
                        [NSString stringWithFormat:@"doc-%i", 3],
                        [NSString stringWithFormat:@"doc-%i", 13],
                        [NSString stringWithFormat:@"doc-%i", 23]];
    
    NSArray *localDocs = [self.datastore getDocumentsWithIds:docids];
    STAssertNotNil(localDocs, @"nil");
    STAssertTrue(localDocs.count == totalReplicated, @"unexpected number of docs: %@",localDocs.count);
    STAssertTrue(self.datastore.documentCount == totalReplicated,
                 @"Incorrect number of documents created %lu", self.datastore.documentCount);
    
}

-(void) testPushFilteredReplicationAllowOne {
    
    // Create docs in local store
    [self createLocalDocs:10];
    
    CDTFilterBlock myFilter = ^BOOL(CDTDocumentRevision *rev, NSDictionary *param){
        return [[rev body][@"docnum"] isEqual:param[@"pickme"]];
    };
    
    [self pushToRemoteWithFilter:myFilter params:@{@"pickme":@3}];
    
    [self assertRemoteDatabaseHasDocCount:1
                              deletedDocs:0];

    //make sure the remote database has the appropriate document
    NSURL *docURL = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:@"doc-3"];
    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    UNIHTTPJsonResponse *response = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    NSDictionary *jsonResponse = response.body.object;
    STAssertTrue([jsonResponse[@"_id"] isEqual:@"doc-3"], @"%@", jsonResponse);
    STAssertTrue([jsonResponse[@"docnum"] isEqual:@3], @"%@", jsonResponse);
    
}

-(void) testPushFilteredReplicationAllowSome {
    
    // Create docs in local store
    [self createLocalDocs:10];
    
    CDTFilterBlock myFilter = ^BOOL(CDTDocumentRevision *rev, NSDictionary *param){
        NSInteger docNum = [[rev body][@"docnum"] integerValue];
        NSInteger threshold = [param[@"threshold"] integerValue];
        return docNum > threshold;
    };
    
    [self pushToRemoteWithFilter:myFilter params:@{@"threshold":@3}];
    
    [self assertRemoteDatabaseHasDocCount:7
                              deletedDocs:0];
    
}

-(void) testPushStateAfterStopping
{
    // Create docs in local store
    int nlocalDocs = 5000;
    [self createLocalDocs:nlocalDocs];

    CDTPushReplication *push = [CDTPushReplication replicationWithSource:self.datastore
                                                                  target:self.primaryRemoteDatabaseURL];
    
    CDTReplicator *replicator =  [self.replicatorFactory oneWay:push error:nil];
    
    CDTTestReplicatorDelegateStopAfterStart *myDelegate = [[CDTTestReplicatorDelegateStopAfterStart alloc] init];
    replicator.delegate = myDelegate;
    
    NSError *error;
    if (![replicator startWithError:&error]) {
        STFail(@"CDTReplicator -startWithError: %@", error);
    }
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }

    STAssertEquals(replicator.state, CDTReplicatorStateStopped, @"expected a different state: %d (%@)",
                   replicator.state, [CDTReplicator stringForReplicatorState:replicator.state]);
    
    BOOL docComparison = [self compareDocCount:self.datastore
      expectFewerDocsInRemoteDatabase:self.primaryRemoteDatabaseURL];
    
    STAssertTrue(docComparison, @"Remote database doesn't have fewer docs than local.");
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

        [self.datastore deleteDocumentFromRevision:rev error:&error];
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

    [self createRemoteDatabase:thirdDatabaseName instanceURL:self.remoteRootURL];

    NSURL *thirdDatabase = [self.remoteRootURL URLByAppendingPathComponent:thirdDatabaseName];

    CDTPushReplication *push = [CDTPushReplication replicationWithSource:self.datastore
                                                                  target:thirdDatabase];
    
    CDTReplicator *replicator = [self.replicatorFactory oneWay:push error:nil];

    NSLog(@"Replicating to %@", [thirdDatabase absoluteString]);
    NSError *error;
    if (![replicator startWithError:&error]) {
        STFail(@"CDTReplicator -startWithError: %@", error);
    }
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:thirdDatabase];
    STAssertTrue(same, @"Remote and local databases differ");

    [self deleteRemoteDatabase:thirdDatabaseName instanceURL:self.remoteRootURL];
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

    [self createRemoteDatabase:thirdDatabaseName instanceURL:self.remoteRootURL];

    NSURL *thirdDatabase = [self.remoteRootURL URLByAppendingPathComponent:thirdDatabaseName];

    CDTPushReplication *push = [CDTPushReplication replicationWithSource:self.datastore
                                                                  target:thirdDatabase];
    
    CDTReplicator *replicator = [self.replicatorFactory oneWay:push error:nil];
    
    NSLog(@"Replicating to %@", [thirdDatabase absoluteString]);
    NSError *error;
    if (![replicator startWithError:&error]) {
        STFail(@"CDTReplicator -startWithError: %@", error);
    }
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:thirdDatabase];
    STAssertTrue(same, @"Remote and local databases differ");

    [self deleteRemoteDatabase:thirdDatabaseName instanceURL:self.remoteRootURL];
}


-(void) testPullClientFilteredLots {
    // Create large number of documents locally and remotely
    // ensure all updated documents on remote side are pulled
    // ensure new documents on remote side matching id list are pulled
    
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    int localdocs = 5000;
    int remotedocs = 5000;
    
    // 0..5000 local
    // 5001..10000 remote
    // then upload 2-rev 0..5000 remote
    
    [self createLocalDocs:localdocs];
    [self createRemoteDocs:localdocs+1 count:remotedocs];
    // now do some updates
    for (CDTDocumentRevision *rev in [self.datastore getAllDocuments]) {
        // 2-rev, with the 1-rev as parent
        NSMutableDictionary *dict = [rev.body mutableCopy];
        NSString *localRevId = [rev revId];
        [dict setValue:localRevId forKey:@"_rev"];
        [dict setValue:@YES forKey:@"updated"];
        [self createRemoteDocWithId:rev.docId body:dict];
    }
    
    NSMutableArray *filterDocIds = [NSMutableArray array];
    int i;
    for (i=0; i<localdocs+remotedocs; i++) {
        if (i % 2 == 1) {
            [filterDocIds addObject:[NSString stringWithFormat:@"doc-%i", i+1]];
        }
    }
  
    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];
    
    //5000 local + 5000/2 remote = 7500
    STAssertEquals(self.datastore.documentCount, (unsigned long)(localdocs+remotedocs/2),
                   @"Incorrect number of documents created");

    //5000 local + 5000/2 remote + 5000 remote copies of local (rev-2)
    STAssertEquals(self.datastore.database.lastSequence, (long long)(localdocs+remotedocs/2+localdocs),
                   @"Incorrect sequence number");

    // document checks:
    // 0..5000 all have 2-rev
    // 5000..10000 are all even numbers and have a 1-rev
    for (CDTDocumentRevision *rev in [self.datastore getAllDocuments]) {
        long docNo = [[rev.docId substringFromIndex:4] integerValue];
        if (docNo <= localdocs+1) {
            STAssertTrue([rev.revId hasPrefix:@"2-"], @"rev id %@ does not start 2- for doc id %@", rev.revId, rev.docId);
        }
        if (docNo > localdocs && docNo <= localdocs+remotedocs+1) {
            STAssertTrue(docNo %2 == 0, @"document number must be even");
            STAssertTrue([rev.revId hasPrefix:@"1-"], @"rev id does not start 1-");
        }
    }
}

-(void) testPullClientFiltered {
    // Create n docs and pull a subset of them, filtered by ID
    
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    int ndocs = 50; //don't need 100k docs
    
    [self createRemoteDocs:ndocs];
    
    NSArray *filterDocIds = @[[NSString stringWithFormat:@"doc-%i", 1],
                        [NSString stringWithFormat:@"doc-%i", 3],
                        [NSString stringWithFormat:@"doc-%i", 13],
                        [NSString stringWithFormat:@"doc-%i", 23]];

    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];
    int count = [self.datastore documentCount];
    STAssertTrue(filterDocIds.count == [self.datastore documentCount], @"unexpected number of docs: %@",[self.datastore documentCount]);
    
    NSArray *localDocs = [self.datastore getDocumentsWithIds:filterDocIds];
    
    STAssertNotNil(localDocs, @"nil");
    STAssertTrue(localDocs.count == filterDocIds.count, @"unexpected number of docs: %@",localDocs.count);
    STAssertTrue(self.datastore.documentCount == filterDocIds.count,
                 @"Incorrect number of documents created %lu", self.datastore.documentCount);
}

-(void) testPullClientFilteredNewDocsAppear {
    // Create n docs and pull a subset of them, filtered by ID
    // then create another n docs, some of which are also included in the filter
    
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    int ndocs = 50; //don't need 100k docs
    
    [self createRemoteDocs:ndocs];
    
    NSArray *filterDocIds = @[[NSString stringWithFormat:@"doc-%i", 1],
                              [NSString stringWithFormat:@"doc-%i", 3],
                              [NSString stringWithFormat:@"doc-%i", 13],
                              [NSString stringWithFormat:@"doc-%i", 23],
                              [NSString stringWithFormat:@"doc-%i", 70]];
    
    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];

    STAssertEquals([self.datastore.database lastSequence], 4ll, @"Incorrect sequence number");
    STAssertEquals(self.datastore.documentCount, 4ul,
                   @"Incorrect number of documents created");
    
    // 50 more
    [self createRemoteDocs:51 count:ndocs];

    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];

    STAssertEquals([self.datastore.database lastSequence], 5ll, @"Incorrect sequence number");
    STAssertEquals(self.datastore.documentCount, 5ul,
                 @"Incorrect number of documents created");

    
    NSArray *localDocs = [self.datastore getAllDocuments];
    
    STAssertEquals(localDocs.count, filterDocIds.count, @"unexpected number of docs");
    STAssertEquals(self.datastore.documentCount, filterDocIds.count,
                 @"Incorrect number of documents created");
}

-(void) testPullClientFilterLargeRevTree {
    // create n docs with m revisions and pull a subset of them, filtered by ID
    
    int ndocs = 50;
    
    NSArray *filterDocIds = @[[NSString stringWithFormat:@"doc-%i", 1],
                              [NSString stringWithFormat:@"doc-%i", 3],
                              [NSString stringWithFormat:@"doc-%i", 13],
                              [NSString stringWithFormat:@"doc-%i", 23],
                              [NSString stringWithFormat:@"doc-%i", 70]];
    
    for(int i=0; i<ndocs; i++) {
        // Create the initial rev in remote datastore
        NSString *docId = [NSString stringWithFormat:@"doc-%i", i];
        [self createRemoteDocWithId:docId revs:50];
    }
    
    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];

    // 50 * 4 docs
    STAssertEquals([self.datastore.database lastSequence], 200ll, @"Incorrect sequence number");
    STAssertEquals(self.datastore.documentCount, 4ul,
                 @"Incorrect number of documents created");

    // 50 more
    for(int i=50; i<ndocs+50; i++) {
        // Create the initial rev in remote datastore
        NSString *docId = [NSString stringWithFormat:@"doc-%i", i];
        [self createRemoteDocWithId:docId revs:50];
    }
    
    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];
    
    STAssertEquals([self.datastore.database lastSequence], 250ll, @"Incorrect sequence number");
    STAssertEquals(self.datastore.documentCount, 5ul,
                 @"Incorrect number of documents created");

}

-(void) testPullClientFilterUpdates {
    // create n docs and pull a subset of them, filtered by ID
    // update them and pull the same subset, filtered by ID
    
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    int ndocs = 50; //don't need 100k docs
    
    [self createRemoteDocs:ndocs];
    
    NSArray *filterDocIds = @[[NSString stringWithFormat:@"doc-%i", 1],
                              [NSString stringWithFormat:@"doc-%i", 3],
                              [NSString stringWithFormat:@"doc-%i", 13],
                              [NSString stringWithFormat:@"doc-%i", 23],
                              [NSString stringWithFormat:@"doc-%i", 70]];
    
    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];

    STAssertEquals([self.datastore.database lastSequence], 4ll, @"Incorrect sequence number");
    STAssertEquals(self.datastore.documentCount, 4ul,
                 @"Incorrect number of documents created");
    
    // now do some updates
    for (CDTDocumentRevision *rev in [self.datastore getAllDocuments]) {
        NSMutableDictionary *dict = [rev.body mutableCopy];
        [dict setValue:rev.revId forKey:@"_rev"];
        [dict setValue:@YES forKey:@"updated"];
        [self createRemoteDocWithId:rev.docId body:dict];
    }

    [self pullFromRemoteWithClientFilterDocIds:filterDocIds];
    
    for (CDTDocumentRevision *rev in [self.datastore getAllDocuments]) {
        STAssertTrue([rev.revId hasPrefix:@"2-"], @"rev id does not start 2-");
    }

    STAssertEquals([self.datastore.database lastSequence], 8ll, @"Incorrect sequence number");
    STAssertEquals(self.datastore.documentCount, 4ul,
                 @"Incorrect number of documents updated");
}

/**
 Reproduce reported issue:
 
 1. Create remote database
 2. Add 250 docs of type A to remote database, 10 docs of type B.
 3. Remove all type A documents from remote database.
 4. Launch application. (test doesn't need to do this)
 5. Create new local database.
 6. Pull and push replicate from remote database to local database; wait until complete.
 7. Add 100 documents to local database of type A.
 8. Push replicate local to remote -> push replication fails
 
 I was able to reduce a couple of things:
 
  - The different "types" of documents was not important.
  - Number of removed documents doesn't matter.
  - Important thing is resurrecting deleted documents and pushing.
 */
-(void) test_CreateRemoteDeleteRemotePullPushCreateLocalPush
{
    // Create docs in remote database
    NSLog(@"Creating documents...");
    
    NSInteger startSuffix = 0;
    NSInteger remoteTotal = 10;
    NSInteger remoteDeleteCount = 5;
    NSInteger localTotal = 1;
    
    [self createRemoteDocs:remoteTotal suffixFrom:startSuffix];
    
    // Modify all the docs -- we know they're going to be doc-1 to doc-<n_docs+1>
    for (NSInteger i = startSuffix+1; i < remoteDeleteCount+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%li", (long)i];
        [self deleteRemoteDocWithId:docId];
    }
    
    [self pullFromRemote];
    [self pushToRemote];
    
    // These will have the same name as the replicated deleted docs.
    [self createLocalDocs:localTotal suffixFrom:startSuffix];
    
    // This should no longer fail
    [self pushToRemote];
    
    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}


/**
 Test that we can replicate resurrected documents. 
 
 This is a minimal example of the bug in test_CreateRemoteDeleteRemotePullPushCreateLocalPush.
 */
-(void) test_PushResurectedDocument
{
    [self createLocalDocs:1 suffixFrom:0];
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:@"doc-1" error:nil];
    [self.datastore deleteDocumentFromRevision:rev error:nil];
    
    [self createLocalDocs:1 suffixFrom:0];
    
    // This should fail
    [self pushToRemote];
    
    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.primaryRemoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}


@end
