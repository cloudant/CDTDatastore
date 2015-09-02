//
//  CDTURLSessionTests.m
//  Tests
//
//  Created by Rhys Short on 24/08/2015.
//
//

#import <XCTest/XCTest.h>
#import "CloudantSyncTests.h"
#import "CDTURLSession.h"
#import "CDTHTTPInterceptorContext.h"
#import "CDTHTTPInterceptor.h"

#import "AllNullResponseURLProtocol.h"

// Expose private vars used by tests
@interface CDTURLSessionTask (Tests)
@property (nonatomic, strong) NSArray *requestInterceptors;
@property (nonatomic, strong) NSArray *responseInterceptors;
@end

@interface CDTCountingHTTPRequestInterceptor : NSObject <CDTHTTPInterceptor>

@property (nonatomic) int timesRequestIntercepted;
@property (nonatomic) int timesResponseIntercepted;

@end

@implementation CDTCountingHTTPRequestInterceptor

- (instancetype)init
{
    self = [super init];

    if (self) {
        _timesRequestIntercepted = 0;
        _timesResponseIntercepted = 0;
    }
    return self;
}

- (nonnull CDTHTTPInterceptorContext *)interceptRequestInContext:(nonnull CDTHTTPInterceptorContext *)context {
    self.timesRequestIntercepted++;
    return context;
}

- (nonnull CDTHTTPInterceptorContext *)interceptResponseInContext:
    (nonnull CDTHTTPInterceptorContext *)context
{
    self.timesResponseIntercepted++;
    return context;
}

@end

@interface CDTRetryingHTTPInterceptor : NSObject <CDTHTTPInterceptor>

@property (nonatomic) int timesCalled;
@property (nonatomic) int numberOfRetriesRemaining;

@end

@implementation CDTRetryingHTTPInterceptor

- (instancetype)init
{
    return [self initWithNumberOfRetires:1];
}
- (instancetype)initWithNumberOfRetires:(int)retries
{
    self = [super init];
    if (self) {
        _timesCalled = 0;
        _numberOfRetriesRemaining = retries;
    }
    return self;
}

- (nonnull CDTHTTPInterceptorContext *)interceptResponseInContext:
    (nonnull CDTHTTPInterceptorContext *)context
{
    if (self.numberOfRetriesRemaining > 0) {
        context.shouldRetry = YES;
        self.numberOfRetriesRemaining--;
    }
    self.timesCalled++;
    return context;
}

@end

@interface CDTURLSessionTests : CloudantSyncTests

@end


@implementation CDTURLSessionTests

- (void)setUp
{
    [super setUp];
    [NSURLProtocol registerClass:[AllNullResponseURLProtocol class]];
}

- (void)tearDown
{
    [super tearDown];
    [NSURLProtocol unregisterClass:[AllNullResponseURLProtocol class]];
}

- (void)testInterceptorsSetCorrectly
{
    CDTCountingHTTPRequestInterceptor *countingInterceptor =
        [[CDTCountingHTTPRequestInterceptor alloc] init];
    CDTURLSession *session = [[CDTURLSession alloc] initWithDelegate:nil
                                                      callbackThread:[NSThread currentThread]
                                                 requestInterceptors:@[ countingInterceptor ]];

    NSURLRequest *request =
        [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:5984"]];

    CDTURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:nil];

    XCTAssertEqual(task.requestInterceptors.count, 1);
    XCTAssertEqual(task.requestInterceptors[0], countingInterceptor);
    XCTAssertEqual(task.responseInterceptors.count, 1);
    XCTAssertEqual(task.responseInterceptors[0], countingInterceptor);
    XCTAssertEqual(NSURLSessionTaskStateSuspended, task.state);
}

- (void)testInterceptorsGetCalled
{
    CDTCountingHTTPRequestInterceptor *countingInterceptor =
        [[CDTCountingHTTPRequestInterceptor alloc] init];
    CDTURLSession *session = [[CDTURLSession alloc] initWithDelegate:nil
                                                      callbackThread:[NSThread currentThread]
                                                 requestInterceptors:@[ countingInterceptor ]];

    NSURLRequest *request =
        [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:5984"]];

    CDTURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:nil];

    [task resume];

    while (task.state != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:0.1f];
    }

    XCTAssertEqual(countingInterceptor.timesRequestIntercepted, 1);
    XCTAssertEqual(countingInterceptor.timesResponseIntercepted, 1);
}

- (void)testInterceptorsCanRetryRequests
{
    CDTRetryingHTTPInterceptor *replayingInterceptor = [[CDTRetryingHTTPInterceptor alloc] init];
    CDTURLSession *session = [[CDTURLSession alloc] initWithDelegate:nil
                                                      callbackThread:[NSThread currentThread]
                                                 requestInterceptors:@[ replayingInterceptor ]];

    NSURLRequest *request =
        [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:5984"]];

    CDTURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:nil];

    XCTAssertEqual(task.responseInterceptors.count, 1);
    XCTAssertEqual(task.responseInterceptors[0], replayingInterceptor);
    XCTAssertEqual(NSURLSessionTaskStateSuspended, task.state);

    [task resume];
    while (task.state != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:0.1f];
    }
    XCTAssertEqual(replayingInterceptor.timesCalled, 2);
}

- (void)testMaxNumberOfRetriesEnforced
{
    CDTRetryingHTTPInterceptor *replayingInterceptor =
        [[CDTRetryingHTTPInterceptor alloc] initWithNumberOfRetires:1000000];
    CDTURLSession *session = [[CDTURLSession alloc] initWithDelegate:nil
                                                      callbackThread:[NSThread currentThread]
                                                 requestInterceptors:@[ replayingInterceptor ]];

    NSURLRequest *request =
        [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:5984"]];

    CDTURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:nil];

    XCTAssertEqual(task.responseInterceptors.count, 1);
    XCTAssertEqual(task.responseInterceptors[0], replayingInterceptor);
    XCTAssertEqual(NSURLSessionTaskStateSuspended, task.state);

    [task resume];
    while (task.state != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:0.1f];
    }
    // it should be called 11 times because we retry a request 10 times making 11 reqests in total
    XCTAssertEqual(replayingInterceptor.timesCalled, 11);
}

@end
