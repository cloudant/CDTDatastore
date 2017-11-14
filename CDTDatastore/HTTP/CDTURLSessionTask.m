//
//  CDTURLSessionTask.h
//
//
//  Created by Rhys Short on 20/08/2015.
//  Copyright (c) 2015 IBM Corp.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTURLSessionTask.h"
#import "CDTHTTPInterceptorContext.h"
#import "CDTHTTPInterceptor.h"
#import "CDTLogging.h"
#import "CDTURLSession.h"

@interface CDTURLSessionTask ()

/**
 Request we're carrying out.
 */
@property (nonnull, nonatomic, strong) NSURLRequest *request;

/*
 * The NSURLSessionTask backing this one
 */
@property (nonnull, nonatomic, strong) NSURLSessionDataTask *inProgressTask;

@property CDTURLSession *session;

/**
 Request interceptors. -init... filters to only valid request interceptors
 */
@property (nonnull, nonatomic, strong) NSArray *requestInterceptors;

@property (nonnull, nonatomic, strong) NSArray *responseInterceptors;

@property (nonatomic) int remainingRetries;

@property (atomic) BOOL finished;

@property (nonnull, nonatomic, strong) NSMutableDictionary *contextState;


#pragma mark properties for the current request
@property (nullable, nonatomic, strong) NSHTTPURLResponse *response;
@property (nullable, nonatomic, strong) NSError * requestError;
@property (nullable, nonatomic, strong) NSData * responseData;

@end

NSString *const CDTURLSessionTaskErrorDomain = @"CDTURLSessionTaskErrorDomain";
static const int requestInterceptorCancelledError = 1;
static const int responseInterceptorCancelledError = 2;

@implementation CDTURLSessionTask

- (instancetype)init
{
    NSAssert(NO, @"Use designated initializer");
    return nil;
}

- (void) dealloc {
    [_session disassociateTask:_inProgressTask];
}

