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
#import <FMDatabase.h>

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
    
//    self.remoteRootURL = [NSURL URLWithString:@"http://localhost:5984"];
}

- (void)tearDown
{
    // Tear-down code here.

    self.datastore = nil;

    self.replicatorFactory = nil;
    
    [super tearDown];
}

#pragma mark Test helpers

- (BOOL)isNumberOfAttachmentsForRevision:(CDTDocumentRevision*)rev
                                 equalTo:(NSUInteger)expected
{
    NSArray *attachments = [self.datastore attachmentsForRev:rev
                                                       error:nil];
    return [attachments count] == expected;
}

- (void)pullFrom:(NSURL*)remoteDbURL to:(CDTDatastore*)local
{
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceURI:remoteDbURL
                            targetDatastore:local];
    [replicator startWithError:nil];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
}

- (void)pushTo:(NSURL*)remoteDbURL from:(CDTDatastore*)local
{
    CDTReplicator *replicator =
    [self.replicatorFactory onewaySourceDatastore:local 
                                        targetURI:remoteDbURL];
    [replicator startWithError:nil];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
    }
}

- (void)deleteAttachmentNamed:(NSString*)attachmentName
                 fromDocument:(NSString*)docId
                   ofRevision:(NSString*)revId
                 fromDatabase:(NSURL*)remoteDbURL
{
    NSDictionary* headers = @{@"accept": @"application/json",
                              @"If-Match": revId};
    UNIHTTPJsonResponse* response = [[UNIRest delete:^(UNISimpleRequest* request) {
        NSURL *docURL = [remoteDbURL URLByAppendingPathComponent:docId];
        NSURL *attachmentURL = [docURL URLByAppendingPathComponent:attachmentName];
        [request setUrl:[attachmentURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db delete failed");
}

#pragma mark Tests

- (void)testReplicateSeveralRemoteDocumentsWithAttachments
{
    //
    // Set up remote database
    //
    
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
    // Replicate
    //
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev;
    
    rev = [self.datastore getDocumentWithId:@"attachments1"
                                      error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)1],
                 @"Incorrect number of attachments");
    
    rev = [self.datastore getDocumentWithId:@"attachments3"
                                      error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)3],
                 @"Incorrect number of attachments");
    
    rev = [self.datastore getDocumentWithId:@"attachments4"
                                      error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)4],
                 @"Incorrect number of attachments");
    
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
        
    NSError *error;
    
    NSString *docId = @"document1";
    CDTMutableDocumentRevision *mrev = [CDTMutableDocumentRevision revision];
    mrev.docId = docId;
    mrev.body =@{@"hello": @12};
    
    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    for (NSInteger i = 1; i <= nAttachments; i++) {
        NSString *content = [NSString stringWithFormat:@"blahblah-%li", (long)i];
        NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                              name:name
                                                                              type:@"text/plain"];
        [attachments setObject:attachment forKey:name];
        
        [originalAttachments setObject:data forKey:name];
    }
    
    mrev.attachments = attachments;
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mrev error:&error];


    STAssertNotNil(rev, @"Unable to add attachments to document");
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    // 
    // Push to remote
    // 
    
    [self pushTo:remoteDbURL from:self.datastore];
    
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
    NSString *docId = @"document1";
    
    NSError *error;
    CDTMutableDocumentRevision *mrev = [CDTMutableDocumentRevision revision];
    mrev.docId = docId;
    mrev.body =@{@"hello": @12};
    
    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    for (NSInteger i = 1; i <= nAttachments; i++) {
        NSString *content = [NSString stringWithFormat:@"blahblah-%li", (long)i];
        NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                              name:name
                                                                              type:@"text/plain"];
        [attachments setObject:attachment forKey:name];
        
        [originalAttachments setObject:data forKey:name];
    }
    
    mrev.attachments = attachments;
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mrev error:&error];

    STAssertNotNil(rev, @"Unable to add attachments to document");
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    // 
    // Push to remote
    // 
    
    [self pushTo:remoteDbURL from:self.datastore];
    
    //
    // Delete some attachments, then replicate to check the changes
    // replicate successfully.
    //
    
    for (int i = 1; i < nAttachments; i+=2) {  // every second att
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        [attachments removeObjectForKey:name];
    }
    mrev.attachments = attachments;
    mrev.sourceRevId = rev.revId;
    
    rev = [self.datastore updateDocumentFromRevision:mrev error:nil];
    
    STAssertNotNil(rev, @"Attachments are not deleted.");
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments/2],
                 @"Incorrect number of attachments");
    
    [self pushTo:remoteDbURL from:self.datastore];
    
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
- (void)testAddLocalReplicateDeleteLocalReplicate412Retry
{
    NSUInteger nAttachments = 2;
    
    //
    // Set up remote database
    //
    
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
    NSString *docId = @"document1";
    
    NSError *error;
    CDTMutableDocumentRevision *mrev = [CDTMutableDocumentRevision revision];
    mrev.docId = docId;
    mrev.body =@{@"hello": @12};
    
    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    for (NSInteger i = 1; i <= nAttachments; i++) {
        NSString *content = [NSString stringWithFormat:@"blahblah-%li", (long)i];
        NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                              name:name
                                                                              type:@"text/plain"];
        [attachments setObject:attachment forKey:name];
        
        [originalAttachments setObject:data forKey:name];
    }
    
    mrev.attachments = attachments;
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mrev error:&error];
    
    STAssertNotNil(rev, @"Unable to add attachments to document");
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    // 
    // Push to remote
    // 
    
    [self pushTo:remoteDbURL from:self.datastore];
    
    //
    // Delete some attachments, then replicate to check the changes
    // replicate successfully.
    //
    
    for (int i = 1; i < nAttachments; i+=2) {  // every second att
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        [attachments removeObjectForKey:name];
    }
    mrev.attachments = attachments;
    mrev.sourceRevId = rev.revId;
    
    rev = [self.datastore updateDocumentFromRevision:mrev error:nil];
    
    STAssertNotNil(rev, @"Attachments are not deleted.");
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments/2],
                 @"Incorrect number of attachments");
    
    // To get the 412 response to happen, we have to change the revpos in the attachments
    // table for the remaining attachment.
    
    [self.datastore.database.fmdbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql = @"UPDATE attachments SET revpos=1 WHERE filename='attachment-2'";
        [db executeUpdate:sql];
    }];
    
    [self pushTo:remoteDbURL from:self.datastore];
    
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
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    
    
    //
    // Upload attachments to remote document
    //
    
    NSString *docId = @"document1";
        
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:remoteDbURL];
    
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
    
    //
    // Replicate
    //
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev;
    rev = [self.datastore getDocumentWithId:docId
                                      error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    for (NSString *attachmentName in [originalAttachments keyEnumerator]) {

        CDTAttachment *a = [[rev attachments] objectForKey:attachmentName];
        
        STAssertNotNil(a, @"No attachment named %@", attachmentName);
        
        NSData *data = [a dataFromAttachmentContent];
        NSData *originalData = originalAttachments[attachmentName];
        
        STAssertEqualObjects(data, originalData, @"attachment content didn't match");
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
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
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
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
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
    NSError *error = nil;
    CDTMutableDocumentRevision *mrev = [rev mutableCopy];
    [mrev.attachments setObject:attachment forKey:attachmentName];
    rev = [self.datastore updateDocumentFromRevision:mrev error:&error];

    STAssertNotNil(rev, @"Unable to add attachments to document");
    
    [self pushTo:remoteDbURL from:self.datastore];
    
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
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
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
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
    //
    // Delete the local attachment, replicate, check deleted remotely
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    CDTMutableDocumentRevision *mrev = [rev mutableCopy];
    [mrev.attachments removeObjectForKey:attachmentName];
    rev = [self.datastore updateDocumentFromRevision:mrev error:nil];

    STAssertNotNil(rev, @"Unable to add attachments to document");
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)0],
                 @"Incorrect number of attachments");
    
    
    [self pushTo:remoteDbURL from:self.datastore];
    
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
    
    NSString *remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:remoteDbName];
    
    [self createRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
    
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
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
    //
    // Delete the remote attachment, replicate, check deleted locally
    //
    
    [self deleteAttachmentNamed:attachmentName
                   fromDocument:docId
                     ofRevision:revId
                   fromDatabase:remoteDbURL];
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)0],
                 @"Incorrect number of attachments");
    
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
    
    [self pullFrom:remoteDbURL to:self.datastore];
    
    //
    // Check both documents are okay
    //
    
    CDTDocumentRevision *rev;
    
    rev = [self.datastore getDocumentWithId:docId
                                      error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)1],
                 @"Incorrect number of attachments");
    
    rev = [self.datastore getDocumentWithId:copiedDocId
                                      error:nil];
    STAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)1],
                 @"Incorrect number of attachments");
    
    //
    // Clean up
    //
    
    [self deleteRemoteDatabase:remoteDbName
                   instanceURL:self.remoteRootURL];
}

@end
