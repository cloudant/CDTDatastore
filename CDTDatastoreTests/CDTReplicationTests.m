//
//  CDTReplicationTests.m
//  Tests
//
//  Created by Adam Cox on 4/14/14.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>
#import "CDTPullReplication.h"
#import "CDTPushReplication.h"
#import "CloudantSyncTests.h"
#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTReplicatorFactory.h"
#import "CDTReplicator.h"
#import "TDReplicatorManager.h"
#import "CDTDocumentRevision.h"
#import "TD_Body.h"
#import "TD_Revision.h"
#import "TDPuller.h"
#import "TDPusher.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import <OCMock/OCMock.h>
#import <netinet/in.h>

@interface ChangesFeedRequestCheckInterceptor : NSObject <CDTHTTPInterceptor>

@property (nonatomic) BOOL changesFeedRequestMade;

@end

@implementation ChangesFeedRequestCheckInterceptor

- (instancetype)init
{
    self = [super init];
    if (self) {
        _changesFeedRequestMade = NO;
    }
    return self;
}

- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    // determines if the interceptor was run before request
    NSURL *url = context.request.URL;

    if ([[url path] containsString:@"/_changes"]) {
        self.changesFeedRequestMade = YES;
    }

    return context;
}

@end

@interface CDTReplicationTests : CloudantSyncTests

@property int listenSocketFd;

@end

@implementation CDTReplicationTests

// Start a simple HTTP server on localhost that responds to any message with a "404 Not Found".
- (void)startSimpleHttp404Server {
    self.listenSocketFd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    const int buf_size = 1024;

    struct sockaddr_in serv_addr;
    memset(&serv_addr, '0', sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(8080);
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    bind(self.listenSocketFd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    listen(self.listenSocketFd, 10);

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        bool stopped = false;
        while (!stopped)
        {
            __block int connfd = accept(self.listenSocketFd, (struct sockaddr*)NULL, NULL);
            if (connfd > 0) {
                char buffer[buf_size];
                bzero(buffer, buf_size);

                // Receive a message.
                recv(connfd, buffer, buf_size, 0);

                // We don't care what the message was (or if we read it all), just send back a 404.
                char* header = "HTTP/1.0 404 Not Found\n";
                write(connfd, header, strlen(header));
                close(connfd);
            } else {
                stopped = true;
            }
        }
    });
}

- (void)stopSimpleHttp404Server {
    close(self.listenSocketFd);
}

- (void)testFiltersWithChangesFeed
{
    NSError *error;
    // We need a real remote here, so the reachability test before the replication starts
    // passes, it doesn't need a couch server, since the NSURLProtocol will 404 any request.
    // We can't use OHHTTPStubs to stub the server as that doesn't work with background
    // requests, so we just start a simple local server that returns 404 to anything it receives
    // and use that for our remote.
    [self startSimpleHttp404Server];
    NSString *remoteUrl = @"http://127.0.0.1:8080";

    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPullReplication *pull =
        [CDTPullReplication replicationWithSource:[NSURL URLWithString:remoteUrl] target:tmp];
    ChangesFeedRequestCheckInterceptor *interceptor =
        [[ChangesFeedRequestCheckInterceptor alloc] init];
    [pull addInterceptor:interceptor];
    CDTReplicatorFactory *replicatorFactory =
        [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];

    CDTReplicator *replicator = [replicatorFactory oneWay:pull error:&error];

    dispatch_group_t taskGroup = dispatch_group_create();
    [replicator startWithTaskGroup:taskGroup error:&error];

    dispatch_group_wait(taskGroup, DISPATCH_TIME_FOREVER);

    XCTAssertTrue(interceptor.changesFeedRequestMade);

    [self stopSimpleHttp404Server];
}

-(void)testReplicatorIsNilForNilDatastoreManager {
    
    XCTAssertNil([[CDTReplicatorFactory alloc] initWithDatastoreManager:nil], @"Replication factory should be nil");
    
}

