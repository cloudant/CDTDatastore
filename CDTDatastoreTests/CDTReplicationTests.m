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
#import "CDTDocumentRevision.h"
#import "TD_Body.h"
#import "TD_Revision.h"
#import "TDPuller.h"
#import "TDPusher.h"
#import "CDTSessionCookieInterceptor.h"
#import "CDTReplay429Interceptor.h"
#import "TD_Database.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import <OCMock/OCMock.h>
#import <netinet/in.h>


@interface TDReplicator ()
@property (nonatomic, strong) NSArray* interceptors;
@end

@interface CDTReplicator()
- (TDReplicator *)buildTDReplicatorFromConfiguration:(NSError *__autoreleasing *)error;
@end

@interface CDTSessionCookieInterceptor()
@property (nonnull, strong, nonatomic) NSData *sessionRequestBody;
@end
#pragma mark Utility - ContextCaptureInterceptor

@interface ContextCaptureInterceptor : NSObject <CDTHTTPInterceptor>

@property CDTHTTPInterceptorContext *lastContext;

@end

@implementation ContextCaptureInterceptor

- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    _lastContext = context;
    return context;
}

@end

#pragma mark Utility - ChangesFeedRequestCheckInterceptor

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

#pragma mark Utility - SimpleHttpServer

@interface SimpleHttpServer : NSObject

@property int listenSocketFd;
@property bool stopped;
@property NSString *header;
@property int port;

@end

@implementation SimpleHttpServer

- (id)initWithHeader:(NSString*)header
                port:(int)port
{
    if (self = [super init]) {
        self.header = header;
        self.port = port;
    }
    return self;
}

// Start a simple HTTP server on localhost that responds to any message with a fixed header.
- (void)startWithError:(NSError**)error {
    int success;
    self.listenSocketFd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    int yes = 1;
    setsockopt(self.listenSocketFd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    self.stopped = false;
    const int buf_size = 1024;
    
    struct sockaddr_in serv_addr;
    memset(&serv_addr, '0', sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(self.port);
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    
    success = bind(self.listenSocketFd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    if (success == -1) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                     code:errno
                                 userInfo:@{@"reason":@"bind() failed"}];
        return;
    }
    success = listen(self.listenSocketFd, 10);
    if (success == -1) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                     code:errno
                                 userInfo:@{@"reason":@"listen() failed"}];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (!self.stopped)
        {
            int connfd = accept(self.listenSocketFd, (struct sockaddr*)NULL, NULL);
            if (connfd > 0) {
                char buffer[buf_size];
                bzero(buffer, buf_size);
                
                // Receive a message.
                recv(connfd, buffer, buf_size, 0);
                
                // We don't care what the message was (or if we read it all), just send back the header.
                const char* header = [self.header cString];
                write(connfd, header, strlen(header));
                close(connfd);
            } else {
                self.stopped = true;
            }
        }
    });
}

- (void)stop {
    self.stopped = true;
    close(self.listenSocketFd);
}

@end

#pragma mark Tests

@interface CDTReplicationTests : CloudantSyncTests

@end

@implementation CDTReplicationTests

- (void) testURLCredsIgnoredIfParametersPresentPull
{
    CDTReplicatorFactory * factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    NSError *error;
    //Doesn't need to be real, we aren't going to actually make a replication.
    NSURL * remoteUrl = [[NSURL alloc] initWithString:@"http://user:pass@example.com"];
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPullReplication *pull =
            [CDTPullReplication replicationWithSource:remoteUrl target:tmp username:@"username" password:@"password"];


    CDTReplicator * replicator = [factory oneWay:pull error:nil];
    TDReplicator * tdReplicator = [replicator buildTDReplicatorFromConfiguration:nil];
            // check the underlying source to make sure it doesn't contain the userinfo
    // and check that the interceptors list contains the cookie interceptor.
    XCTAssertEqualObjects(@"http://example.com", pull.source.absoluteString);
    XCTAssertEqual(tdReplicator.interceptors.count, 1);
    XCTAssertEqualObjects([tdReplicator.interceptors[0] class], [CDTSessionCookieInterceptor class]);

    NSData* expectedPayload = [[NSString stringWithFormat:@"name=%@&password=%@", @"username", @"password"]
            dataUsingEncoding:NSUTF8StringEncoding];
    CDTSessionCookieInterceptor* cookieInterceptor = (CDTSessionCookieInterceptor*)tdReplicator.interceptors[0];
            XCTAssertEqualObjects(expectedPayload, [cookieInterceptor sessionRequestBody]);
}

