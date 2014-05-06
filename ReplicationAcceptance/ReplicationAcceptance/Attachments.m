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
    //
    // Set up remote database
    //
    
    self.remoteRootURL = [NSURL URLWithString:@"http://localhost:5984"];
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
    // { document ID: number of attachments to create }
    NSDictionary *docs = @{@"attachments1": @(1),
                           @"attachments3": @(3),
                           @"attachments4": @(4)};
    for (NSString* docId in [docs keyEnumerator]) {
        
        NSString *revId = [self createRemoteDocumentWithId:docId
                                    body:@{@"hello": @"world"}
                             databaseURL:remoteDbURL];
        
        NSInteger nAttachments = [docs[docId] integerValue];
        for (NSInteger i = 1; i <= nAttachments; i++) {
            NSString *name = [NSString stringWithFormat:@"txtDoc%li", (long)i];
            NSData *txtData = [@"0123456789" dataUsingEncoding:NSUTF8StringEncoding];
            revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                        revId:revId
                                               attachmentName:name
                                                  contentType:@"text/plain"
                                                         data:txtData
                                                  databaseURL:remoteDbURL];
        }
    }
    
    //
    // Replicate and check
    //
    
    CDTDocumentRevision *rev;
    NSArray *attachments;
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:remoteDbURL
                            targetDatastore:self.datastore];

    NSLog(@"Replicating from %@", [remoteDbURL absoluteString]);
    [replicator start];

    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    rev = [self.datastore getDocumentWithId:@"attachments1"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)1, @"Should be one attachment");
    
    rev = [self.datastore getDocumentWithId:@"attachments3"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)3, @"Should be one attachment");
    
    rev = [self.datastore getDocumentWithId:@"attachments4"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)4, @"Should be one attachment");
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

- (void)testReplicateManyAttachments
{
    //
    // Set up remote database
    //
    
    self.remoteRootURL = [NSURL URLWithString:@"http://localhost:5984"];
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    
    // { document ID: number of attachments to create }
    NSDictionary *docs = @{@"attachments1": @(10)};
    for (NSString* docId in [docs keyEnumerator]) {
        
        NSString *revId = [self createRemoteDocumentWithId:docId
                                                      body:@{@"hello": @"world"}
                                               databaseURL:remoteDbURL];
        
        NSInteger nAttachments = [docs[docId] integerValue];
        for (NSInteger i = 1; i <= nAttachments; i++) {
            NSString *name = [NSString stringWithFormat:@"txtDoc%li", (long)i];
            NSString *content = [NSString stringWithFormat:@"doc%li", (long)i];
            NSData *txtData = [content dataUsingEncoding:NSUTF8StringEncoding];
            revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                        revId:revId
                                               attachmentName:name
                                                  contentType:@"text/plain"
                                                         data:txtData
                                                  databaseURL:remoteDbURL];
            originalAttachments[name] = txtData;
        }
    }
    
    //
    // Replicate and check
    //
    
    CDTDocumentRevision *rev;
    NSArray *attachments;
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:remoteDbURL
                            targetDatastore:self.datastore];
    
    NSLog(@"Replicating from %@", [remoteDbURL absoluteString]);
    [replicator start];
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    rev = [self.datastore getDocumentWithId:@"attachments1"
                                      error:nil];
    attachments = [self.datastore attachmentsForRev:rev error:nil];
    STAssertEquals([attachments count], (NSUInteger)10, @"Should be one attachment");
    
    for (NSString *attachmentName in [originalAttachments keyEnumerator]) {
        NSError *error;
        CDTAttachment *a = [self.datastore attachmentNamed:attachmentName
                                                    forRev:rev
                                                     error:&error];
        STAssertNotNil(a, @"No attachment named %@", attachmentName);
        STAssertNil(error, @"error wasn't nil");
        
        NSData *data = [a dataFromAttachmentContent];
        NSData *originalData = originalAttachments[attachmentName];
        
        STAssertEqualObjects([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], 
                             [[NSString alloc] initWithData:originalData encoding:NSUTF8StringEncoding],
                             @"attachment content didn't match");
    }
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

/** 
 Regression test for issue at:
 
 https://github.com/couchbase/couchbase-lite-ios/commit/b5ecc07c8688a5d834992a51a23cd99faf8be0db
 */
- (void)testRevposIssueFixed
{
    self.remoteRootURL = [NSURL URLWithString:@"http://localhost:5984"];
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                                      self.remoteDbPrefix,
                                      [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
    
    //
    // Create document
    //
    
    NSString *docId = @"attachment_doc_1";
    NSString *revId;
    NSDictionary *dict = @{@"hello": @"world"};
    
    revId = [self createRemoteDocumentWithId:docId
                                        body:dict
                                 databaseURL:remoteDbURL];
    
    //
    // Create new rev with attachment
    //
    
    NSData *txtData = [@"0123456789" dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:@"txtDoc"
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:remoteDbURL];
    
    //
    // Issue HTTP COPY w/ Destination header to copy
    //
    NSString *copiedDocId = @"copied-document";
    NSURL *copiedDocURL = [remoteDbURL URLByAppendingPathComponent:copiedDocId];
    
    [self copyRemoteDocumentWithId:docId
                              toId:copiedDocId
                       databaseURL:remoteDbURL];
    
    
    // Should end up with revpos > generation number
    NSDictionary *headers = @{@"accept": @"application/json"};
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
    [self.replicatorFactory onewaySourceURI:remoteDbURL
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
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

@end
