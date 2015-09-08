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

static const NSInteger CDTSessionCookieRequestTimeout = 600;

@interface CDTSessionCookieInterceptor ()

@property (nonnull, strong, nonatomic) NSData *cookieRequestBody;
@property (nonatomic) BOOL shouldMakeCookieRequest;
@property (nullable, strong, nonatomic) NSString *cookie;
@property (nonnull, nonatomic, strong) NSURLSession *urlSession;

@end

@implementation CDTSessionCookieInterceptor

- (instancetype)initWithUsername:(NSString *)username password:(NSString *)password
{
    self = [super init];
    if (self) {
        _cookieRequestBody = [[NSString stringWithFormat:@"name=%@&password=%@", username, password]
            dataUsingEncoding:NSUTF8StringEncoding];
        _shouldMakeCookieRequest = YES;
        NSURLSessionConfiguration *config =
            [NSURLSessionConfiguration ephemeralSessionConfiguration];
        // content type will always be application/x-www-form-urlencoded
        config.HTTPAdditionalHeaders = @{ @"Content-Type" : @"application/x-www-form-urlencoded" };
        _urlSession = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    if (self.shouldMakeCookieRequest) {
        if (!self.cookie) {
            // get the cookie
            self.cookie = [self newCookieForRemote:context.request.URL];
        }
        [context.request setValue:self.cookie forHTTPHeaderField:@"Cookie"];
    }

    return context;
}

- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    // check the response code.
    if (context.response.statusCode == 401) {
        // reset the cookie, let the request interceptor handle getting a new cookie.
        self.cookie = nil;
        context.shouldRetry = YES;
    }

    return context;
}

- (nullable NSString *)newCookieForRemote:(NSURL *)url
{
    NSURLComponents *components =
        [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.path = @"/_session";

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.HTTPBody = self.cookieRequestBody;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSString *cookie = nil;
    NSURLSessionDataTask *task = [self.urlSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *__nullable data, NSURLResponse *__nullable response,
                              NSError *__nullable error) {

            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            // handle response being nil
            if (!httpResp) {
                CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"Error making cookie response, error:%@",
                            [error localizedDescription]);
                return;
            }

            if ([httpResp statusCode] / 100 == 2) {
                // we have the cookie. maybe
                if (data && [self hasSessionStarted:data]) {
                    // get the cookie from the header
                    NSString *cookieHeader = [[httpResp allHeaderFields] valueForKey:@"Set-Cookie"];
                    cookie = [cookieHeader componentsSeparatedByString:@";"][0];
                }
            } else if ([httpResp statusCode] == 401) {
                CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"Credentials are incorrect, cookie "
                                                        @"authentication will not be attempted "
                                                        @"again by this interceptor object");
                self.shouldMakeCookieRequest = NO;
            } else if ([httpResp statusCode] / 100 == 5) {
                CDTLogError(CDTREPLICATION_LOG_CONTEXT,
                            @"Failed to get cookie from the server, response code was %ld.",
                            (long)[httpResp statusCode]);
            } else {
                CDTLogError(CDTREPLICATION_LOG_CONTEXT,
                            @"Failed to get cookie from the server,response code %ld. Cookie "
                            @"authentication will not be attempted again by this interceptor "
                            @"object",
                            (long)[httpResp statusCode]);
                self.shouldMakeCookieRequest = NO;
            }

            dispatch_semaphore_signal(sema);

          }];
    [task resume];
    dispatch_semaphore_wait(
        sema, dispatch_time(DISPATCH_TIME_NOW, CDTSessionCookieRequestTimeout * NSEC_PER_SEC));

    return cookie;
}

- (BOOL)hasSessionStarted:(nonnull NSData *)data
{
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    // only check for ok:true, https://issues.apache.org/jira/browse/COUCHDB-1356
    // means we cannot check that the name returned is the one we sent.
    return [[jsonResponse objectForKey:@"ok"] boolValue];
}

- (void)dealloc { [self.urlSession invalidateAndCancel]; }
@end