- (void) testURLCredsIgnoredIfParametersPresentPush {
    CDTReplicatorFactory * factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    NSError *error;
    //Doesn't need to be real, we aren't going to actually make a replication.
    NSURL * remoteUrl = [[NSURL alloc] initWithString:@"http://user:pass@example.com"];
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:tmp target:remoteUrl username:@"username" password:@"password"];

    CDTReplicator * replicator = [factory oneWay:push error:nil];
    TDReplicator * tdReplicator = [replicator buildTDReplicatorFromConfiguration:nil];


    // check the underlying source to make sure it doesn't contain the userinfo
    // and check that the interceptors list contains the cookie interceptor.
    XCTAssertEqualObjects(@"http://example.com", push.target.absoluteString);
    XCTAssertEqual(tdReplicator.interceptors.count, 1);
    XCTAssertEqualObjects([tdReplicator.interceptors[0] class], [CDTSessionCookieInterceptor class]);

    NSData* expectedPayload = [[NSString stringWithFormat:@"name=%@&password=%@", @"username", @"password"]
            dataUsingEncoding:NSUTF8StringEncoding];
    CDTSessionCookieInterceptor* cookieInterceptor = (CDTSessionCookieInterceptor*) tdReplicator.interceptors[0];
    XCTAssertEqualObjects(expectedPayload, [cookieInterceptor sessionRequestBody]);
}

- (void)testURLCredsReplacedWithCookieInterceptorPull
{
    NSError *error;
    //Doesn't need to be real, we aren't going to actually make a replication.
    NSURL * remoteUrl = [[NSURL alloc] initWithString:@"http://user:pass@example.com"];
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPullReplication *pull =
    [CDTPullReplication replicationWithSource:remoteUrl target:tmp];

    // check the underlying source to make sure it doesn't contain the userinfo
    // and check that the interceptors list contains the cookie interceptor.
    XCTAssertEqualObjects(@"http://example.com", pull.source.absoluteString);
    XCTAssertEqual(pull.httpInterceptors.count, 1);
    XCTAssertEqualObjects([pull.httpInterceptors[0] class], [CDTSessionCookieInterceptor class]);
}

- (void)testURLCredsReplacedWithCookieInterceptorPush
{
    NSError *error;
    //Doesn't need to be real, we aren't going to actually make a replication.
    NSURL * remoteUrl = [[NSURL alloc] initWithString:@"http://user:pass@example.com"];
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:tmp target:remoteUrl];

    // check the underlying source to make sure it doesn't contain the userinfo
    // and check that the interceptors list contains the cookie interceptor.
    XCTAssertEqualObjects(@"http://example.com", push.target.absoluteString);
    XCTAssertEqual(push.httpInterceptors.count, 1);
    XCTAssertEqualObjects([push.httpInterceptors[0] class], [CDTSessionCookieInterceptor class]);
}

- (void)testCredentialsAddedViaPushInit
{
    NSError *error;
    // Doesn't need to be real, we aren't going to actually make a replication.
    NSURL *remoteUrl = [[NSURL alloc] initWithString:@"http://example.com"];
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:tmp
                                                                  target:remoteUrl
                                                                username:@"user"
                                                                password:@"password"];

    // check the underlying source to make sure it doesn't contain the userinfo
    // and check that the interceptors list contains the cookie interceptor.
    XCTAssertEqualObjects(@"http://example.com", push.target.absoluteString);
    XCTAssertEqual(push.httpInterceptors.count, 0);

    // The interceptor will be added when creating the TDReplicator
    error = nil;

    CDTReplicatorFactory *factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    CDTReplicator *replicator = [factory oneWay:push error:&error];
    XCTAssertNil(error);
    error = nil;
    TDReplicator *tdReplicator = [replicator buildTDReplicatorFromConfiguration:&error];
    XCTAssertNil(error);
    NSArray<id<CDTHTTPInterceptor>> *interceptors = tdReplicator.interceptors;

    XCTAssertNotNil(interceptors);
    XCTAssertEqual(1, interceptors.count);
    XCTAssertEqual([interceptors[0] class], [CDTSessionCookieInterceptor class]);
}

- (void)testCredentialsAddedViaPullInit
{
    NSError *error;
    // Doesn't need to be real, we aren't going to actually make a replication.
    NSURL *remoteUrl = [[NSURL alloc] initWithString:@"http://example.com"];
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:remoteUrl
                                                                  target:tmp
                                                                username:@"user"
                                                                password:@"password"];

    // check the underlying source to make sure it doesn't contain the userinfo
    // and check that the interceptors list contains the cookie interceptor.
    XCTAssertEqualObjects(@"http://example.com", pull.source.absoluteString);
    XCTAssertEqual(pull.httpInterceptors.count, 0);

    // The interceptor will be added when creating the TDReplicator
    error = nil;

    CDTReplicatorFactory *factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    CDTReplicator *replicator = [factory oneWay:pull error:&error];
    XCTAssertNil(error);
    error = nil;
    TDReplicator *tdReplicator = [replicator buildTDReplicatorFromConfiguration:&error];
    XCTAssertNil(error);
    NSArray<id<CDTHTTPInterceptor>> *interceptors = tdReplicator.interceptors;

    XCTAssertNotNil(interceptors);
    XCTAssertEqual(1, interceptors.count);
    XCTAssertEqual([interceptors[0] class], [CDTSessionCookieInterceptor class]);
}

