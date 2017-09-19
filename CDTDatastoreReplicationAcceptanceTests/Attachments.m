//
//  Attachments.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 20/03/2014.
//
//

#import "CloudantReplicationBase.h"
#import "CloudantReplicationBase+CompareDb.h"

#import <UNIRest/UNIRest.h>
#import <XCTest/XCTest.h>
#import <CDTDatastore/CloudantSync.h>
#import <CDTDatastore/CloudantSyncEncryption.h>
#import <FMDB/FMDatabase.h>
#import <FMDB/FMDatabaseQueue.h>

#import <CDTDatastore/TDReplicator.h>
#import <CDTDatastore/TDPusher.h>
#import <CDTDatastore/TD_Database.h>

@interface CDTReplicator (test)
@property (nonatomic, strong) TDReplicator *tdReplicator;
@end

@interface TDPusher (test)
- (void)setSendAllDocumentsWithAttachmentsAsMultipart:(BOOL)value;
@end

@implementation TDPusher (test)
- (void)setSendAllDocumentsWithAttachmentsAsMultipart:(BOOL)value
{
	self->_sendAllDocumentsWithAttachmentsAsMultipart = value;
}
@end

@interface Attachments : CloudantReplicationBase
@property NSString *remoteDbName;
@end

@implementation Attachments

- (void)setUp
{
    [super setUp];

    // Create local and remote databases, start the replicator

    NSError *error;
    self.datastore =
        [self.factory datastoreNamed:@"test" withEncryptionKeyProvider:self.provider error:&error];
    XCTAssertNotNil(self.datastore, @"datastore is nil");

    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    
    self.remoteDbName = [NSString stringWithFormat:@"%@-test-database-%@",
                              self.remoteDbPrefix,
                              [CloudantReplicationBase generateRandomString:5]];
    NSURL *remoteDbURL = [self.remoteRootURL URLByAppendingPathComponent:self.remoteDbName];
    
    [self createRemoteDatabase:self.remoteDbName
                   instanceURL:self.remoteRootURL];
    self.primaryRemoteDatabaseURL = remoteDbURL;
}

- (void)tearDown
{
    // Tear-down code here.

    self.datastore = nil;

    self.replicatorFactory = nil;
    
    [self deleteRemoteDatabase:self.remoteDbName instanceURL:self.remoteRootURL];
    
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

- (void)deleteAttachmentNamed:(NSString*)attachmentName
                 fromDocument:(NSString*)docId
                   ofRevision:(NSString*)revId
                 fromDatabase:(NSURL*)remoteDbURL
{
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    headers[@"If-Match"] = revId;
    if(self.iamApiKey) {
        headers[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@",[self getIAMBearerToken]];
    }
    UNIHTTPJsonResponse* response = [[UNIRest delete:^(UNISimpleRequest* request) {
        NSURL *docURL = [remoteDbURL URLByAppendingPathComponent:docId];
        NSURL *attachmentURL = [docURL URLByAppendingPathComponent:attachmentName];
        [request setUrl:[attachmentURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    XCTAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db delete failed");
}

#pragma mark Tests
-(void)testSavedHttpAttachmentWithRemote
{
    //
    // Add attachments to a document in the local store
    //
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    
    NSError *error;
    
    NSString *docId = @"document1";
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:docId];
    rev.body = [@{ @"hello" : @12 } mutableCopy];

    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    NSString *content = @"blahblah";
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSString *name = @"attachment";
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:name
                                                                          type:@"text/plain"];
    [attachments setObject:attachment forKey:name];
    
    [originalAttachments setObject:data forKey:name];

    rev.attachments = attachments;
    rev = [self.datastore createDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:1],
                  @"Incorrect number of attachments");
    
    [self pushToRemote];

    rev.attachments = [@{} mutableCopy];
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev2, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev2 equalTo:0],
                  @"Incorrect number of attachments");
    
    
    //
    // Push to remote
    //
    
    [self pushToRemote];

    
    //check we can use the remote attachment class to get the attachments
    
    NSURL *docURL = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:docId];
    NSURLComponents *docURLComponents = [NSURLComponents componentsWithURL:docURL resolvingAgainstBaseURL:NO];
    docURLComponents.query = [NSString stringWithFormat:@"rev=%@",rev.revId];
    docURL = [docURLComponents URL];
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    if(self.iamApiKey) {
        headers[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@",[self getIAMBearerToken]];
    }
    UNIHTTPJsonResponse* response = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    
    

    
    //
    // Checks
    //
    
    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                  @"Local and remote database comparison failed");
    
    XCTAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore
                                                 withDatabase:self.primaryRemoteDatabaseURL],
                  @"Local and remote database attachment comparison failed");
    
    NSDictionary *responseDict = response.body.JSONObject;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CDTDocumentRevision *remoteRevision = [CDTDocumentRevision createRevisionFromJson:responseDict forDocument:docURL error:&error];
