//
//  ReplicationAcceptance.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import <CloudantSync.h>
#import <UNIRest.h>
#import <TRVSMonitor.h>

#import "CloudantReplicationBase.h"
#import "CloudantReplicationBase+CompareDb.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"

@interface ReplicationAcceptance : CloudantReplicationBase

@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) CDTReplicatorFactory *replicatorFactory;

@property (nonatomic, strong) NSURL *remoteDatabaseURL;

@end

@implementation ReplicationAcceptance

static NSUInteger n_docs = 10000;
static NSUInteger largeRevTreeSize = 1500;

#pragma mark - setUp and tearDown

- (void)setUp
{
    [super setUp];

    // Create local and remote databases, start the replicator

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    STAssertNotNil(self.datastore, @"datastore is nil");

    NSString *remoteDatabaseName = [NSString stringWithFormat:@"%@-test-database-%@",
                                    self.remoteDbPrefix,
                                    [CloudantReplicationBase generateRandomString:5]];
    self.remoteDatabaseURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDatabaseName];

    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[self.remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSData data]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db create failed");

    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    [self.replicatorFactory start];
}

- (void)tearDown
{
    // Tear-down code here.

    // Delete remote database, stop the replicator.

    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest delete:^(UNISimpleRequest* request) {
        [request setUrl:[self.remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db delete failed");

    self.datastore = nil;

    [self.replicatorFactory stop];

    self.replicatorFactory = nil;

    [super tearDown];
}


#pragma mark - Replication helpers

-(void) pullFromRemote {
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:self.remoteDatabaseURL
                            targetDatastore:self.datastore];

    NSLog(@"Replicating from %@", [self.remoteDatabaseURL absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}

-(void) pushToRemote {
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:self.datastore
                                        targetURI:self.remoteDatabaseURL];

    NSLog(@"Replicating to %@", [self.remoteDatabaseURL absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}

#pragma mark - Doc CRUD helpers

-(void) createLocalDocs:(NSInteger)count
{
    [self createLocalDocs:count suffixFrom:0];
}

-(void) createLocalDocs:(NSInteger)count suffixFrom:(NSInteger)start
{
    [self createLocalDocs:count suffixFrom:start reverse:NO updates:NO];
}

/**
 * Create a given number local documents, with IDs of the form doc-1, doc-2 etc.
 *
 * @param count number of documents to create
 * @param start the number to start the suffix numbering, e.g., start = 100, first doc doc-101
 * @param reverse go from doc-100 -> doc-1
 * @param updates check for and update current doc if there is one
 */
-(void) createLocalDocs:(NSInteger)count
             suffixFrom:(NSInteger)start
                reverse:(BOOL)reverse
                updates:(BOOL)updates
{

    for (long i = 1; i < count+1; i++) {

        NSError *error;

        NSString *docId;
        NSInteger currentIndex = start + i;

        if (!reverse) {
            docId = [NSString stringWithFormat:@"doc-%li", (long)currentIndex];
        } else {
            NSInteger endIndex = start + count;
            docId = [NSString stringWithFormat:@"doc-%li", endIndex-currentIndex+1];
        }

        CDTDocumentRevision *rev;
        if (updates) {
            rev = [self.datastore getDocumentWithId:docId error:&error];
            if (error.code != 404) {  // new doc, so not error
                STAssertNil(error, @"Error creating docs: %@", error);
                STAssertNotNil(rev, @"Error creating docs: rev was nil");
            }
        }

        error = nil;

        NSDictionary *dict = @{@"hello": @"world"};
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
        if (rev == nil) {  // we need to update an existing rev
            rev = [self.datastore createDocumentWithId:docId
                                                  body:body
                                                 error:&error];
//            NSLog(@"Created %@", docId);
            STAssertNil(error, @"Error creating doc: %@", error);
            STAssertNotNil(rev, @"Error creating doc: rev was nil");
        } else {
            rev = [self.datastore updateDocumentWithId:docId
                                               prevRev:rev.revId
                                                  body:body
                                                 error:&error];
//            NSLog(@"Updated %@", docId);
            STAssertNil(error, @"Error updating doc: %@", error);
            STAssertNotNil(rev, @"Error updating doc: rev was nil");
        }


        if (i % 1000 == 0) {
            NSLog(@" -> %li documents created", i);
        }
    }
}

-(void) createLocalDocWithId:(NSString*)docId revs:(NSInteger)n_revs
{
    NSError *error;

    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithId:docId
                                                               body:body
                                                              error:&error];
    STAssertNil(error, @"Error creating docs: %@", error);
    STAssertNotNil(rev, @"Error creating docs: rev was nil, but so was error");

    // Create revisions of document in local store
    rev = [self addRevsToDocumentRevision:rev count:n_revs];

    NSString *revPrefix = [NSString stringWithFormat:@"%li", (long)n_revs];
    STAssertTrue([rev.revId hasPrefix:revPrefix], @"Unexpected current rev in local document, %@", rev.revId);
}

-(CDTDocumentRevision*) addRevsToDocumentRevision:(CDTDocumentRevision*)rev count:(NSInteger)n_revs
{
    NSError *error;
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    for (long i = 0; i < n_revs-1; i++) {
        rev = [self.datastore updateDocumentWithId:rev.docId
                                           prevRev:rev.revId
                                              body:body
                                             error:&error];
    }
    return rev;
}

-(void) createRemoteDocs:(NSInteger)count
{
    NSMutableArray *docs = [NSMutableArray array];
    for (long i = 1; i < count+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%li", i];
        NSDictionary *dict = @{@"_id": docId, @"hello": @"world"};
        [docs addObject:dict];
    }

    NSDictionary *bulk_json = @{@"docs": docs};

    NSURL *bulk_url = [self.remoteDatabaseURL URLByAppendingPathComponent:@"_bulk_docs"];

    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest postEntity:^(UNIBodyRequest* request) {
        [request setUrl:[bulk_url absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSJSONSerialization dataWithJSONObject:bulk_json
                                                         options:0
                                                           error:nil]];
    }] asJson];
    //    NSLog(@"%@", response.body.array);
    STAssertTrue([response.body.array count] == n_docs, @"Remote db has wrong number of docs");
}

-(void) createRemoteDocWithId:(NSString*)docId revs:(NSInteger)n_revs
{
    NSString *revId;
    NSDictionary *dict = @{@"hello": @"world"};

    NSURL *docURL = [self.remoteDatabaseURL URLByAppendingPathComponent:docId];

    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSJSONSerialization dataWithJSONObject:dict
                                                         options:0
                                                           error:nil]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Create document failed");
    revId = [response.body.object objectForKey:@"rev"];

    // Create revisions of document in remote store
    for (long i = 0; i < n_revs-1; i++) {
        headers = @{@"accept": @"application/json",
                    @"content-type": @"application/json",
                    @"If-Match": revId};
        response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
            [request setUrl:[docURL absoluteString]];
            [request setHeaders:headers];
            [request setBody:[NSJSONSerialization dataWithJSONObject:dict
                                                             options:0
                                                               error:nil]];
        }] asJson];
        revId = [response.body.object objectForKey:@"rev"];
    }

    NSString *revPrefix = [NSString stringWithFormat:@"%li", (long)n_revs];
    STAssertTrue([revId hasPrefix:revPrefix], @"Unexpected current rev in local document, %@", revId);
}

