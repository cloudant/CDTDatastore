//
//  CDTCookieInterceptorTests.m
//  Tests
//
//  Created by Rhys Short on 09/09/2015.
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

#import <XCTest/XCTest.h>
#import "CloudantSyncTests.h"
#import "CDTLogging.h"
#import "CDTSessionCookieInterceptor.h"
#import "CDTURLSession.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import <OHHTTPStubs/NSURLRequest+HTTPBodyTesting.h>
#import "OHHTTPStubsHelper.h"

// expose properties so we can look at them
@interface CDTSessionCookieInterceptor ()

@property (nonatomic) BOOL shouldMakeSessionRequest;
@property (nullable, strong, nonatomic) NSString *cookie;
@property (nonnull, nonatomic, strong) NSURLSession *urlSession;

@end

static const NSString *testCookieHeaderValue =
    @"AuthSession=cm9vdDo1MEJCRkYwMjq0LO0ylOIwShrgt8y-UkhI-c6BGw";

static const NSString *testCookieHeaderValue2 =
    @"AuthSession=dn0weEp2NFKDSlZxNkr1MP1zmPJxTishs9z-VliJ-d7CHx";

@interface CDTSessionCookieInterceptorTests : CloudantSyncTests

@end

@implementation CDTSessionCookieInterceptorTests

- (void)setUp
{
    setenv("CDT_TEST_ENABLE_OHHTTPSTUBS", "1", true);
    CDTChangeLogLevel(CDTTD_REMOTE_REQUEST_CONTEXT, DDLogLevelDebug);
    CDTChangeLogLevel(CDTREPLICATION_LOG_CONTEXT, DDLogLevelDebug);
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *__nonnull request) {
      return [[request.URL host] isEqualToString:@"username1.cloudant.com"];
    }
        withStubResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
          return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:401 headers:@{}];
        }];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *__nonnull request) {
      return [[request.URL host] isEqualToString:@"username.cloudant.com"];
    }
        withStubResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {

          if ([request.HTTPMethod isEqualToString:@"POST"]) {
              return [OHHTTPStubsResponse
                  responseWithJSONObject:@{
                      @"ok" : @(YES),
                      @"name" : @"username",
                      @"roles" : @[ @"_admin" ]
                  }
                              statusCode:200
                                 headers:@{
                                     @"Set-Cookie" : [NSString
                                         stringWithFormat:@"%@; Version=1; Path=/; HttpOnly",
                                                          testCookieHeaderValue]
                                 }];
          } else if ([request.HTTPMethod isEqualToString:@"GET"]) {
              return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:200 headers:@{}];
          } else if ([request.HTTPMethod isEqualToString:@"DELETE"]) {
              return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:200 headers:@{}];
          } else {
              XCTFail(@"Unexpected HTTP Method");
              return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
          }

        }];
}

- (void)tearDown {
    unsetenv("CDT_TEST_ENABLE_OHHTTPSTUBS");
    [OHHTTPStubs removeAllStubs];
}

- (void)testCookieInterceptorSuccessfullyGetsCookie
{
    CDTSessionCookieInterceptor *interceptor =
        [[CDTSessionCookieInterceptor alloc] initWithUsername:@"username" password:@"password"];

    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username.cloudant.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    CDTHTTPInterceptorContext *context =
        [[CDTHTTPInterceptorContext alloc] initWithRequest:[request mutableCopy]
                                                     state:[NSMutableDictionary dictionary]];

    context = [interceptor interceptRequestInContext:context];

    NSString *cookieString = [NSString stringWithFormat:@"%@=%@", interceptor.cookies[0].name, interceptor.cookies[0].value];
    XCTAssertEqualObjects(cookieString, testCookieHeaderValue);
    XCTAssertEqual(interceptor.shouldMakeSessionRequest, YES);
    XCTAssertEqualObjects([context.request valueForHTTPHeaderField:@"Cookie"],
                          testCookieHeaderValue);
}

- (void)testCookieInterceptorHandles401
{
    CDTSessionCookieInterceptor *interceptor =
        [[CDTSessionCookieInterceptor alloc] initWithUsername:@"username" password:@"password"];

    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username1.cloudant.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    CDTHTTPInterceptorContext *context =
        [[CDTHTTPInterceptorContext alloc] initWithRequest:[request mutableCopy]
                                                     state:[NSMutableDictionary dictionary]];

    context = [interceptor interceptRequestInContext:context];

    XCTAssertNil(interceptor.cookies);
    XCTAssertEqual(interceptor.shouldMakeSessionRequest, NO);
    XCTAssertNil([context.request valueForHTTPHeaderField:@"Cookie"]);
}

/**
 * Test cookie flow, where a Set-Cookie header on a (non _session) response
 * pre-emptively renews the cookie.
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get session cookie with short expiry time
 * - GET now proceeds as normal, expected cookie value is sent in header
 * - Longer lived cookie is sent in Set-Cookie header on this GET response
 * - second GET on cloudant server longer lived Cookie should be in place so
 * no renewal and successful GET with new cookie.
 */