// this test can only run on macOS and not iOS because it needs to start a server
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
- (void)test429Retry
{
    NSError *error = nil;
    SimpleHttpServer *server;
    // simple remote to send 429
    int port = 9999 + (arc4random() & 0x3FF); // add 10 bits of randomness
    // find a free port
    for (int i=0; i<100; i++, port++) {
        server = [[SimpleHttpServer alloc] initWithHeader:@"HTTP/1.0 429 Too Many Requests\r\n\r\n"
                                                                       port:port];
        [server startWithError:&error];
        if (error == nil) {
            break;
        }
    }
    XCTAssertNil(error, @"Start errored with %@", error);
        
    if (error) {
        // early exit
        return;
    }
    NSString *remoteUrl = [NSString stringWithFormat:@"http://127.0.0.1:%d", port];
    
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTPullReplication *pull =
    [CDTPullReplication replicationWithSource:[NSURL URLWithString:remoteUrl] target:tmp];
    // add 429 backoff interceptor
    [pull addInterceptor:[CDTReplay429Interceptor interceptor]];
    // add utility interceptor to capture final sleep valuew
    ContextCaptureInterceptor *cci = [[ContextCaptureInterceptor alloc] init];
    [pull addInterceptor:cci];
    CDTReplicatorFactory *replicatorFactory =
    [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
    
    CDTReplicator *replicator = [replicatorFactory oneWay:pull error:&error];
    
    dispatch_group_t taskGroup = dispatch_group_create();
    [replicator startWithTaskGroup:taskGroup error:&error];
    
    dispatch_group_wait(taskGroup, DISPATCH_TIME_FOREVER);

    // after 3 retries the sleep time should equal 2s:
    // 250ms * (2^3)
    double lastSleepValue = [(NSNumber*)[cci.lastContext stateForKey:@"com.cloudant.CDTRequestLimitInterceptor.sleep"] doubleValue];
    XCTAssertEqual(2.0, lastSleepValue);
    
    [server stop];
}
#endif

// this test can only run on macOS and not iOS because it needs to start a server
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
- (void)testFiltersWithChangesFeed
{
    NSError *error = nil;
    SimpleHttpServer *server;
    // We need a real remote here, so the reachability test before the replication starts
    // passes, it doesn't need a couch server, since the NSURLProtocol will 404 any request.
    // We can't use OHHTTPStubs to stub the server as that doesn't work with background
    // requests, so we just start a simple local server that returns 404 to anything it receives
    // and use that for our remote.
    int port = 9999 + (arc4random() & 0x3FF); // add 10 bits of randomness
    // find a free port
    for (int i=0; i<100; i++, port++) {
        server = [[SimpleHttpServer alloc] initWithHeader:@"HTTP/1.0 404 Not Found\r\n\r\n"
                                                                   port:port];
        [server startWithError:&error];
        if (error == nil) {
            break;
        }
    }
    XCTAssertNil(error, @"Start errored with %@", error);

    if (error) {
        // early exit
        return;
    }
    NSString *remoteUrl = [NSString stringWithFormat:@"http://127.0.0.1:%d", port];

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

    [server stop];
}
#endif

-(void)testReplicatorIsNilForNilDatastoreManager {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([[CDTReplicatorFactory alloc] initWithDatastoreManager:nil], @"Replication factory should be nil");
#pragma clang diagnostic pop
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
    NSDictionary *optionalHeaders;
    
    optionalHeaders = @{@"User-Agent": @"My Agent"};
    pull = [self createPullReplicationWithHeaders:optionalHeaders];
    error = nil;
    
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
        CDTReplicatorFactory *replicatorFactory =
        [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
        CDTReplicator *rep = [replicatorFactory oneWay:pull error:&error];
        
        XCTAssertNil(rep, @"Error was not set");
        XCTAssertNotNil(error, @"Error was not set");
        XCTAssertEqual(error.code, CDTReplicationErrorProhibitedOptionalHttpHeader,
                       @"Wrote error code: %ld", (long)error.code);
    }
    //make sure the lower case versions fail too
    for (NSString* prohibitedHeader in prohibitedLowerArray) {
        optionalHeaders = @{prohibitedHeader: @"some value"};
        pull = [self createPullReplicationWithHeaders:optionalHeaders];
        CDTReplicatorFactory *replicatorFactory =
        [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.factory];
        CDTReplicator *rep = [replicatorFactory oneWay:pull error:&error];
        
        XCTAssertNil(rep, @"Error was not set");
        XCTAssertNotNil(error, @"Error was not set");
        XCTAssertEqual(error.code, CDTReplicationErrorProhibitedOptionalHttpHeader,
                       @"Wrote error code: %ld", (long)error.code);
    }
}

@end
