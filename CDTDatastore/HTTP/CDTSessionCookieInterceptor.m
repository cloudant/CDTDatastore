//
//  CDTSessionCookieInterceptor.m
//
//
//  Created by Rhys Short on 08/09/2015.
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

#import "CDTSessionCookieInterceptor.h"
#import "CDTLogging.h"


@interface CDTSessionCookieInterceptor ()

@end

@implementation CDTSessionCookieInterceptor

- (instancetype)initWithUsername:(NSString *)username password:(NSString *)password
{
    self = [super init];
    if (self) {

        // The _session endpoint requires a form-encoded username/password combination.
        // We might as well set that up now.
        [[[super urlSession] configuration] setHTTPAdditionalHeaders:@{ @"Content-Type" : @"application/x-www-form-urlencoded" }];
        [super setSessionRequestBody:
            [[NSString stringWithFormat:@"name=%@&password=%@",
              [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
              [password stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]]
             dataUsingEncoding:NSUTF8StringEncoding]];

    }
    return self;
}

- (NSURLSessionConfiguration*)customiseSessionConfig:(NSURLSessionConfiguration*)config
{
    // The _session endpoint requires a form-encoded username/password combination.
    // We might as well set that up now.
    [config setHTTPAdditionalHeaders:@{ @"Content-Type" : @"application/x-www-form-urlencoded" }];
    return config;
}

/**
 The interceptor adds a session cookie to every request, unless we've encountered an error
 retrieving a cookie that doesn't look recoverable. If we don't yet have a session cookie,
 this method handles making a request to _session to retrieve one.
 */
- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    if (self.shouldMakeSessionRequest) {
        BOOL hasCookie = [self hasValidCookieWithName:@"AuthSession" forRequestURL: context.request.URL];
        if (!hasCookie) {
            // We don't have a cookie --
            // either a new session entirely or the old one is expired (or nearly expired).
            self.cookies = [self startNewSessionAtURL:context.request.URL];
        }
        [context.request setAllHTTPHeaderFields: [NSHTTPCookie requestHeaderFieldsWithCookies:self.cookies]];
    }

    return context;
}

/**
 Handles retrieving a cookie ("logging in") for the credentials this interceptor
 was initialised with.

 If the request fails, this method will also set the `shouldMakeSessionRequest` property
 to `NO` if the error didn't look transient.
 */
- (nullable NSArray<NSHTTPCookie *> *)startNewSessionAtURL:(NSURL *)url
{
    NSURLComponents *components =
    [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.path = @"/_session";
    
    return [super startNewSessionAtURL:[components URL] withBody:self.sessionRequestBody session:self.urlSession sessionStartedHandler:^(NSData * data){return [self hasSessionStarted:data];}];
}

/**
 Check the content of a response to make sure the reply indicates we're really logged in.
 */
- (BOOL)hasSessionStarted:(nonnull NSData *)data
{
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    // Only check for ok:true, https://issues.apache.org/jira/browse/COUCHDB-1356
    // means we cannot check that the name returned is the one we sent.
    return [[jsonResponse objectForKey:@"ok"] boolValue];
}

- (void)dealloc { [self.urlSession invalidateAndCancel]; }
@end
