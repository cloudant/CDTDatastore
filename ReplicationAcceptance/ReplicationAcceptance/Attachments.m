//
//  Attachments.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 20/03/2014.
//
//

#import "CloudantReplicationBase.h"
#import "CloudantReplicationBase+CompareDb.h"

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

- (void)testReplicateSeveralRemoteDocumentsWithAttachments
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

- (void)testReplicateManyLocalAttachments
{
    NSUInteger nAttachments = 100;
    
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
    
    //
    // Add attachments to a document in the local store
    //
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    // { document ID: number of attachments to create }
    NSDictionary *docs = @{@"attachments1": @(nAttachments)};
    for (NSString* docId in [docs keyEnumerator]) {
        
        NSError *error;
        
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @12}];
        CDTDocumentRevision *rev = [self.datastore createDocumentWithId:docId
                                                                   body:body
                                                                  error:&error];
        STAssertNotNil(rev, @"Unable to create document");
        
        NSMutableArray *attachments = [NSMutableArray array];
        for (NSInteger i = 1; i <= nAttachments; i++) {
            NSString *content = [NSString stringWithFormat:@"blahblah-%li", (long)i];
            NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
            NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
            CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                                  name:name
                                                                                  type:@"text/plain"];
            [attachments addObject:attachment];
            
            [originalAttachments setObject:data forKey:name];
        }
        
        rev = [self.datastore updateAttachments:attachments
                                         forRev:rev
                                          error:&error];
        STAssertNotNil(rev, @"Unable to add attachments to document");
        STAssertEquals(nAttachments, 
                       [[self.datastore attachmentsForRev:rev
                                                    error:nil] count],
                       @"All attachments not found");
    }
    
    // 
    // Push to remote
    // 
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:self.datastore targetURI:remoteDbURL];
    
    NSLog(@"Replicating from %@", [remoteDbURL absoluteString]);
    [replicator start];
    
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    //
    // Checks
    //
    
    STAssertTrue([self compareDatastore:self.datastore withDatabase:remoteDbURL],
                 @"Local and remote database comparison failed");
    
    STAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:remoteDbURL],
                 @"Local and remote database attachment comparison failed");
                 
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

/**
 Test that deleting attachments locally is replicated to a
 remote database.
 */
- (void)testAddLocalReplicateDeleteLocalReplicate
{
    NSUInteger nAttachments = 100;
    
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
    
    //
    // Add attachments to a document in the local store
    //
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    // { document ID: number of attachments to create }
    NSDictionary *docs = @{@"attachments1": @(nAttachments)};
    CDTDocumentRevision *rev;
    for (NSString* docId in [docs keyEnumerator]) {
        
        NSError *error;
        
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @12}];
        rev = [self.datastore createDocumentWithId:docId
                                              body:body
                                             error:&error];
        STAssertNotNil(rev, @"Unable to create document");
        
        NSMutableArray *attachments = [NSMutableArray array];
        for (NSInteger i = 1; i <= nAttachments; i++) {
            NSString *content = [NSString stringWithFormat:@"blahblah-%li", (long)i];
            NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
            NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
            CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                                  name:name
                                                                                  type:@"text/plain"];
            [attachments addObject:attachment];
            
            [originalAttachments setObject:data forKey:name];
        }
        
        rev = [self.datastore updateAttachments:attachments
                                         forRev:rev
                                          error:&error];
        STAssertNotNil(rev, @"Unable to add attachments to document");
        STAssertEquals(nAttachments, 
                       [[self.datastore attachmentsForRev:rev
                                                    error:nil] count],
                       @"All attachments not found");
    }
    
    // 
    // Push to remote
    // 
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:self.datastore
                                        targetURI:remoteDbURL];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Delete some attachments, then replicate to check the changes
    // replicate successfully.
    //
    
    NSMutableArray *attachmentNamesToDelete = [NSMutableArray array];
    for (int i = 1; i < nAttachments; i+=2) {  // every second att
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        [attachmentNamesToDelete addObject:name];
    }
    rev = [self.datastore removeAttachments:attachmentNamesToDelete
                                    fromRev:rev 
                                      error:nil];
    STAssertNotNil(rev, @"Attachments are not deleted.");
    STAssertEquals([[self.datastore attachmentsForRev:rev
                                                error:nil] count],
                   nAttachments/2,
                   @"Wrong attachment count after deleting");
    
    replicator = [self.replicatorFactory onewaySourceDatastore:self.datastore 
                                                     targetURI:remoteDbURL];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Checks
    //
    
    STAssertTrue([self compareDatastore:self.datastore withDatabase:remoteDbURL],
                 @"Local and remote database comparison failed");
    
    STAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:remoteDbURL],
                 @"Local and remote database attachment comparison failed");
    
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