#pragma clang diagnostic pop

    XCTAssertNotNil(remoteRevision,@"Remote Revision was nil");
    XCTAssertEqual(remoteRevision.attachments.count, 1,@"Remote attachments were not equal to 1");

    CDTAttachment *remoteAttachment = remoteRevision.attachments.allValues[0];
    
    XCTAssertEqualObjects([@"blahblah" dataUsingEncoding:NSUTF8StringEncoding], [remoteAttachment dataFromAttachmentContent],@"Attachment content was not equal");
}


- (void)testReplicateSeveralRemoteDocumentsWithAttachments
{
    // { document ID: number of attachments to create }
    NSDictionary *docs = @{@"attachments1": @(1),
                           @"attachments3": @(3),
                           @"attachments4": @(4)};
    for (NSString* docId in [docs keyEnumerator]) {
        
        NSString *revId = [self createRemoteDocumentWithId:docId
                                    body:@{@"hello": @"world"}
                             databaseURL:self.primaryRemoteDatabaseURL];
        
        NSInteger nAttachments = [docs[docId] integerValue];
        for (NSInteger i = 1; i <= nAttachments; i++) {
            NSString *name = [NSString stringWithFormat:@"txtDoc%li", (long)i];
            NSData *txtData = [@"0123456789" dataUsingEncoding:NSUTF8StringEncoding];
            revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                        revId:revId
                                               attachmentName:name
                                                  contentType:@"text/plain"
                                                         data:txtData
                                                  databaseURL:self.primaryRemoteDatabaseURL];
        }
    }
    
    //
    // Replicate
    //
    
    [self pullFromRemote];
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev;
    
    rev = [self.datastore getDocumentWithId:@"attachments1"
                                      error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)1],
                 @"Incorrect number of attachments");
    
    rev = [self.datastore getDocumentWithId:@"attachments3"
                                      error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)3],
                 @"Incorrect number of attachments");
    
    rev = [self.datastore getDocumentWithId:@"attachments4"
                                      error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)4],
                 @"Incorrect number of attachments");
}

- (void)testReplicateManyLocalAttachments
{
    NSUInteger nAttachments = 100;
    
    //
    // Add attachments to a document in the local store
    //
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
        
    NSError *error;
    
    NSString *docId = @"document1";
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:docId];
    rev.body = [@{ @"hello" : @12 } mutableCopy];

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

    rev.attachments = attachments;
    rev = [self.datastore createDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    // 
    // Push to remote
    // 
    
    [self pushToRemote];
    
    //
    // Checks
    //
    
    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database comparison failed");
    
    XCTAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database attachment comparison failed");
}

