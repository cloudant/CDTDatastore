//
//  CDTIAMSessionCookieInterceptor.m
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

#import <Foundation/Foundation.h>

#import "CDTIAMSessionCookieInterceptor.h"
#import "CDTLogging.h"

static const NSInteger CDTIAMSessionCookieRequestTimeout = 600;


@interface CDTIAMSessionCookieInterceptor ()


@property NSData *IAMSessionRequestBody;

- (NSData *)getBearerToken;

/** NSURLSession to make calls to get IAM bearer token (shouldn't be same one we're intercepting). */
@property (nonnull, nonatomic, strong) NSURLSession *IAMURLSession;

@property NSURL *IAMTokenURL;

@end

@implementation CDTIAMSessionCookieInterceptor

- (instancetype)initWithAPIKey:(NSString *)apiKey
{
    self = [super init];
    if (self) {
        // build the request to get the IAM bearer token
        _IAMSessionRequestBody = [[NSString stringWithFormat:@"grant_type=urn:ibm:params:oauth:grant-type:apikey&response_type=cloud_iam&apikey=%@", [apiKey stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]] dataUsingEncoding:NSUTF8StringEncoding];
        
        NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
        // The IAM bearer token endpoint requires a form-encoded request with API key present.
        // We might as well set that up now.
        config.HTTPAdditionalHeaders = @{ @"Content-Type" : @"application/x-www-form-urlencoded" };
        _IAMURLSession = [NSURLSession sessionWithConfiguration:config];
        [super setShouldMakeSessionRequest:YES];
        
        _IAMTokenURL = [NSURL URLWithString:[[NSProcessInfo processInfo]environment][@"CDT_IAM_TOKEN_URL"]];
        if (_IAMTokenURL == nil) {
            _IAMTokenURL = [NSURL URLWithString:@"https://iam.bluemix.net/identity/token"];
        }
    }
    return self;
}

- (NSURLSessionConfiguration*)customiseSessionConfig:(NSURLSessionConfiguration*)config
{
    // We are posting to the _iam_session endpoint using JSON.
    // We might as well set that up now.
    [config setHTTPAdditionalHeaders:@{ @"Content-Type" : @"application/json" }];
    return config;
}

- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    if (self.shouldMakeSessionRequest) {
        BOOL hasCookie = [self hasValidCookieWithName:@"IAMSession" forRequestURL: context.request.URL];
        if (!hasCookie) {
            // We don't have a cookie - first get the IAM bearer token
            NSData *bearerToken = [self getBearerToken];
            // Now get the _iam_session cookie
            if (bearerToken != nil) {
                [self setSessionRequestBody:bearerToken];
                NSURLComponents *components =
                [NSURLComponents componentsWithURL:context.request.URL resolvingAgainstBaseURL:NO];
                components.path = @"/_iam_session";
                NSURL *URL = [components URL];
                self.cookies = [super startNewSessionAtURL:URL withBody:self.sessionRequestBody session:self.urlSession sessionStartedHandler:^(NSData * data){return [self hasSessionStarted:data];}];
            } else {
                // Wipe the cookies if we couldn't get a valid token
                self.cookies = nil;
            }
        }
        [context.request setAllHTTPHeaderFields: [NSHTTPCookie requestHeaderFieldsWithCookies:self.cookies]];
    }
    return context;
}

- (NSData *)getBearerToken {

    CDTLogDebug(CDTREPLICATION_LOG_CONTEXT, @"Getting bearer token");
    
    // TODO allow over-riding of URL
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_IAMTokenURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = self.IAMSessionRequestBody;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSData *token = nil;
    NSURLSessionDataTask *task = [self.IAMURLSession
                                  dataTaskWithRequest:request
                                  completionHandler:^(NSData *__nullable data, NSURLResponse *__nullable response,
                                                      NSError *__nullable error) {
                                      
                                      NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                                      
                                      if (httpResp && httpResp.statusCode / 100 == 2) {
                                          token = data;
                                          CDTLogDebug(CDTREPLICATION_LOG_CONTEXT, @"Got IAM token");
                                      } else if (!httpResp) {
                                          // Network failure of some kind; often transient. Try again next time.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"Error getting cookie response from the server at %@, error: %@",
                                                      request.URL,
                                                      [error localizedDescription]);
                                      } else if (httpResp.statusCode / 100 == 5) {
                                          // Server error of some kind; often transient. Try again next time.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT,
                                                      @"Failed to get cookie from the server at %@, response code was %ld.",
                                                      request.URL,
                                                      (long)httpResp.statusCode);
                                      } else if (httpResp.statusCode == 401) {
                                          // Credentials are not valid, fail and don't retry.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"Credentials are incorrect for the server at %@, cookie "
                                                      @"authentication will not be attempted "
                                                      @"again by this interceptor object",
                                                      request.URL);
                                          self.shouldMakeSessionRequest = NO;
                                      } else {
                                          // Most other HTTP status codes are non-transient failures; don't retry.
                                          CDTLogError(CDTREPLICATION_LOG_CONTEXT,
                                                      @"Failed to get cookie from the server at %@, response code %ld. Cookie "
                                                      @"authentication will not be attempted again by this interceptor "
                                                      @"object",
                                                      request.URL,
                                                      (long)httpResp.statusCode);
                                          self.shouldMakeSessionRequest = NO;
                                      }
                                      dispatch_semaphore_signal(sema);
                                      
                                  }];
    [task resume];
    dispatch_semaphore_wait(
                            sema, dispatch_time(DISPATCH_TIME_NOW, CDTIAMSessionCookieRequestTimeout * NSEC_PER_SEC));
    return token;
}

/* this is a no-op for IAM session, we only needed to check the HTTP status code */
- (BOOL)hasSessionStarted:(nonnull NSData *)data
{
    return true;
}


@end