-(void)testDictionaryForPullReplicationDocument
{
    NSString *remoteUrl = @"https://adam:cox@myaccount.cloudant.com/mydb";
    NSDictionary *expectedDictionary = @{
        @"target" : @"test_database",
        @"source" : remoteUrl,
        @"filter" : @"myddoc/myfilter",
        @"query_params" : @{@"min" : @23, @"max" : @43},
        @"interceptors" : @[]
    };

    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:[NSURL URLWithString:remoteUrl]
                                                                  target:tmp];
    
    pull.filter = @"myddoc/myfilter";
    pull.filterParams = @{@"min":@23, @"max":@43};
    
    error = nil;
    NSDictionary *pullDict = [pull dictionaryForReplicatorDocument:&error];
    XCTAssertNil(error, @"Error creating dictionary. %@. Replicator: %@", error, pull);
    XCTAssertEqualObjects(pullDict, expectedDictionary, @"pull dictionary: %@", pullDict);
    
    //ensure that TDReplicatorManager makes the appropriate TDPuller object
    //The code to do this, seems, a bit precarious and this guards against any future
    //changes that could affect this process.
    error = nil;
    TDReplicatorManager *replicatorManager = [[TDReplicatorManager alloc]
                                              initWithDatabaseManager:self.factory.manager];
    TDReplicator *tdreplicator = [replicatorManager createReplicatorWithProperties:pullDict
                                                                             error:&error];
    XCTAssertEqualObjects([tdreplicator class], [TDPuller class], @"Wrong Type of TDReplicator. %@", error);
}

-(void)testDictionaryForPushReplicationDocument
{
    NSString *remoteUrl = @"https://adam:cox@myaccount.cloudant.com/mydb";
    NSDictionary *expectedDictionary =
        @{ @"source" : @"test_database",
           @"target" : remoteUrl,
           @"interceptors" : @[] };

    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:tmp
                                                                  target:[NSURL URLWithString:remoteUrl]];

    
    error = nil;
    NSDictionary *pushDict = [push dictionaryForReplicatorDocument:&error];
    XCTAssertNil(error, @"Error creating dictionary. %@. Replicator: %@", error, push);
    XCTAssertEqualObjects(pushDict, expectedDictionary, @"push dictionary: %@", pushDict);
    
    //ensure that TDReplicatorManager makes the appropriate TDPuller object
    //The code to do this, seems, a bit precarious and this guards against any future
    //changes that could affect this process.
    error = nil;
    TDReplicatorManager *replicatorManager = [[TDReplicatorManager alloc]
                                              initWithDatabaseManager:self.factory.manager];
    TDReplicator *tdreplicator = [replicatorManager createReplicatorWithProperties:pushDict
                                                                             error:&error];
    XCTAssertEqualObjects([tdreplicator class], [TDPusher class], @"Wrong Type of TDReplicator. %@", error);
}


-(void)testCreatePushReplicationWithFilter
{
    NSString *remoteUrl = @"https://adam:cox@myaccount.cloudant.com/mydb";
    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:tmp
                                                                  target:[NSURL URLWithString:remoteUrl]];
    
    CDTFilterBlock aFilter = ^BOOL(CDTDocumentRevision *rev, NSDictionary *params) {
        return YES;
    };
    
    push.filter = aFilter;
    push.filterParams = @{@"param1":@"foo"};
    
    CDTReplicatorFactory *replicatorFactory = [[CDTReplicatorFactory alloc]
                                               initWithDatastoreManager:self.factory];
    
    error = nil;
    CDTReplicator *replicator =  [replicatorFactory oneWay:push error:&error];
    XCTAssertNotNil(replicator, @"%@", push);
    XCTAssertNil(error, @"%@", error);

    NSDictionary *pushDoc = [push dictionaryForReplicatorDocument:nil];
    
    XCTAssertTrue(push.filter != nil, @"No filter set in CDTPushReplication");
    XCTAssertEqualObjects(@{@"param1":@"foo"}, pushDoc[@"query_params"], @"\n%@", pushDoc);
    
    //ensure that TDReplicatorManager makes the appropriate TDPuller object
    //The code to do this, seems, a bit precarious and this guards against any future
    //changes that could affect this process.
    error = nil;
    TDReplicatorManager *replicatorManager = [[TDReplicatorManager alloc]
                                              initWithDatabaseManager:self.factory.manager];
    TDReplicator *tdreplicator = [replicatorManager createReplicatorWithProperties:pushDoc
                                                                             error:&error];
    XCTAssertEqualObjects([tdreplicator class], [TDPusher class], @"Wrong Type of TDReplicator. %@", error);
}

