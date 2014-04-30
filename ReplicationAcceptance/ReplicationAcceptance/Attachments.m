//
//  Attachments.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 20/03/2014.
//
//

#import "CloudantReplicationBase.h"

#import <UNIRest.h>

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
    CDTDocumentRevision *rev;
    NSArray *attachments;
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:self.remoteDatabase
                            targetDatastore:self.datastore];

    NSLog(@"Replicating from %@", [self.remoteDatabase absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    rev = [self.datastore getDocumentWithId:@"attachment1"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)1, @"Should be one attachment");
    
    rev = [self.datastore getDocumentWithId:@"attachment_3"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)3, @"Should be one attachment");
    
    rev = [self.datastore getDocumentWithId:@"attachment4"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)4, @"Should be one attachment");
}

/** 
 Regression test for issue at:
 
 https://github.com/couchbase/couchbase-lite-ios/commit/b5ecc07c8688a5d834992a51a23cd99faf8be0db
 */
- (void)testRevposIssueFixed
{
    self.remoteRootURL = [NSURL URLWithString:@"http://localhost:5984"];
    
    NSString *primaryRemoteDatabaseName = [NSString stringWithFormat:@"%@-test-database-%@",
                                      self.remoteDbPrefix,
                                      [CloudantReplicationBase generateRandomString:5]];
    NSURL *primaryRemoteDatabaseURL = [self.remoteRootURL URLByAppendingPathComponent:primaryRemoteDatabaseName];
    
    // should be calling the shared method here
    NSDictionary* headers = @{@"accept": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[primaryRemoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSData data]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db create failed");
    
    NSString *docId = @"attachment_doc_1";
    
    //
    // Create document
    //
    
    NSString *revId;
    NSDictionary *dict = @{@"hello": @"world"};
    
    NSURL *docURL = [primaryRemoteDatabaseURL URLByAppendingPathComponent:docId];
    
    headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSJSONSerialization dataWithJSONObject:dict
                                                         options:0
                                                           error:nil]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Create document failed");
    revId = [response.body.object objectForKey:@"rev"];
    
    //
    // Create new rev with attachment
    //
    headers = @{@"accept": @"application/json",
                @"content-type": @"text/plain",
                @"If-Match": revId,
                @"Content-Length": @"10"};
    response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        NSURL *attachmentURL = [docURL URLByAppendingPathComponent:@"txtDoc"];
        [request setUrl:[attachmentURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[@"0123456789" dataUsingEncoding:NSUTF8StringEncoding]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"rev"] != nil, @"Adding attachment failed");
    revId = [response.body.object objectForKey:@"rev"];
    
    //
    // Issue HTTP COPY w/ Destination header to copy
    //
    NSString *copiedDocId = @"copied-document";
    NSURL *copiedDocURL = [primaryRemoteDatabaseURL URLByAppendingPathComponent:copiedDocId];
    headers = @{@"accept": @"application/json",
                @"content-type": @"application/json",
                @"Destination": copiedDocId};
    response = [[[UNIHTTPRequestWithBody alloc] initWithSimpleRequest:COPY
                                                          url:[docURL absoluteString] 
                                                      headers:headers
                                                     username:nil 
                                                     password:nil] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Copy document failed");
    revId = [response.body.object objectForKey:@"rev"];
    
    
    // Should end up with revpos > generation number
    headers = @{@"accept": @"application/json"};
    NSDictionary* json = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[copiedDocURL absoluteString]];
        [request setHeaders:headers];
    }] asJson].body.object;
    
    // The regression this tests for is triggered by the attachment's revpos being
    // greater than the generation of the revision.
    STAssertEqualObjects(json[@"_attachments"][@"txtDoc"][@"revpos"], @(2), @"revpos not expected");
    STAssertTrue([json[@"_rev"] hasPrefix:@"1"], @"revpos not expected");
    
    //
    // Replicate to local database
    //
    
    CDTDocumentRevision *rev;
    NSArray *attachments;
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:primaryRemoteDatabaseURL
                            targetDatastore:self.datastore];
    
    NSLog(@"Replicating from %@", [self.remoteDatabase absoluteString]);
    [replicator start];
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    //
    // Check both documents are okay
    //
    
    rev = [self.datastore getDocumentWithId:docId
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)1, @"Should be one attachment");
    
    rev = [self.datastore getDocumentWithId:copiedDocId
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)1, @"Should be one attachment");
}

@end