- (void)testReplicateMultipartAttachments
{
    NSUInteger nAttachments = 10;

    //
    // Add attachments to a document in the local store
    //

    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];

    NSError *error;

    NSString *docId = @"document1";
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:docId];
    rev.body = [@{ @"hello" : @12 } mutableCopy];

    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    for (NSInteger i = 1; i <= nAttachments; i++) {
        NSString *content = [NSString stringWithFormat:@"blahblah-%li", (long)i];
        NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];

        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        CDTAttachment *attachment =
            [[CDTUnsavedDataAttachment alloc] initWithData:data name:name type:@"text/plain"];
        [attachments setObject:attachment forKey:name];

        [originalAttachments setObject:data forKey:name];
    }

    rev.attachments = attachments;
    rev = [self.datastore createDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                  @"Incorrect number of attachments");

    //
    // Push to remote
    //

    CDTReplicator *replicator =
        [self.replicatorFactory onewaySourceDatastore:self.datastore targetURI:self.primaryRemoteDatabaseURL];

    [replicator addObserver:self
                 forKeyPath:@"tdReplicator"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];

    [replicator startWithError:nil];

    // Time out test after 120 seconds
    NSDate *start = [NSDate date];
    while (replicator.isActive && ([[NSDate date] timeIntervalSinceDate:start] < 120)) {
        [NSThread sleepForTimeInterval:1.0f];
    }

    if (replicator.isActive) {
        XCTFail(@"Test timed out");
    }

    [replicator removeObserver:self forKeyPath:@"tdReplicator"];

    //
    // Checks
    //

    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                  @"Local and remote database comparison failed");

    XCTAssertTrue(
        [self compareAttachmentsForCurrentRevisions:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
        @"Local and remote database attachment comparison failed");

}

/* This is a little hacky, but it was the easiest way I could find to force a multipart upload. */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqual:@"tdReplicator"]) {
        CDTReplicator *replicator = (CDTReplicator *)object;
        TDPusher *pusher = (TDPusher *)replicator.tdReplicator;
        [pusher setSendAllDocumentsWithAttachmentsAsMultipart:YES];
    }
}

/**
 Test that deleting attachments locally is replicated to a
 remote database.
 */
- (void)testAddLocalReplicateDeleteLocalReplicate
{
    NSUInteger nAttachments = 100;
    
    //
    // Add attachments to a document in the local store
    //
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    // { document ID: number of attachments to create }
    NSString *docId = @"document1";
    
    NSError *error;
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:docId];
    rev.body = [@{ @"hello" : @12 } mutableCopy];

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

    rev.attachments = attachments;
    rev = [self.datastore createDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    // 
    // Push to remote
    // 
    
    [self pushToRemote];
    
    //
    // Delete some attachments, then replicate to check the changes
    // replicate successfully.
    //
    
    for (int i = 1; i < nAttachments; i+=2) {  // every second att
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        [attachments removeObjectForKey:name];
    }
    rev.attachments = attachments;

    rev = [self.datastore updateDocumentFromRevision:rev error:nil];

    XCTAssertNotNil(rev, @"Attachments are not deleted.");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments/2],
                 @"Incorrect number of attachments");
    
    [self pushToRemote];
    
    //
    // Checks
    //
    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database comparison failed");
    
    XCTAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database attachment comparison failed");
}

/**
 Test that deleting attachments locally is replicated to a
 remote database.
 */
- (void)testAddLocalReplicateDeleteLocalReplicate412Retry
{
    NSUInteger nAttachments = 2;
    
    //
    // Add attachments to a document in the local store
    //
    
    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    // { document ID: number of attachments to create }
    NSString *docId = @"document1";
    
    NSError *error;
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:docId];
    rev.body = [@{ @"hello" : @12 } mutableCopy];

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

    rev.attachments = attachments;
    rev = [self.datastore createDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    // 
    // Push to remote
    // 
    
    [self pushToRemote];
    
    //
    // Delete some attachments, then replicate to check the changes
    // replicate successfully.
    //
    
    for (int i = 1; i < nAttachments; i+=2) {  // every second att
        NSString *name = [NSString stringWithFormat:@"attachment-%li", (long)i];
        [attachments removeObjectForKey:name];
    }
    rev.attachments = attachments;

    rev = [self.datastore updateDocumentFromRevision:rev error:nil];

    XCTAssertNotNil(rev, @"Attachments are not deleted.");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments/2],
                 @"Incorrect number of attachments");
    
    // To get the 412 response to happen, we have to change the revpos in the attachments
    // table for the remaining attachment.
    
    [self.datastore.database.fmdbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql = @"UPDATE attachments SET revpos=1 WHERE filename='attachment-2'";
        [db executeUpdate:sql];
    }];
    
    [self pushToRemote];
    
    //
    // Checks
    //
    
    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database comparison failed");
    
    XCTAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database attachment comparison failed");
}