-(CDTAbstractReplication *)buildReplicationObject:(Class)aClass remoteUrl:(NSURL *)url
{
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:nil];
    
    //this feels wrong...
    if (aClass == [CDTPushReplication class]) {
        
        return [CDTPushReplication replicationWithSource:tmp target:url];
    
    } else if (aClass == [CDTPullReplication class]) {
    
        return [CDTPullReplication replicationWithSource:url target:tmp];
    
    } else {
        
        return nil;
    }
}

-(void)urlTestExpectTrue:(Class)prClass
                     url:(NSURL*)url
{
    CDTAbstractReplication *pr = [self buildReplicationObject:prClass remoteUrl:url];
    NSError *error = nil;
    XCTAssertTrue([pr validateRemoteDatastoreURL:url error:&error], @"\nerror: %@ \nurl: %@", error, url);
}

-(void)urlTestExpectFalse:(Class)prClass
                      url:(NSURL*)url
            withErrorCode:(NSInteger)code
{
    NSError *error = nil;
    CDTAbstractReplication *pr = [self buildReplicationObject:prClass remoteUrl:url];
    
    XCTAssertFalse([pr validateRemoteDatastoreURL:url error:&error], @"\nerror: %@ \nurl: %@", error, url);
    XCTAssertTrue(error.code == code, @"\nerror: %@  \nurl: %@", error, url);
}

-(void)runUrlTestFor:(Class)prClass
{

    //expect to pass
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://myaccount.cloudant.com/foo"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://adam:pass@myaccount.cloudant.com/foo"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"http://adam:pass@myaccount.cloudant.com/foo"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"http://adam:pass@myaccount.cloudant.com:5000/foo"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"http://myaccount.cloudant.com:5000/foo"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://myaccount.cloudant.com:5000/foo"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://myaccount.cloudant.com/foo%2Fbar%2Fbam"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://myaccount.cloudant.com:5000/foo%2Fbar%2Fbam"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://adam:pass@myaccount.cloudant.com:5000/foo%2Fbar%2Fbam"]];
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"http://adam:pass@myaccount.cloudant.com:5000/foo%2Fbar%2Fbam"]];
    
    //even though this path shouldn't exist in normal situations, we can't restrict the URL because
    //it could be a CNAME record or other type of redirect.
    [self urlTestExpectTrue:prClass
                        url:[NSURL URLWithString:@"https://someurl.com/foo/bar/bam"]];
    
    //build a URL with NSURLComponents
    NSURLComponents *urlc = [[NSURLComponents alloc] init];
    urlc.scheme = @"https";
    urlc.host = @"myaccount.cloudant.com";
    urlc.percentEncodedPath = @"/foo%2Fbar%2Fbam";
    [self urlTestExpectTrue:prClass  url:[urlc URL]];
    
    urlc.user = @"adam";
    [self urlTestExpectFalse:prClass
                         url:[urlc URL]
               withErrorCode:CDTReplicationErrorIncompleteCredentials];
    
    urlc.user = nil;
    urlc.password = @"password";
    [self urlTestExpectFalse:prClass
                         url:[urlc URL]
               withErrorCode:CDTReplicationErrorIncompleteCredentials];
    
    urlc.user = @"adam";
    [self urlTestExpectTrue:prClass url:[urlc URL]];
    
    //expect to fail
    [self urlTestExpectFalse:prClass
                         url:[NSURL URLWithString:@"ftp://myaccount.cloudant.com/foo"]
               withErrorCode:CDTReplicationErrorInvalidScheme];
    
    [self urlTestExpectFalse:prClass
                         url:[NSURL URLWithString:@"ftp://myaccount.cloudant.com/foo/bar"]
               withErrorCode:CDTReplicationErrorInvalidScheme];
    
    [self urlTestExpectFalse:prClass
                         url:[NSURL URLWithString:@"https://adam@myaccount.cloudant.com/foo"]
               withErrorCode:CDTReplicationErrorIncompleteCredentials];
    
    [self urlTestExpectFalse:prClass
                         url:[NSURL URLWithString:@"https://:password@myaccount.cloudant.com/foo"]
               withErrorCode:CDTReplicationErrorIncompleteCredentials];
    
}

-(void)testRemoteURL
{

    //tests for the pull replication class
    [self runUrlTestFor:[CDTPullReplication class]];
    
    [self urlTestExpectFalse:[CDTPullReplication class]
                         url:nil
               withErrorCode:CDTReplicationErrorUndefinedSource];

    
    //tests for the push replication class
    [self runUrlTestFor:[CDTPushReplication class]];

    [self urlTestExpectFalse:[CDTPushReplication class]
                         url:nil
               withErrorCode:CDTReplicationErrorUndefinedTarget];
    
}

