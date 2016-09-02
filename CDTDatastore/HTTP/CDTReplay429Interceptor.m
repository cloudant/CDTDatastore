//
//  CDTReplay429Interceptor.m
//  CDTDatastore
//
//  Created by tomblench on 23/06/2016.
//  Copyright © 2016 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTReplay429Interceptor.h"

static NSString *kSleepKey = @"com.cloudant.CDTRequestLimitInterceptor.sleep";
static NSString *kRetryCountKey = @"com.cloudant.CDTRequestLimitInterceptor.retryCount";

@interface CDTReplay429Interceptor ()

// the initial time to sleep on receipt of a 429
@property (readonly) NSTimeInterval initialSleep;

// the maximum number of retries (after original request) to make on receipt of a
// 429
@property (readonly) int maxRetries;

@end

@implementation CDTReplay429Interceptor

+ (instancetype)interceptor
{
    return [[CDTReplay429Interceptor alloc] init];
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
        if (![context stateForKey:kSleepKey]) {
            [context setState:@(self.initialSleep) forKey:kSleepKey];
        }
        if (![context stateForKey:kRetryCountKey]) {
            [context setState:@0 forKey:kRetryCountKey];
        }
        
        double sleep = [(NSNumber*)[context stateForKey:kSleepKey] doubleValue];
        int retryCount = [(NSNumber*)[context stateForKey:kRetryCountKey] intValue];

        if (retryCount < self.maxRetries) {
            CDTLogInfo(CDTTD_REMOTE_REQUEST_CONTEXT, @"429 error code (too many requests) received. "
                       "Will retry in %.3f seconds.", sleep);
            
            // sleep for a short time before making next request
            [NSThread sleepForTimeInterval:sleep];
            [context setState:@(sleep*2) forKey:kSleepKey]; // exponential back-off
            [context setState:@(retryCount+1) forKey:kRetryCountKey];
            context.shouldRetry = true;
        } else {
            CDTLogWarn(CDTTD_REMOTE_REQUEST_CONTEXT, @"Maximum number of retries (%d) exceeded in "
                       "CDTRequestLimitInterceptor.", self.maxRetries);
        }

    }
    return context;
}

@end