- (void)testReplicateManyRemoteAttachments
{
    NSUInteger nAttachments = 100;

    // Contains {attachmentName: attachmentContent} for later checking
    NSMutableDictionary *originalAttachments = [NSMutableDictionary dictionary];
    
    
    //
    // Upload attachments to remote document
    //
    
    NSString *docId = @"document1";
        
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:self.primaryRemoteDatabaseURL];
    
    for (NSInteger i = 1; i <= nAttachments; i++) {
        NSString *name = [NSString stringWithFormat:@"txtDoc%li", (long)i];
        NSString *content = [NSString stringWithFormat:@"doc%li", (long)i];
        NSData *txtData = [content dataUsingEncoding:NSUTF8StringEncoding];
        revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                    revId:revId
                                           attachmentName:name
                                              contentType:@"text/plain"
                                                     data:txtData
                                              databaseURL:self.primaryRemoteDatabaseURL];
        originalAttachments[name] = txtData;
    }
    
    //
    // Replicate
    //
    
    [self pullFromRemote];
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev;
    rev = [self.datastore getDocumentWithId:docId
                                      error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:nAttachments],
                 @"Incorrect number of attachments");
    
    for (NSString *attachmentName in [originalAttachments keyEnumerator]) {

        CDTAttachment *a = [[rev attachments] objectForKey:attachmentName];
        
        XCTAssertNotNil(a, @"No attachment named %@", attachmentName);
        
        NSData *data = [a dataFromAttachmentContent];
        NSData *originalData = originalAttachments[attachmentName];
        
        XCTAssertEqualObjects(data, originalData, @"attachment content didn't match");
    }
}

/**
 Test that updates to an attachment are replicated correctly.
 */
- (void)testReplicateRemoteDocumentUpdate
{
    NSString *docId = @"attachments1";
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:self.primaryRemoteDatabaseURL];
    
    NSString *attachmentName = @"attachment-1";
    NSString *originalContent = @"originalContent";
    NSData *txtData = [originalContent dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:attachmentName
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:self.primaryRemoteDatabaseURL];
    
    //
    // Replicate
    //
    
    [self pullFromRemote];
    
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
    [rev.attachments setObject:attachment forKey:attachmentName];
    rev = [self.datastore updateDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    
    [self pushToRemote];
    
    //
    // Checks
    //
    
    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database comparison failed");
    
    XCTAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database attachment comparison failed");
}

/**
 Test that deleting an attachment locally is replicated correctly.
 */