- (instancetype)initWithSession:(CDTURLSession *)session
                        request:(NSURLRequest *)request
                   interceptors:(NSArray *)interceptors
{
    NSParameterAssert(session);
    NSParameterAssert(request);

    self = [super init];
    if (self) {
        _session = session;
        _request = [request mutableCopy];
        _requestInterceptors = [self filterRequestInterceptors:interceptors];
        _responseInterceptors = [self filterResponseInterceptors:interceptors];
        _remainingRetries = 10;
        _contextState = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)resume
{
    NSURLSessionTask *t = self.inProgressTask;
    if (!t) {
        self.inProgressTask = [self makeRequest];
        // task can be nil, if interceptor returns nil (logging and error raising will have happened in makeRequest)
        if (self.inProgressTask == nil) {
            self.finished = YES;
            return;
        }
    }
    CDTLogVerbose(CDTTD_REMOTE_REQUEST_CONTEXT, @"Waiting on asyncTaskMonitor");
    [self.session waitForFreeSlot];
    CDTLogVerbose(CDTTD_REMOTE_REQUEST_CONTEXT, @"Wait completed");
    [self.inProgressTask resume];
}
- (void)cancel
{
    NSURLSessionTask *t = self.inProgressTask;
    if (t) {
        [t cancel];
    }
    self.finished = YES;
}

- (NSURLSessionTaskState)state
{
    NSURLSessionTask *t = self.inProgressTask;
    // Check finished as we use that to guard against returning the
    // NSURLSessionTask's state if we're about to retry the request.
    if (self.finished && t) {
        return t.state;
    } else {
        return NSURLSessionTaskStateSuspended;  // essentially we're in this state until resumed.
    }
}

#pragma mark Helpers

- (NSURLSessionDataTask *)makeRequest
{
    self.finished = NO;
    self.response = nil;
    self.requestError = nil;
    self.responseData = nil;
    __block CDTHTTPInterceptorContext *ctx =
        [[CDTHTTPInterceptorContext alloc] initWithRequest:[self.request mutableCopy]
                                                     state:self.contextState];

    // We make sure all objects support `interceptRequestInContext:` during init.
    for (NSObject<CDTHTTPInterceptor> *obj in self.requestInterceptors) {
        ctx = [obj interceptRequestInContext:ctx];
        if (ctx == nil) {
            // if interceptor returns nil, log an error, send the requestDidError message, and exit early
            CDTLogWarn(CDTTD_REMOTE_REQUEST_CONTEXT, @"Aborting request because interceptor %@ returned nil",
                       obj);
            NSError *err = [NSError errorWithDomain:CDTURLSessionTaskErrorDomain
                                               code:requestInterceptorCancelledError
                                           userInfo:@{@"message": [NSString stringWithFormat:@"Task was cancelled by request interceptor %@ returning nil", obj]}];
            [self.delegate performSelector:@selector(requestDidError:)
                                  onThread:[NSThread currentThread]
                                withObject:err
                             waitUntilDone:NO];
            return nil;
        }
    }
    
    // Update self.request with the updated request modified by any interceptors.
    self.request = ctx.request;

    return [self.session createDataTaskWithRequest:ctx.request
                                associatedWithTask:self];
}

/**
 Copy the interceptor array, filtering out non-compliant classes.

 We do this once during `-init...`. This checks for responding to `interceptRequestInContext:`
 as we're creating a request interceptor array, not a response one.
 */
- (nonnull NSArray *)filterRequestInterceptors:(nonnull NSArray *)proposedRequestInterceptors
{
    NSMutableArray *requestInterceptors = [NSMutableArray array];

    for (NSObject *obj in proposedRequestInterceptors) {
        if ([obj respondsToSelector:@selector(interceptRequestInContext:)]) {
            [requestInterceptors addObject:obj];
        }
    }

    return [NSArray arrayWithArray:requestInterceptors];
}

/**
 Copy the interceptor array, filtering out non-compliant classes.

 We do this once during `-init...`. This checks for responding to `interceptResponseInContext:`
 as we're creating a response interceptor array, not a request one.
 */
- (nonnull NSArray *)filterResponseInterceptors:(nonnull NSArray *)proposedResponseInterceptors
{
    NSMutableArray *responseInterceptors = [NSMutableArray array];

    for (NSObject *obj in proposedResponseInterceptors) {
        if ([obj respondsToSelector:@selector(interceptResponseInContext:)]) {
            [responseInterceptors addObject:obj];
        }
    }

    return [NSArray arrayWithArray:responseInterceptors];
}

- (void)processData:(NSData*)data {
    self.responseData = data;
}

- (void)processResponse:(NSURLResponse *)response onThread:(NSThread *)thread
{
    self.response = (NSHTTPURLResponse*)response;
}

- (void)processError:(NSError *)error onThread:(NSThread *)thread
{
    self.requestError = error;
}

- (void) completedThread:(NSThread *)thread {
    // copy state from request interceptor context to response interceptor context
    __block CDTHTTPInterceptorContext *ctx =
    [[CDTHTTPInterceptorContext alloc] initWithRequest:[self.request mutableCopy]
                                                 state:self.contextState];
    ctx.response = self.response;
    ctx.responseData = self.responseData;
    
    for (NSObject<CDTHTTPInterceptor> *obj in self.responseInterceptors) {
        ctx = [obj interceptResponseInContext:ctx];
        if (ctx == nil) {
            // if interceptor returns nil, log an error, send the requestDidError message, and exit early
            CDTLogWarn(CDTTD_REMOTE_REQUEST_CONTEXT, @"Aborting response interceptors because interceptor %@ returned nil",
                       obj);
            NSError *err = [NSError errorWithDomain:CDTURLSessionTaskErrorDomain
                                               code:responseInterceptorCancelledError
                                           userInfo:@{@"message": [NSString stringWithFormat:@"Task was cancelled by response interceptor %@ returning nil", obj]}];
            [self.delegate performSelector:@selector(requestDidError:)
                                  onThread:thread
                                withObject:err
                             waitUntilDone:NO];
            self.finished = YES;
            return;
        }
    }
    
    if (ctx.shouldRetry && self.remainingRetries > 0) {
        // retry
        self.remainingRetries--;
        // makeRequest maintains the state across retries, even though it creates a fresh context
        self.inProgressTask = [self makeRequest];
        [self.inProgressTask resume];
    } else {
        if( self.requestError){
            [self.delegate performSelector:@selector(requestDidError:)
                                  onThread:thread
                                withObject:self.requestError
                             waitUntilDone:NO];
        } else {
            [self.delegate performSelector:@selector(receivedResponse:)
                                  onThread:thread
                                withObject:self.response
                             waitUntilDone:NO];
            [self.delegate performSelector:@selector(receivedData:)
                                  onThread:thread
                                withObject:self.responseData
                             waitUntilDone:NO];
        }
        self.finished = YES;
    }

}

@end

