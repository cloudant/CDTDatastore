//
//  CDTSessionCookieInterceptorBase.m
//  CDTDatastore
//
//  Created by tomblench on 05/07/2017.
//  Copyright © 2017 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTSessionCookieInterceptorBase.h"
#import "CDTLogging.h"

/** Number of seconds to wait for _session to respond. */
static const NSInteger CDTSessionCookieRequestTimeout = 600;


@implementation CDTSessionCookieInterceptorBase


- (instancetype)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
        [self setShouldMakeSessionRequest:YES];
        // allow sub-classes to set headers etc for the session
        config = [self customiseSessionConfig:config];
        [self setUrlSession:[NSURLSession sessionWithConfiguration:config]];
    }
    return self;
}

- (NSURLSessionConfiguration*)customiseSessionConfig:(NSURLSessionConfiguration*)config
{
    // sub-classes may wish to over-ride this
    return config;
}


/**
 We assume a 401 means that the cookie we applied at request time was rejected. Therefore
 clear it and tell the HTTP mechanism to retry the request. For all other responses, there's
 nothing for this interceptor to do.
 */
- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    if (context.response.statusCode == 401 && self.shouldMakeSessionRequest) {
        self.cookie = nil;
        context.shouldRetry = YES;
    }

    return context;
}


/**
 Handles retrieving a cookie ("logging in") for the credentials this interceptor
 was initialised with.
 
 If the request fails, this method will also set the `shouldMakeSessionRequest` property
 to `NO` if the error didn't look transient.
 */
- (nullable NSString *)startNewSessionAtURL:(NSURL *)url
                                   withBody:(NSData *)body
                                    session:(NSURLSession *)session
                      sessionStartedHandler:(BOOL (^)(NSData *data))sessionStartedHandler
{
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSString *cookie = nil;
    NSURLSessionDataTask *task = [session
                                  dataTaskWithRequest:request
                                  completionHandler:^(NSData *__nullable data, NSURLResponse *__nullable response,
                                                      NSError *__nullable error) {
                                      
                                      NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                                      
                                      if (httpResp && httpResp.statusCode / 100 == 2) {
                                          // Success! Get the cookie from the header if login succeeded.
                                          if (data && sessionStartedHandler(data)) {
                                              NSString *cookieHeader = httpResp.allHeaderFields[@"Set-Cookie"];
                                              cookie = [cookieHeader componentsSeparatedByString:@";"][0];
                                          }
                                      } else if (!httpResp) {
                                          // Network failure of some kind; often transient. Try again next time.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"Error making cookie response, error:%@",
                                                      [error localizedDescription]);
                                      } else if (httpResp.statusCode / 100 == 5) {
                                          // Server error of some kind; often transient. Try again next time.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT,
                                                      @"Failed to get cookie from the server at %@, response code was %ld.",
                                                      url,
                                                      (long)httpResp.statusCode);
                                      } else if (httpResp.statusCode == 401) {
                                          // Credentials are not valid, fail and don't retry.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"Credentials are incorrect, cookie "
                                                      @"authentication will not be attempted "
                                                      @"again by this interceptor object");
                                          self.shouldMakeSessionRequest = NO;
                                      } else {
                                          // Most other HTTP status codes are non-transient failures; don't retry.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT,
                                                      @"Failed to get cookie from the server at %@, response code %ld. Cookie "
                                                      @"authentication will not be attempted again by this interceptor "
                                                      @"object",
                                                      url,
                                                      (long)httpResp.statusCode);
                                          self.shouldMakeSessionRequest = NO;
                                      }
                                      
                                      dispatch_semaphore_signal(sema);
                                      
                                  }];
    [task resume];
    dispatch_semaphore_wait(
                            sema, dispatch_time(DISPATCH_TIME_NOW, CDTSessionCookieRequestTimeout * NSEC_PER_SEC));
    
    return cookie;
}

@end