- (void)testReplicateRemoteDocumentDeleteLocalCheckReplicated
{
    NSString *docId = @"attachments1";
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:self.primaryRemoteDatabaseURL];
    NSString *attachmentName = @"attachment-1";
    NSString *originalContent = @"an-attachment";
    NSData *txtData = [originalContent dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:attachmentName
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:self.primaryRemoteDatabaseURL];
    
    //
    // Replicate
    //
    
    [self pullFromRemote];
    
    //
    // Delete the local attachment, replicate, check deleted remotely
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    [rev.attachments removeObjectForKey:attachmentName];
    rev = [self.datastore updateDocumentFromRevision:rev error:nil];

    XCTAssertNotNil(rev, @"Unable to add attachments to document");
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)0],
                 @"Incorrect number of attachments");
    
    
    [self pushToRemote];
    
    //
    // Checks
    //
    
    XCTAssertTrue([self compareDatastore:self.datastore withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database comparison failed");
    XCTAssertTrue([self compareAttachmentsForCurrentRevisions:self.datastore 
                                                withDatabase:self.primaryRemoteDatabaseURL],
                 @"Local and remote database attachment comparison failed");
}

/**
 Test that deleting an attachment remotely is replicated correctly.
 */
- (void)testReplicateRemoteDocumentDeleteRemoteCheckReplicated
{
    NSString *docId = @"attachments1";
    NSString *revId = [self createRemoteDocumentWithId:docId
                                                  body:@{@"hello": @"world"}
                                           databaseURL:self.primaryRemoteDatabaseURL];
    NSString *attachmentName = @"attachment-1";
    NSString *originalContent = @"an-attachment";
    NSData *txtData = [originalContent dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:attachmentName
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:self.primaryRemoteDatabaseURL];
    
    //
    // Replicate
    //
    
    [self pullFromRemote];
    
    //
    // Delete the remote attachment, replicate, check deleted locally
    //
    
    [self deleteAttachmentNamed:attachmentName
                   fromDocument:docId
                     ofRevision:revId
                   fromDatabase:self.primaryRemoteDatabaseURL];
    
    [self pullFromRemote];
    
    //
    // Checks
    //
    
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docId
                                                           error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)0],
                 @"Incorrect number of attachments");
}

/** 
 Regression test for issue at:
 
 https://github.com/couchbase/couchbase-lite-ios/commit/b5ecc07c8688a5d834992a51a23cd99faf8be0db
 */
- (void)testRevposIssueFixed
{
    //
    // Create document
    //
    
    NSString *docId = @"attachment_doc_1";
    NSString *revId;
    NSDictionary *dict = @{@"hello": @"world"};
    
    revId = [self createRemoteDocumentWithId:docId
                                        body:dict
                                 databaseURL:self.primaryRemoteDatabaseURL];
    
    //
    // Create new rev with attachment
    //
    
    NSData *txtData = [@"0123456789" dataUsingEncoding:NSUTF8StringEncoding];
    revId = [self addAttachmentToRemoteDocumentWithId:docId
                                                revId:revId
                                       attachmentName:@"txtDoc"
                                          contentType:@"text/plain"
                                                 data:txtData
                                          databaseURL:self.primaryRemoteDatabaseURL];
    
    //
    // Issue HTTP COPY w/ Destination header to copy
    //
    NSString *copiedDocId = @"copied-document";
    NSURL *copiedDocURL = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:copiedDocId];
    
    [self copyRemoteDocumentWithId:docId
                              toId:copiedDocId
                       databaseURL:self.primaryRemoteDatabaseURL];
    
    
    // Should end up with revpos > generation number
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    if(self.iamApiKey) {
        headers[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@",[self getIAMBearerToken]];
    }
    NSDictionary* json = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[copiedDocURL absoluteString]];
        [request setHeaders:headers];
    }] asJson].body.object;
    
    // The regression this tests for is triggered by the attachment's revpos being
    // greater than the generation of the revision.
    XCTAssertEqualObjects(json[@"_attachments"][@"txtDoc"][@"revpos"], 
                         @(2), 
                         @"revpos not expected");
    XCTAssertTrue([json[@"_rev"] hasPrefix:@"1"], @"revpos not expected");
    
    //
    // Replicate to local database
    //
    
    [self pullFromRemote];
    
    //
    // Check both documents are okay
    //
    
    CDTDocumentRevision *rev;
    
    rev = [self.datastore getDocumentWithId:docId
                                      error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)1],
                 @"Incorrect number of attachments");
    
    rev = [self.datastore getDocumentWithId:copiedDocId
                                      error:nil];
    XCTAssertTrue([self isNumberOfAttachmentsForRevision:rev equalTo:(NSUInteger)1],
                 @"Incorrect number of attachments");
}

@end
