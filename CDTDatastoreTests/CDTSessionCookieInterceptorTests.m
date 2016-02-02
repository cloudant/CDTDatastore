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
#import "CDTSessionCookieInterceptor.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
// expose properties so we can look at them
@interface CDTSessionCookieInterceptor ()

@property (nonatomic) BOOL shouldMakeSessionRequest;
@property (nullable, strong, nonatomic) NSString *cookie;
@property (nonnull, nonatomic, strong) NSURLSession *urlSession;

@end

static const NSString *testCookieHeaderValue =
    @"AuthSession=cm9vdDo1MEJCRkYwMjq0LO0ylOIwShrgt8y-UkhI-c6BGw";

@interface CDTSessionCookieInterceptorTests : CloudantSyncTests

@end

@implementation CDTSessionCookieInterceptorTests

- (void)setUp
{
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

- (void)tearDown { [OHHTTPStubs removeAllStubs]; }
- (void)testCookieInterceptorSuccessfullyGetsCookie
{
    CDTSessionCookieInterceptor *interceptor =
        [[CDTSessionCookieInterceptor alloc] initWithUsername:@"username" password:@"password"];

    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username.cloudant.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    CDTHTTPInterceptorContext *context =
        [[CDTHTTPInterceptorContext alloc] initWithRequest:[request mutableCopy]];

    context = [interceptor interceptRequestInContext:context];

    XCTAssertEqualObjects(interceptor.cookie, testCookieHeaderValue);
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
        [[CDTHTTPInterceptorContext alloc] initWithRequest:[request mutableCopy]];

    context = [interceptor interceptRequestInContext:context];

    XCTAssertNil(interceptor.cookie);
    XCTAssertEqual(interceptor.shouldMakeSessionRequest, NO);
    XCTAssertNil([context.request valueForHTTPHeaderField:@"Cookie"]);
}

@end
