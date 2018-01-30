//
//  CloudantReplicationBase.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import "CloudantReplicationBase.h"

#import <CDTDatastore/CloudantSync.h>
#import <CDTDatastore/CloudantSyncEncryption.h>

#import "ReplicationSettings.h"

#import <UNIRest/UNIRest.h>

@implementation CloudantReplicationBase

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.

    self.factoryPath = [self createTemporaryDirectoryAndReturnPath];

    NSError *error;
    self.factory = [[CDTDatastoreManager alloc] initWithDirectory:self.factoryPath error:&error];

    XCTAssertNil(error, @"CDTDatastoreManager had error");
    XCTAssertNotNil(self.factory, @"Factory is nil");

    ReplicationSettings *settings = [[ReplicationSettings alloc] init];
    self.remoteRootURL = [NSURL URLWithString:settings.serverURI];
    
    // Configure BasicAuth header for UNIRest requests
    if(settings.iamApiKey) {
        [UNIRest clearDefaultHeaders];
        self.iamApiKey = settings.iamApiKey;
        [UNIRest defaultHeader:@"Authorization"
                         value:[NSString stringWithFormat:@"Bearer %@",[self getIAMBearerToken]]];
    } else {
        if (settings.authorization != nil) {
            [UNIRest defaultHeader:@"Authorization" value: settings.authorization];
        }
    }
    
#ifdef USE_ENCRYPTION
    self.remoteDbPrefix = @"replication-acceptance-with-encryption";
    
    char buffer[CDTENCRYPTIONKEY_KEYSIZE];
    memset(buffer, '*', sizeof(buffer));
    NSData *key = [NSData dataWithBytes:buffer length:sizeof(buffer)];
    
    self.provider = [CDTEncryptionKeySimpleProvider providerWithKey:key];
#else
    self.remoteDbPrefix = @"replication-acceptance";
    
    self.provider = [CDTEncryptionKeyNilProvider provider];
#endif
    
}

- (void)tearDown
{
    self.provider = nil;
    
    self.factory = nil;

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:self.factoryPath error:&error];
    XCTAssertNil(error, @"Error deleting temporary directory.");

    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

#pragma mark Setup helpers

+(NSString*)generateRandomString:(int)num {
    NSMutableString* string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}

- (NSString*)createTemporaryDirectoryAndReturnPath
{
#ifdef USE_ENCRYPTION
    NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"cloudant_sync_ios_tests_with_encryption.XXXXXX"];
#else
    NSString *tempDirectoryTemplate =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
#endif
    const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString =  (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
    
    char *result = mkdtemp(tempDirectoryNameCString);
    if (!result)
    {
        XCTFail(@"Couldn't create temporary directory");
    }
    
    NSString *path = [[NSFileManager defaultManager]
                      stringWithFileSystemRepresentation:tempDirectoryNameCString
                      length:strlen(result)];
    free(tempDirectoryNameCString);
    
    NSLog(@"Database path: %@", path);
    
    return path;
}

/**
 Get the IAM access token.  Used for CRUD helper methods.
 */
-(NSString *) getIAMBearerToken {
    NSDictionary* headers = @{@"accept": @"application/json"};
    NSDictionary* parameters = @{@"grant_type": @"urn:ibm:params:oauth:grant-type:apikey",
                                 @"response_type": @"cloud_iam",
                                 @"apikey": self.iamApiKey};
    
    // Get IAM access token
    UNIHTTPJsonResponse* iamKeyResponse = [[UNIRest post:^(UNISimpleRequest *request) {
        [request setUrl:@"https://iam.bluemix.net/identity/token"];
        [request setHeaders:headers];
        [request setParameters:parameters];
    }] asJson];
    
    XCTAssertNotNil([iamKeyResponse.body.object objectForKey:@"access_token"]);
    return [iamKeyResponse.body.object objectForKey:@"access_token"];
}

#pragma mark Remote database operations

/**
 Create a remote database.
 */
-(void) createRemoteDatabase:(NSString*)name
                 instanceURL:(NSURL*)instanceURL
{
    NSURL *remoteDatabaseURL = [instanceURL URLByAppendingPathComponent:name];
    
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
    [request setUrl:[remoteDatabaseURL absoluteString]];
    [request setHeaders:headers];
    [request setBody:[NSData data]];
    }] asJson];
    
    XCTAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db create failed");
}

/**
 Delete a remote database.
 */
-(void) deleteRemoteDatabase:(NSString*)name
                 instanceURL:(NSURL*)instanceURL
{
    NSURL *remoteDatabaseURL = [instanceURL URLByAppendingPathComponent:name];
    
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    UNIHTTPJsonResponse* response = [[UNIRest delete:^(UNISimpleRequest* request) {
        [request setUrl:[remoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson];
    XCTAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Remote db delete failed");
}


/**
 Create a remote document with a given ID, returning the revId
 */
- (NSString*)createRemoteDocumentWithId:(NSString*)docId
                                   body:(NSDictionary*)body
                            databaseURL:(NSURL*)dbUrl
{
    NSURL *docURL = [dbUrl URLByAppendingPathComponent:docId];
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    headers[@"content-type"] = @"application/json";
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSJSONSerialization dataWithJSONObject:body
                                                         options:0
                                                           error:nil]];
    }] asJson];
    XCTAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Create document failed");
    NSString *revId = [response.body.object objectForKey:@"rev"];
    return revId;
}