-(void) testStateAfterStoppingBeforeStarting
{
    NSString *remoteUrl = @"https://adam:cox@myaccount.cloudant.com/mydb";
    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:tmp
                                                                  target:[NSURL URLWithString:remoteUrl]];
 
    
    CDTReplicatorFactory *replicatorFactory = [[CDTReplicatorFactory alloc]
                                               initWithDatastoreManager:self.factory];
    
    error = nil;
    CDTReplicator *replicator =  [replicatorFactory oneWay:push error:&error];
    XCTAssertNotNil(replicator, @"%@", push);
    XCTAssertNil(error, @"%@", error);
    
    XCTAssertEqual(replicator.state, CDTReplicatorStatePending, @"Unexpected state: %@",
                   [CDTReplicator stringForReplicatorState:replicator.state ]);
    
    [replicator stop];
    
    XCTAssertEqual(replicator.state, CDTReplicatorStateStopped, @"Unexpected state: %@",
                   [CDTReplicator stringForReplicatorState:replicator.state ]);
    
}

-(CDTPullReplication*)createPullReplicationWithHeaders:(NSDictionary *)optionalHeaders
{
    NSString *remoteUrl = @"https://adam:cox@myaccount.cloudant.com/mydb";
    
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:nil];
    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:[NSURL URLWithString:remoteUrl]
                                                                  target:tmp];
    
    pull.optionalHeaders = optionalHeaders;

    return pull;
}

-(void)testForProhibitedOptionalReplicationHeaders
{
    CDTPullReplication *pull;
    NSError *error;
    NSDictionary *pullDoc;
    NSDictionary *optionalHeaders;
    
    optionalHeaders = @{@"User-Agent": @"My Agent"};
    pull = [self createPullReplicationWithHeaders:optionalHeaders];
    error = nil;
    pullDoc = [pull dictionaryForReplicatorDocument:&error];
    XCTAssertNotNil(pullDoc, @"CDTPullReplication -dictionaryForReplicatorDocument failed with "
                   @"header: %@", optionalHeaders);
    
    XCTAssertTrue([pullDoc[@"headers"][@"User-Agent"] isEqualToString:@"My Agent"],
                 @"Bad headers: %@", pullDoc[@"headers"]);
    
    
    NSArray *prohibitedUpperArray = @[@"Authorization", @"WWW-Authenticate", @"Host",
                                  @"Connection", @"Content-Type", @"Accept",
                                  @"Content-Length"];
    
    NSMutableArray *prohibitedLowerArray = [[NSMutableArray alloc] init];
    
    for (NSString *header in prohibitedUpperArray) {
        [prohibitedLowerArray addObject:[header lowercaseString]];
    }
    
    for (NSString* prohibitedHeader in prohibitedUpperArray) {
        optionalHeaders = @{prohibitedHeader: @"some value"};
        pull = [self createPullReplicationWithHeaders:optionalHeaders];
        error = nil;
        pullDoc = [pull dictionaryForReplicatorDocument:&error];
        XCTAssertNil(pullDoc, @"CDTPullReplication -dictionaryForReplicatorDocument passed with "
                       @"header: %@, pullDoc: %@", optionalHeaders, pullDoc);
        XCTAssertNotNil(error, @"Error was not set");
        XCTAssertEqual(error.code, CDTReplicationErrorProhibitedOptionalHttpHeader,
                       @"Wrote error code: %@", error.code);
    }
    //make sure the lower case versions fail too
    for (NSString* prohibitedHeader in prohibitedLowerArray) {
        optionalHeaders = @{prohibitedHeader: @"some value"};
        pull = [self createPullReplicationWithHeaders:optionalHeaders];
        error = nil;
        pullDoc = [pull dictionaryForReplicatorDocument:&error];
        XCTAssertNil(pullDoc, @"CDTPullReplication -dictionaryForReplicatorDocument passed with "
                    @"header: %@, pullDoc: %@", optionalHeaders, pullDoc);
        XCTAssertNotNil(error, @"Error was not set");
        XCTAssertEqual(error.code, CDTReplicationErrorProhibitedOptionalHttpHeader,
                       @"Wrote error code: %@", error.code);
    }
}

@end