- (void)testReplicateManyRemoteAttachments
{
    NSUInteger nAttachments = 100;
    
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
    NSDictionary *docs = @{@"attachments1": @(nAttachments)};
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
    STAssertEquals([attachments count], nAttachments, @"Wrong number of attachments");
    
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
 Test that updates to an attachment are replicated correctly.
 */
- (void)testReplicateRemoteDocumentUpdate
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
    NSString *docId = @"attachments1";
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:remoteDbURL];
    
    NSString *attachmentName = @"attachment-1";
    NSString *originalContent = @"originalContent";
    NSData *txtData = [originalContent dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:attachmentName
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:remoteDbURL];
    
    //
    // Replicate
    //
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:remoteDbURL
                            targetDatastore:self.datastore];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Update the local attachment, replicate, check updated remotely
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    
    NSString *updatedContent = @"updatedContent";
    NSData *data = [updatedContent dataUsingEncoding:NSUTF8StringEncoding];
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"text/plain"];    
    rev = [self.datastore updateAttachments:@[attachment]
                                     forRev:rev
                                      error:nil];
    STAssertNotNil(rev, @"Unable to add attachments to document");
    
    replicator = [self.replicatorFactory onewaySourceDatastore:self.datastore
                                                     targetURI:remoteDbURL];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Checks
    //
    
    STAssertTrue([self compareDatastore:self.datastore withDatabase:remoteDbURL],
                 @"Local and remote database comparison failed");
    
    STAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:remoteDbURL],
                 @"Local and remote database attachment comparison failed");
    
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

/**
 Test that deleting an attachment locally is replicated correctly.
 */
- (void)testReplicateRemoteDocumentDeleteLocalCheckReplicated
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
    NSString *docId = @"attachments1";
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:remoteDbURL];
    
    NSString *attachmentName = @"attachment-1";
    NSString *originalContent = @"an-attachment";
    NSData *txtData = [originalContent dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:attachmentName
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:remoteDbURL];
    
    //
    // Replicate
    //
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:remoteDbURL
                            targetDatastore:self.datastore];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Delete the local attachment, replicate, check deleted remotely
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    rev = [self.datastore removeAttachments:@[attachmentName]
                                    fromRev:rev
                                      error:nil];
    STAssertNotNil(rev, @"Unable to add attachments to document");
    STAssertEquals([[self.datastore attachmentsForRev:rev
                                                error:nil] count],
                   (NSUInteger)0,
                   @"Wrong attachment count after deleting");
    
    replicator = [self.replicatorFactory onewaySourceDatastore:self.datastore
                                                     targetURI:remoteDbURL];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Checks
    //
    
    STAssertTrue([self compareDatastore:self.datastore withDatabase:remoteDbURL],
                 @"Local and remote database comparison failed");
    STAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:remoteDbURL],
                 @"Local and remote database attachment comparison failed");
    
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

/**
 Test that deleting an attachment remotely is replicated correctly.
 */
- (void)testReplicateRemoteDocumentDeleteRemoteCheckReplicated
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
    NSString *docId = @"attachments1";
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:remoteDbURL];
    
    NSString *attachmentName = @"attachment-1";
    NSString *originalContent = @"an-attachment";
    NSData *txtData = [originalContent dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:attachmentName
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:remoteDbURL];
    
    //
    // Replicate
    //
    
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:remoteDbURL
                            targetDatastore:self.datastore];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Delete the remote attachment, replicate, check deleted locally
    //
    
    NSDictionary* headers = @{@"accept": @"application/json",
                              @"If-Match": revId};
    UNIHTTPJsonResponse* response = [[UNIRest delete:^(UNISimpleRequest* request) {
        NSURL *docURL = [remoteDbURL URLByAppendingPathComponent:docId];
        NSURL *attachmentURL = [docURL URLByAppendingPathComponent:attachmentName];
        [request setUrl:[attachmentURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db delete failed");
    
    replicator = [self.replicatorFactory onewaySourceURI:remoteDbURL
                                         targetDatastore:self.datastore];
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    STAssertNotNil(rev, @"Unable to get doc");
    STAssertEquals([[self.datastore attachmentsForRev:rev
                                                error:nil] count],
                   (NSUInteger)0,
                   @"Wrong attachment count after deleting");
    
    
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
    STAssertEqualObjects(json[@"_attachments"][@"txtDoc"][@"revpos"], 
                         @(2), 
                         @"revpos not expected");
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
