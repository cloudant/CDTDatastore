//
//  CDTURLSessionTask.h
//
//
//  Created by Rhys Short on 20/08/2015.
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

@interface CDTURLSessionTask ()

/**
 Request we're carrying out.
 */
@property (nonatomic, strong) NSURLRequest *request;

/*
 * The NSURLSessionTask backing this one
 */
@property (nonnull, nonatomic, strong) NSURLSessionDataTask *inProgressTask;

@property NSURLSession *session;

/**
 Request interceptors. -init... filters to only valid request interceptors
 */
@property (nonatomic, strong) NSArray *requestInterceptors;

@end

@implementation CDTURLSessionTask

- (instancetype)init
{
    NSAssert(NO, @"Use designated initializer");
    return nil;
}

- (instancetype)initWithSession:(NSURLSession *)session
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
    }
    return self;
}

- (void)resume
{
    NSURLSessionTask *t = self.inProgressTask;
    if (!t) {
        CDTHTTPInterceptorContext *ctx =
            [[CDTHTTPInterceptorContext alloc] initWithRequest:[self.request mutableCopy]];

        // We make sure all objects support `interceptRequestInContext:` during init.
        for (NSObject<CDTHTTPInterceptor> *obj in self.requestInterceptors) {
            ctx = [obj interceptRequestInContext:ctx];
        }

        __weak CDTURLSessionTask *weakSelf = self;
        self.inProgressTask = [self.session
            dataTaskWithRequest:ctx.request
              completionHandler:^void(NSData *data, NSURLResponse *response, NSError *error) {
                  __strong CDTURLSessionTask *self = weakSelf;
                  if (self && self.completionHandler) {
                      data = [NSData dataWithData:data];
                      self.completionHandler(data, response, error);
                  }
              }];
    }
    [self.inProgressTask resume];
}
- (void)cancel
{
    NSURLSessionTask *t = self.inProgressTask;
    if (t) {
        [t cancel];
    }
}

- (NSURLSessionTaskState)state
{
    NSURLSessionTask *t = self.inProgressTask;
    if (t) {
        return t.state;
    } else {
        return NSURLSessionTaskStateSuspended;  // essentially we're in this state until resumed.
    }
}

#pragma mark Helpers

/**
 Copy the interceptor array, filtering out non-compliant classes.

 We do this once during -init... to avoid spamming the logs for every retry. This checks for
 responding to `interceptRequestInContext:` as we're creating a request interceptor array,
 not a response one.
 */
- (NSArray *)filterRequestInterceptors:(NSArray *)proposedRequestInterceptors
{
    NSMutableArray *acc = [NSMutableArray array];

    for (NSObject *obj in proposedRequestInterceptors) {
        if (![obj conformsToProtocol:@protocol(CDTHTTPInterceptor)]) {
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@ doesn't conform to protocol \
                       CDTURLSessionInterceptor, skipping",
                       obj);
            continue;
        }

        if (![obj respondsToSelector:@selector(interceptRequestInContext:)]) {
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@ doesn't respond to \
                       interceptRequestInContext:, skipping",
                       obj);
            continue;
        }

        [acc addObject:obj];
    }

    return [NSArray arrayWithArray:acc];
}

@end

