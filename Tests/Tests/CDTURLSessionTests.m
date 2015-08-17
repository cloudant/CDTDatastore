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

// Expose private vars used by tests
@interface CDTURLSessionTask (Tests)
@property (nonatomic, strong) NSArray *requestInterceptors;
@end

@interface CDTCountingHTTPRequestInterceptor : NSObject <CDTHTTPInterceptor>

@property int timesCalled;

@end

@implementation CDTCountingHTTPRequestInterceptor

- (nonnull CDTHTTPInterceptorContext *)interceptRequestInContext:(nonnull CDTHTTPInterceptorContext *)context {
    self.timesCalled++;
    return context;
}

@end

@interface CDTURLSessionTests : CloudantSyncTests

@end


@implementation CDTURLSessionTests

- (void)testRequestInterceptorsSetCorrectly
{
    CDTCountingHTTPRequestInterceptor *countingInterceptor =
        [[CDTCountingHTTPRequestInterceptor alloc] init];
    CDTURLSession *session = [[CDTURLSession alloc] initWithDelegate:nil
                                                      callbackThread:[NSThread currentThread]
                                                 requestInterceptors:@[ countingInterceptor ]];

    //make a request but don't start it
    NSURLRequest *request =
        [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:5984"]];

    CDTURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:nil];

    XCTAssertEqual(task.requestInterceptors.count, 1);
    XCTAssertEqual(task.requestInterceptors[0], countingInterceptor);
    XCTAssertEqual(NSURLSessionTaskStateSuspended, task.state);
}

@end