- (void)testCookieInterceptorAcceptsSetCookieOnResponse
{
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _session endpoint, return cookie in header with 1 minute life
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"]);
        XCTAssert([[[NSString alloc] initWithData: request.OHHTTPStubs_HTTPBody encoding:NSUTF8StringEncoding] isEqualToString:@"name=username&password=password"]);
        return [OHHTTPStubsResponse
                responseWithJSONObject:@{
                                         @"ok" : @(YES),
                                         @"name" : @"username",
                                         @"roles" : @[ @"_admin" ]
                                         }
                statusCode:200
                headers:@{
                          @"Set-Cookie" : [NSString
                                           stringWithFormat:@"%@; Version=1; Path=/; HttpOnly; Max-Age=60",
                                           testCookieHeaderValue]
                          }];
    }];
    
    // get resource successfully using cookie, return longer cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{
                                                                                                      @"Set-Cookie" : [NSString
                                                                                                               stringWithFormat:@"%@; Version=1; Path=/; HttpOnly; Max-Age=86400",
                                                                                                               testCookieHeaderValue2]
                                                                                                      }];
    }];
    
    // get resource successfully using new cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue2 isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    [helper doStubsForHost:@"username2.cloudant.com"];
    
    CDTSessionCookieInterceptor *interceptor =
    [[CDTSessionCookieInterceptor alloc] initWithUsername:@"username" password:@"password"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username2.cloudant.com/somedb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:[NSThread currentThread] requestInterceptors:@[interceptor] sessionConfigDelegate: nil];
    
    // Initial GET will get a cookie and resource and update with a longer lived cookie
    CDTURLSessionTask *task = [session dataTaskWithRequest:request taskDelegate:nil];
    [task resume];
    while ([task state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    // Second GET should use new cookie
    CDTURLSessionTask *task2 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task2 resume];
    while ([task2 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    XCTAssert([helper currentResponse] == 3);
}

/**
 * Test cookie flow, where session is nearly expired and we pre-emptively renew.
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get session cookie with short expiry time
 * - GET now proceeds as normal, expected cookie value is sent in header
 * - second GET on cloudant server, cookie is nearly expired so should renew
 * - session cookie requested, followed by replay of request with new cookie.
 * - third GET on cloudant server with new valid cookie.
 */

- (void)testCookieInterceptorRenewsEarly
{
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _session endpoint, return cookie in header with 1 minute life
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"]);
        XCTAssert([[[NSString alloc] initWithData: request.OHHTTPStubs_HTTPBody encoding:NSUTF8StringEncoding] isEqualToString:@"name=username&password=password"]);
        return [OHHTTPStubsResponse
                responseWithJSONObject:@{
                                         @"ok" : @(YES),
                                         @"name" : @"username",
                                         @"roles" : @[ @"_admin" ]
                                         }
                statusCode:200
                headers:@{
                          @"Set-Cookie" : [NSString
                                           stringWithFormat:@"%@; Version=1; Path=/; HttpOnly; Max-Age=60",
                                           testCookieHeaderValue]
                          }];
    }];
    
    // get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // renewal call to _session endpoint, return cookie in header with 1 day life
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"]);
        XCTAssert([[[NSString alloc] initWithData: request.OHHTTPStubs_HTTPBody encoding:NSUTF8StringEncoding] isEqualToString:@"name=username&password=password"]);
        return [OHHTTPStubsResponse
                responseWithJSONObject:@{
                                         @"ok" : @(YES),
                                         @"name" : @"username",
                                         @"roles" : @[ @"_admin" ]
                                         }
                statusCode:200
                headers:@{
                          @"Set-Cookie" : [NSString
                                           stringWithFormat:@"%@; Version=1; Path=/; HttpOnly; Max-Age=86400",
                                           testCookieHeaderValue2]
                          }];
    }];
    
    // get resource successfully using new cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue2 isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // get another resource successfully using new cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue2 isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    [helper doStubsForHost:@"username2.cloudant.com"];
    
    CDTSessionCookieInterceptor *interceptor =
    [[CDTSessionCookieInterceptor alloc] initWithUsername:@"username" password:@"password"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username2.cloudant.com/somedb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:[NSThread currentThread] requestInterceptors:@[interceptor] sessionConfigDelegate: nil];
    
    // Initial GET will get a cookie and resource
    CDTURLSessionTask *task = [session dataTaskWithRequest:request taskDelegate:nil];
    [task resume];
    while ([task state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    // Second GET should renew cookie and get resource
    CDTURLSessionTask *task2 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task2 resume];
    while ([task2 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    // Third GET should just GET resource
    CDTURLSessionTask *task3 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task3 resume];
    while ([task3 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    XCTAssert([helper currentResponse] == 5);
}

@end
