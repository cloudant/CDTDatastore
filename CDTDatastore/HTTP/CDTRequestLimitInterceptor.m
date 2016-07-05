//
//  CDTRequestLimitInterceptor.m
//  CDTDatastore
//
//  Created by tomblench on 23/06/2016.
//  Copyright © 2016 IBM Corporation. All rights reserved.
//

#import "CDTRequestLimitInterceptor.h"

static NSString *kSleepKey = @"com.cloudant.CDTRequestLimitInterceptor.sleep";
static NSString *kRetryCountKey = @"com.cloudant.CDTRequestLimitInterceptor.retryCount";

@interface CDTRequestLimitInterceptor ()

// the initial time to sleep on receipt of a 429
@property (readonly) NSTimeInterval initialSleep;

// the maximum number of retries (after original request) to make on receipt of a
// 429
@property (readonly) int maxRetries;

@end

@implementation CDTRequestLimitInterceptor

+ (instancetype)interceptor
{
    return [[CDTRequestLimitInterceptor alloc] init];
}

- (instancetype)init
{
    self = [self initWithSleep:0.25 // 250ms
                     maxRetries:3];
    return self;
}

- (instancetype)initWithSleep:(NSTimeInterval)initialSleep
                  maxRetries:(int)maxRetries;
{
    if (self = [super init]) {
        _initialSleep = initialSleep;
        _maxRetries = maxRetries;
    }
    return self;
}

/**
 * Interceptor to retry after an exponential backoff if we receive a 429 error
 */
- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    if (context.response.statusCode == 429) {

        // if we are the first invocation in this pipeline, set some state
        if (!context.state[kSleepKey]) {
            [context.state setValue:@(self.initialSleep) forKey:kSleepKey];
        }
        if (!context.state[kRetryCountKey]) {
            [context.state setValue:@0 forKey:kRetryCountKey];
        }
        
        double sleep = [(NSNumber*)context.state[kSleepKey] doubleValue];
        int retryCount = [(NSNumber*)context.state[kRetryCountKey] intValue];

        if (retryCount < self.maxRetries) {
            CDTLogInfo(CDTTD_REMOTE_REQUEST_CONTEXT, @"429 error code (too many requests) received. "
                       "Will retry in %@ seconds.", context.state[@"sleep"]);
            
            // sleep for a short time before making next request
            [NSThread sleepForTimeInterval:sleep];
            [context.state setValue:@(sleep*2) forKey:kSleepKey]; // exponential back-off
            [context.state setValue:@(retryCount+1) forKey:kRetryCountKey];
            context.shouldRetry = true;
        } else {
            CDTLogWarn(CDTTD_REMOTE_REQUEST_CONTEXT, @"Maximum number of retries (%d) exceeded in "
                       "CDTRequestLimitInterceptor.", self.maxRetries);
        }

    }
    return context;
}

@end
