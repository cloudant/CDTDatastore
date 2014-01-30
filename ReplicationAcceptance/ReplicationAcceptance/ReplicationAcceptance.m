//
//  ReplicationAcceptance.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import <SenTestingKit/SenTestingKit.h>

#import <CloudantSync.h>
#import <UNIRest.h>

#import "CloudantReplicationBase.h"

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

static NSUInteger n_docs = 100000;
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


#pragma mark - Tests

-(void)testPush100kDocuments
{
    NSError *error;

    // Create docs in local store
    NSLog(@"Creating documents...");
    for (long i = 1; i < n_docs+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%li", i];
        NSDictionary *dict = @{@"hello": @"world"};
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
        CDTDocumentRevision *rev = [self.datastore createDocumentWithId:docId
                                                              body:body
                                                             error:&error];
        STAssertNil(error, @"Error creating docs: %@", error);
        STAssertNotNil(rev, @"Error creating docs: rev was nil, but so was error");

        if (i % 1000 == 0) {
            NSLog(@" -> %li documents created", i);
        }
    }
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");

    [self pushToRemote];

    // Check document count in the remote DB
    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[self.remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    STAssertEquals([[NSNumber numberWithUnsignedInteger:n_docs] integerValue],
                   [response.body.object[@"doc_count"] integerValue],
                   @"Wrong number of remote docs");
}

-(void) testPull100kDocuments {

//    NSError *error;

    // Create docs in remote database
    NSLog(@"Creating documents...");
    NSMutableArray *docs = [NSMutableArray array];
    for (long i = 1; i < n_docs+1; i++) {
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

    [self pullFromRemote];

    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");
}

-(void) testPushLargeRevTree {
    NSError *error;

    // Create the initial rev
    NSString *docId = [NSString stringWithFormat:@"doc-0"];
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithId:docId
                                                               body:body
                                                              error:&error];
    STAssertNil(error, @"Error creating docs: %@", error);
    STAssertNotNil(rev, @"Error creating docs: rev was nil, but so was error");

    // Create revisions of document in local store
    for (long i = 0; i < largeRevTreeSize-1; i++) {
        rev = [self.datastore updateDocumentWithId:docId
                                           prevRev:rev.revId
                                              body:body
                                             error:&error];
    }
    STAssertEquals(self.datastore.documentCount, (NSUInteger)1, @"Incorrect number of documents created");
    STAssertTrue([rev.revId hasPrefix:@"1500"], @"Unexpected current rev in local document");

    [self pushToRemote];

    // Check document count in the remote DB
    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[self.remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    STAssertEquals([response.body.object[@"doc_count"] intValue],
                   1,
                   @"Wrong number of remote docs");

    // Check number of revs
    NSURL *docURL = [self.remoteDatabaseURL URLByAppendingPathComponent:docId];
    response = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
        [request setParameters:@{@"revs": @"true"}];
    }] asJson];
    NSDictionary *jsonResponse = response.body.object;

    // default couchdb revs_limit is 1000
    STAssertEquals([jsonResponse[@"_revisions"][@"ids"] count], (NSUInteger)1000, @"Wrong number of revs");
    STAssertTrue([jsonResponse[@"_rev"] hasPrefix:@"1500"], @"Not all revs seem to be replicated");
}

-(void) testPullLargeRevTree {
    NSError *error;
    NSString *revId;

    // Create the initial rev in remote datastore
    NSString *docId = [NSString stringWithFormat:@"doc-0"];
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
    for (long i = 0; i < largeRevTreeSize-1; i++) {
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
    STAssertTrue([revId hasPrefix:@"1500"], @"Unexpected current rev in local document");

    [self pullFromRemote];

    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:&error];
    STAssertNil(error, @"Error getting replicated doc: %@", error);
    STAssertNotNil(rev, @"Error creating doc: rev was nil, but so was error");

    STAssertTrue([rev.revId hasPrefix:@"1500"], @"Unexpected current rev in local document");
}


@end