-(NSDictionary*) remoteDbMetadata
{
    // Check document count in the remote DB
    NSDictionary* headers = @{@"accept": @"application/json"};
    return [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[self.remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson].body.object;
}

-(void) assertRemoteDatabaseHasDocCount:(NSInteger)count deletedDocs:(NSInteger)deleted
{
    NSDictionary *dbMeta = [self remoteDbMetadata];
    STAssertEquals(count,
                   [dbMeta[@"doc_count"] integerValue],
                   @"Wrong number of remote docs");
    STAssertEquals(deleted,
                   [dbMeta[@"doc_del_count"] integerValue],
                   @"Wrong number of remote deleted docs");
}


#pragma mark - Tests

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
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

-(void) testPullLotsOfOneRevDocuments {

//    NSError *error;

    // Create docs in remote database
    NSLog(@"Creating documents...");

    [self createRemoteDocs:n_docs];

    [self pullFromRemote];

    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

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
    NSURL *docURL = [self.remoteDatabaseURL URLByAppendingPathComponent:docId];
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
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

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
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}


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
        NSURL *docURL = [self.remoteDatabaseURL URLByAppendingPathComponent:docId];
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
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}


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
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

-(void) test_pushDocsAsWritingThem
{
    TRVSMonitor *monitor = [[TRVSMonitor alloc] initWithExpectedSignalCount:2];
    [self performSelectorInBackground:@selector(pushDocsAsWritingThem_pullReplicateThenSignal:)
                           withObject:monitor];
    [self performSelectorInBackground:@selector(pushDocsAsWritingThem_populateLocalDatabaseThenSignal:)
                           withObject:monitor];

    [monitor wait];

    BOOL same = [self compareDatastore:self.datastore
                          withDatabase:self.remoteDatabaseURL];
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
                          withDatabase:self.remoteDatabaseURL];
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
                          withDatabase:self.remoteDatabaseURL];
    STAssertTrue(same, @"Remote and local databases differ");
}

-(void) pullDocsWhileWritingSame_pullReplicateThenSignal:(TRVSMonitor*)monitor
{
    [self pullFromRemote];
    [monitor signal];
}

-(void) pullDocsWhileWritingSame_populateLocalDatabaseThenSignal:(TRVSMonitor*)monitor
{
    [self createLocalDocs:n_docs suffixFrom:0 reverse:YES updates:YES];
    [monitor signal];
}


@end