/**
 Add an attachment to a document with a given ID, returning the revId
 */
- (NSString*)addAttachmentToRemoteDocumentWithId:(NSString*)docId
                                           revId:(NSString*)revId
                                  attachmentName:(NSString*)attachmentName
                                     contentType:(NSString*)contentType
                                            data:(NSData*)data
                                     databaseURL:(NSURL*)dbUrl
{
    NSURL *docURL = [dbUrl URLByAppendingPathComponent:docId];
    NSString *contentLength = [NSString stringWithFormat:@"%lu", (unsigned long)data.length];
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    headers[@"content-type"] = contentType;
    headers[@"If-Match"] = revId;
    headers[@"Content-Length"] = contentLength;
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        NSURL *attachmentURL = [docURL URLByAppendingPathComponent:attachmentName];
        [request setUrl:[attachmentURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:data];
    }] asJson];
    XCTAssertTrue([response.body.object objectForKey:@"rev"] != nil, @"Adding attachment failed");
    NSString *newRevId = [response.body.object objectForKey:@"rev"];
    return newRevId;
}

/**
 Copy a remote document using HTTP COPY.
 */
- (NSString*)copyRemoteDocumentWithId:(NSString*)fromId
                                 toId:(NSString*)toId
                          databaseURL:(NSURL*)dbUrl
{
    NSURL *docURL = [dbUrl URLByAppendingPathComponent:fromId];
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    headers[@"accept"] = @"application/json";
    headers[@"content-type"] = @"application/json";
    headers[@"Destination"] = toId;
    UNIHTTPJsonResponse* response;
    response = [[[UNIHTTPRequestWithBody alloc] initWithSimpleRequest:COPY
                                                                  url:[docURL absoluteString] 
                                                              headers:headers
                                                             username:nil 
                                                             password:nil] asJson];
    XCTAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Copy document failed");
    NSString *revId = [response.body.object objectForKey:@"rev"];
    return revId;
}


/**
 Create a new replicator, and wait for replication from the remote database to complete.
 */
-(CDTReplicator *) pullFromRemote {
    return [self pullFromRemoteWithFilter:nil params:nil];
}

-(CDTReplicator *) pullFromRemoteWithFilter:(NSString*)filterName params:(NSDictionary*)params
{
    
    CDTReplicator *replicator;
    int n = 10; // how many times to try replicating
    
    do {
        CDTPullReplication *pull = nil;
        if([self.iamApiKey length] != 0) {
            pull = [CDTPullReplication replicationWithSource:self.primaryRemoteDatabaseURL
                                                      target:self.datastore
                                                   IAMAPIKey:self.iamApiKey];
        } else {
            pull = [CDTPullReplication replicationWithSource:self.primaryRemoteDatabaseURL
                                                      target:self.datastore];
        }
        pull.filter = filterName;
        pull.filterParams = params;
        
        NSError *error;
        replicator =  [self.replicatorFactory oneWay:pull error:&error];
        XCTAssertNil(error, @"%@",error);
        XCTAssertNotNil(replicator, @"CDTReplicator is nil");
        NSLog(@"Replicating from %@", [pull.source absoluteString]);
        if (![replicator startWithError:&error]) {
            XCTFail(@"CDTReplicator -startWithError: %@", error);
        }
        while (replicator.isActive) {
            [NSThread sleepForTimeInterval:1.0f];
            NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
        }
        NSLog(@"*** Replicator ended with error = %@", replicator.error);
    } while (replicator.error != nil && n-- > 0);

    return replicator;
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
    
    CDTReplicator *replicator;
    int n = 10; // how many times to try replicating

    do {
        CDTPushReplication *push = nil;
        if([self.iamApiKey length] != 0) {
            push = [CDTPushReplication replicationWithSource:self.datastore
                                                      target:self.primaryRemoteDatabaseURL
                                                   IAMAPIKey:self.iamApiKey];
        } else {
            push = [CDTPushReplication replicationWithSource:self.datastore
                                                      target:self.primaryRemoteDatabaseURL];
        }
        
        push.filter = filter;
        push.filterParams = params;
        
        NSError *error;
        replicator =  [self.replicatorFactory oneWay:push error:&error];
        XCTAssertNil(error, @"%@",error);
        XCTAssertNotNil(replicator, @"CDTReplicator is nil");

        NSLog(@"Replicating to %@", [self.primaryRemoteDatabaseURL absoluteString]);
        if (![replicator startWithError:&error]) {
            XCTFail(@"CDTReplicator -startWithError: %@", error);
        }
        while (replicator.isActive) {
            
            [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                     beforeDate: [NSDate dateWithTimeIntervalSinceNow:1.0]];
            NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
        }
        NSLog(@"*** Replicator ended with error = %@", replicator.error);
    } while (replicator.error != nil && n-- > 0);

    return replicator;
}


@end
