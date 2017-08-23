//
//  CDTIAMSessionCookieInterceptorTests.m
//  CDTDatastore
//
//  Created by tomblench on 06/07/2017.
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


#import <XCTest/XCTest.h>
#import "CloudantSyncTests.h"
#import "CDTIAMSessionCookieInterceptor.h"
#import "CDTURLSession.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import <OHHTTPStubs/NSURLRequest+HTTPBodyTesting.h>
#import "OHHTTPStubsHelper.h"
#import "CDTLogging.h"
#import "TDJSON.h"

// expose properties so we can look at them
@interface CDTIAMSessionCookieInterceptor ()

@property (nonatomic) BOOL shouldMakeSessionRequest;
@property (nullable, strong, nonatomic) NSString *cookie;
@property (nonnull, nonatomic, strong) NSURLSession *URLSession;

@property NSURL *IAMTokenURL;


@end

static const NSString *testCookieHeaderValue =
@"IAMSession=a2ltc3RlYmVsOjUxMzRBQTUzOtiY2_IDUIdsTJEVNEjObAbyhrgz";

static const NSString *testCookieHeaderValue2 =
@"IAMSession=dG9tYmxlbmNoOjU5NTM0QzgyOhqHa60IlqPmGR8vTVIK-tzhopMR";

@interface CDTIAMSessionCookieInterceptorTests : CloudantSyncTests

@end

@implementation CDTIAMSessionCookieInterceptorTests

NSDictionary *iamToken1;
NSDictionary *iamToken2;

- (void)setUp {
    setenv("CDT_TEST_ENABLE_OHHTTPSTUBS", "1", true);
    CDTChangeLogLevel(CDTTD_REMOTE_REQUEST_CONTEXT, DDLogLevelDebug);
    CDTChangeLogLevel(CDTREPLICATION_LOG_CONTEXT, DDLogLevelDebug);
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    iamToken1 =
    @{
      @"access_token": @"eyJraWQiOiIyMDE3MDQwMi0wMDowMDowMCIsImFsZyI6IlJTMjU2In0.eyJpYW1faWQiOiJJQk1pZC0yNzAwMDdHRjBEIiwiaWQiOiJJQk1pZC0yNzAwMDdHRjBEIiwicmVhbG1pZCI6IklCTWlkIiwiaWRlbnRpZmllciI6IjI3MDAwN0dGMEQiLCJnaXZlbl9uYW1lIjoiVG9tIiwiZmFtaWx5X25hbWUiOiJCbGVuY2giLCJuYW1lIjoiVG9tIEJsZW5jaCIsImVtYWlsIjoidGJsZW5jaEB1ay5pYm0uY29tIiwic3ViIjoidGJsZW5jaEB1ay5pYm0uY29tIiwiYWNjb3VudCI6eyJic3MiOiI1ZTM1ZTZhMjlmYjJlZWNhNDAwYWU0YzNlMWZhY2Y2MSJ9LCJpYXQiOjE1MDA0NjcxMDIsImV4cCI6MTUwMDQ3MDcwMiwiaXNzIjoiaHR0cHM6Ly9pYW0ubmcuYmx1ZW1peC5uZXQvb2lkYy90b2tlbiIsImdyYW50X3R5cGUiOiJ1cm46aWJtOnBhcmFtczpvYXV0aDpncmFudC10eXBlOmFwaWtleSIsInNjb3BlIjoib3BlbmlkIiwiY2xpZW50X2lkIjoiZGVmYXVsdCJ9.XAPdb5K4n2nYih-JWTWBGoKkxTXM31c1BB1g-Ciauc2LxuoNXVTyz_mNqf1zQL07FUde1Cb_dwrbotjickNcxVPost6byQztfc0mRF1x2S6VR8tn7SGiRmXBjLofkTh1JQq-jutp2MS315XbTG6K6m16uYzL9qfMnRvQHxsZWErzfPiJx-Trg_j7OX-qNFjdNUGnRpU7FmULy0r7RxLd8mhG-M1yxVzRBAZzvM63s0XXfMnk1oLi-BuUUTqVOdrM0KyYMWfD0Q72PTo4Exa17V-R_73Nq8VPCwpOvZcwKRA2sPTVgTMzU34max8b5kpTzVGJ6SXSItTVOUdAygZBng",
      @"refresh_token": @"MO61FKNvVRWkSa4vmBZqYv_Jt1kkGMUc-XzTcNnR-GnIhVKXHUWxJVV3RddE8Kqh3X_TZRmyK8UySIWKxoJ2t6obUSUalPm90SBpTdoXtaljpNyormqCCYPROnk6JBym72ikSJqKHHEZVQkT0B5ggZCwPMnKagFj0ufs-VIhCF97xhDxDKcIPMWG02xxPuESaSTJJug7e_dUDoak_ZXm9xxBmOTRKwOxn5sTKthNyvVpEYPE7jIHeiRdVDOWhN5LomgCn3TqFCLpMErnqwgNYbyCBd9rNm-alYKDb6Jle4njuIBpXxQPb4euDwLd1osApaSME3nEarFWqRBzhjoqCe1Kv564s_rY7qzD1nHGvKOdpSa0ZkMcfJ0LbXSQPs7gBTSVrBFZqwlg-2F-U3Cto62-9qRR_cEu_K9ZyVwL4jWgOlngKmxV6Ku4L5mHp4KgEJSnY_78_V2nm64E--i2ZA1FhiKwIVHDOivVNhggE9oabxg54vd63glp4GfpNnmZsMOUYG9blJJpH4fDX4Ifjbw-iNBD7S2LRpP8b8vG9pb4WioGzN43lE5CysveKYWrQEZpThznxXlw1snDu_A48JiL3Lrvo1LobLhF3zFV-kQ=",
      @"token_type": @"Bearer",
      @"expires_in": @3600,
      @"expiration": @1500470702
      };
    iamToken2 =
    @{
      @"access_token": @"eyJraWQiOiIyMDE3MDQwMi0wMDowMDowMCIsImFsZyI6IlJTMjU2In0.eyJpYW1faWQiOiJJQk1pZC0yNzAwMDdHRjBEIiwiaWQiOiJJQk1pZC0yNzAwMDdHRjBEIiwicmVhbG1pZCI6IklCTWlkIiwiaWRlbnRpZmllciI6IjI3MDAwN0dGMEQiLCJnaXZlbl9uYW1lIjoiVG9tIiwiZmFtaWx5X25hbWUiOiJCbGVuY2giLCJuYW1lIjoiVG9tIEJsZW5jaCIsImVtYWlsIjoidGJsZW5jaEB1ay5pYm0uY29tIiwic3ViIjoidGJsZW5jaEB1ay5pYm0uY29tIiwiYWNjb3VudCI6eyJic3MiOiI1ZTM1ZTZhMjlmYjJlZWNhNDAwYWU0YzNlMWZhY2Y2MSJ9LCJpYXQiOjE1MDA0NjcxMTEsImV4cCI6MTUwMDQ3MDcxMSwiaXNzIjoiaHR0cHM6Ly9pYW0ubmcuYmx1ZW1peC5uZXQvb2lkYy90b2tlbiIsImdyYW50X3R5cGUiOiJ1cm46aWJtOnBhcmFtczpvYXV0aDpncmFudC10eXBlOmFwaWtleSIsInNjb3BlIjoib3BlbmlkIiwiY2xpZW50X2lkIjoiZGVmYXVsdCJ9.wJ5Glsvee3xRbfxr847pNgVj-U_ZLLzOiScHcjkrHk0jQdg8D4KurAV1QGa_MwWzd_QxS55lNqCzi6HV1p3kSyjcdJSGe-l-B3_xjw-7Q3BMoPjcO-X1mNYsKQyCtSAJsuByCYQVPoNKuBifsQcds65mKh87gUtc00vP5J-vzdYpzkrjncFO3lzJJwYSnbqFaAPtNnEYwEEIpS0n9H4mgHiLqletzYs9acggssxZpUl2wdkUaQ_diuTJg-u2o6Oy3aVJCWV78DIc3NVwgQCuJ40as6QpFPWluXJmfgdW5lFkQ_etieI9JDgXk_HQUpYcj0Droec6wTXEGUYWjukhsw",
      @"refresh_token": @"M0oCn5XLXUWAFUSqC7FRv1d83-SOfPvYmKKRdZpT33C81KsTaZx3Y3jMXRGkR1sIAohEm-gkpwGQcm1I_lfs5zlqwaKlsLOv4jvjvjiaPFwoU7QP62bHWGsq0j-RNN-_kHXsp3G1R7AtndZL0XQ4se4Jlgt68Cw3_YyEcxS6E65iTv1hZ9lg1EjJqzFLd4ArQVT6gFCpSaRaH2ilie4hat5ZFI2JALHPzVnBlRBqeIUferQOL6Yw2b_Z9TvYa6AaqOsQzI5ma2yIQTw6tzjrc5xXqnqnkH566pNlY8pKvETvCsdLgEclMoa8zoe9SAXDFEIl7svNMRG9FsoR7G4rwojs2BawDPPwkEcm6aC1K5azX23GbnekhvNfXloASWc2ETerN2RxYRZNnFnO4f0enCNReMhoPCUBObgO6iq0a56VslRTT-BHYBCax_YklBz9acbhJnF-C9PWjyrYwZHFajMhpFjOmY3hlrQXVXtjOqKs5WbMhpQ8BWN5KBUDYY7F7OMvv4bYTF7kfu5Uc_ge9_Nj4EGvPwA6vehvZjSj-0td6D32p2zMDmu_yoTLRpv6N7u5BRA5_PmhH_hsffXSKX5fDNL_CqGaNvcI5tVBry8=",
      @"token_type": @"Bearer",
      @"expires_in": @3600,
      @"expiration": @1500470711
      };
}

- (void)tearDown {
    unsetenv("CDT_TEST_ENABLE_OHHTTPSTUBS");
    [OHHTTPStubs removeAllStubs];
}

/**
 * Test normal IAM token and IAM session request path
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get IAM token followed by session cookie
 * - GET now proceeds as normal, expected cookie value is sent in header
 */
- (void)testIAMTokenAndCookieSuccessful
{
 
    OHHTTPStubsHelper *IAMTokenHelper = [[OHHTTPStubsHelper alloc] init];
    
    // IAM token
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken1
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    
    [IAMTokenHelper doStubsForHost:@"iam.bluemix.net"];
    
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _iam_session endpoint, return cookie in header
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken1[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
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
                                           testCookieHeaderValue]
                          }];
    }];
    
    // get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    [helper doStubsForHost:@"username.cloudant.com"];
    
    CDTIAMSessionCookieInterceptor *interceptor =
    [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:@"apikey"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username.cloudant.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:[NSThread currentThread] requestInterceptors:@[interceptor] sessionConfigDelegate: nil];
    
    CDTURLSessionTask *task = [session dataTaskWithRequest:request taskDelegate:nil];
    [task resume];
    while ([task state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    XCTAssert([IAMTokenHelper currentResponse] == 1);
    XCTAssert([helper currentResponse] == 2);
}

/**
 * Test IAM token and cookie flow, where session expires and is successfully renewed:
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get IAM token followed by session cookie
 * - GET now proceeds as normal, expected cookie value is sent in header
 * - second GET on cloudant server, re-using session cookie
 * - third GET on cloudant server, cookie invalid, get IAM token and session cookie and replay
 *   request
 */
- (void)testIAMTokenAndCookieWithExpirySuccessful
{
    OHHTTPStubsHelper *IAMTokenHelper = [[OHHTTPStubsHelper alloc] init];
    
    // first token
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken1
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    
    // second token
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken2
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    [IAMTokenHelper doStubsForHost:@"iam.bluemix.net"];
    
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _iam_session endpoint, return cookie in header
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken1[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);

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
                                           testCookieHeaderValue]
                          }];
    }];
    
    // get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // 2nd get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // 3nd get resource fails, pretend cookie invalid by returning 401
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"error":@"credentials_expired"} statusCode:401 headers:@{}];
    }];
    
    // call to _iam_session endpoint to refresh cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken2[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);

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
    // replay of 3rd get resource succeeds with new cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue2 isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
        
    }];
    [helper doStubsForHost:@"username1.cloudant.com"];
    
    CDTIAMSessionCookieInterceptor *interceptor =
    [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:@"apikey"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username1.cloudant.com/animaldb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:[NSThread currentThread] requestInterceptors:@[interceptor] sessionConfigDelegate:nil];
    
    CDTURLSessionTask *task = [session dataTaskWithRequest:request taskDelegate:nil];
    [task resume];
    while ([task state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    CDTURLSessionTask *task2 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task2 resume];
    while ([task2 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    CDTURLSessionTask *task3 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task3 resume];
    while ([task3 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    XCTAssert([IAMTokenHelper currentResponse] == 2);
    XCTAssert([helper currentResponse] == 6);
}


/**
 * Test IAM token and cookie flow, where session expires and subsequent IAM token fails:
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get IAM token followed by session cookie
 * - GET now proceeds as normal, expected cookie value is sent in header
 * - second GET on cloudant server, re-using session cookie
 * - third GET on cloudant server, cookie invalid, subsequent IAM token fails, no more requests
 *   are made
 */

- (void)testIAMRenewalFailureOnIamToken
{
    OHHTTPStubsHelper *IAMTokenHelper = [[OHHTTPStubsHelper alloc] init];
    
    // first one succeeds
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken1
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    
    // IAM goes down - could be anything non 200
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:@{@"error" : @"error"}
                    statusCode:401
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    
    [IAMTokenHelper doStubsForHost:@"iam.bluemix.net"];
    
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _iam_session endpoint, return cookie in header
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken1[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
        
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
                                           testCookieHeaderValue]
                          }];
    }];
    
    // get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // 2nd get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // 3rd get resource fails, pretend cookie invalid by returning 401
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"error":@"credentials_expired"} statusCode:401 headers:@{}];
    }];
    
    // 3rd get is re-attempted but will fail - request interceptors can't stop "in flight" requests
    // but we didn't manage to get the IAM token so we don't have a valid cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        // The old cookie is still sent on the request because of the replay
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"error":@"credentials_expired"} statusCode:401 headers:@{}];
    }];
    
    [helper doStubsForHost:@"username1.cloudant.com"];
    
    CDTIAMSessionCookieInterceptor *interceptor =
    [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:@"apikey"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username1.cloudant.com/animaldb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:[NSThread currentThread] requestInterceptors:@[interceptor] sessionConfigDelegate:nil];
    
    CDTURLSessionTask *task = [session dataTaskWithRequest:request taskDelegate:nil];
    [task resume];
    while ([task state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    CDTURLSessionTask *task2 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task2 resume];
    while ([task2 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    CDTURLSessionTask *task3 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task3 resume];
    while ([task3 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    XCTAssert(interceptor.cookies == nil);
    XCTAssert([IAMTokenHelper currentResponse] == 2);
    XCTAssert([helper currentResponse] == 5);
}

/**
 * Test IAM token and cookie flow, where session expires and subsequent session cookie fails:
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get IAM token followed by session cookie
 * - GET now proceeds as normal, expected cookie value is sent in header
 * - second GET on cloudant server, re-using session cookie
 * - third GET on cloudant server, cookie expired, get IAM token, subsequent session cookie
 *   request fails, no more requests are made
 */

- (void) testIAMRenewalFailureOnSessionCookie
{
    
    OHHTTPStubsHelper *IAMTokenHelper = [[OHHTTPStubsHelper alloc] init];
    
    // first IAM token
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken1
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    
    // second IAM token
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken2
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{} statusCode:400 headers:@{}];
        }
    }];
    
    [IAMTokenHelper doStubsForHost:@"iam.bluemix.net"];
    
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _iam_session endpoint, return cookie in header
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken1[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
        
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
                                           testCookieHeaderValue]
                          }];
    }];
    
    // get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // 2nd get resource successfully using cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:200 headers:@{}];
    }];
    
    // 3rd get resource fails, cookie expired
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"error":@"credentials_expired"} statusCode:401 headers:@{}];
    }];
    
    // call to _iam_session endpoint with updated token fails
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken2[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);

        return [OHHTTPStubsResponse responseWithJSONObject:@{@"error":@"credentials_expired"} statusCode:401 headers:@{}];
    }];
    
    // 3rd get is re-attempted but will fail - request interceptors can't stop "in flight" requests
    // but we didn't manage to get the IAM token so we don't have a valid cookie
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        XCTAssert([request.HTTPMethod isEqualToString:@"GET"]);
        // The old cookie is still sent on the request because of the replay
        XCTAssert([testCookieHeaderValue isEqualToString: request.allHTTPHeaderFields[@"Cookie"]]);
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"error":@"credentials_expired"} statusCode:401 headers:@{}];
    }];
    
    
    [helper doStubsForHost:@"username1.cloudant.com"];
    
    CDTIAMSessionCookieInterceptor *interceptor =
    [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:@"apikey"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username1.cloudant.com/animaldb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:[NSThread currentThread] requestInterceptors:@[interceptor] sessionConfigDelegate:nil];
    
    CDTURLSessionTask *task = [session dataTaskWithRequest:request taskDelegate:nil];
    [task resume];
    while ([task state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    CDTURLSessionTask *task2 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task2 resume];
    while ([task2 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    CDTURLSessionTask *task3 = [session dataTaskWithRequest:request taskDelegate:nil];
    [task3 resume];
    while ([task3 state] != NSURLSessionTaskStateCompleted) {
        [NSThread sleepForTimeInterval:1.0];
    }
    
    XCTAssert(interceptor.cookies == nil);
    XCTAssert([IAMTokenHelper currentResponse] == 2);
    XCTAssert([helper currentResponse] == 6);
    
}

/**
 * Test IAM token and cookie flow, where session is nearly expired and we pre-emptively renew.
 * - GET a resource on the cloudant server
 * - Cookie jar empty, so get IAM token followed by session cookie with short expiry time
 * - GET now proceeds as normal, expected cookie value is sent in header
 * - second GET on cloudant server, cookie is nearly expired so should renew
 * - IAM token followed by session cookie, followed by replay of request with new cookie.
 * - third GET on cloudant server with new valid cookie.
 */

- (void)testIAMInterceptorRenewsEarly
{
    OHHTTPStubsHelper *IAMTokenHelper = [[OHHTTPStubsHelper alloc] init];
    
    // IAM token
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken1
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:400 headers:@{}];
        }
    }];
    
    // IAM token renewal
    [IAMTokenHelper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if ([request.HTTPMethod isEqualToString:@"POST"]) {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:iamToken2
                    statusCode:200
                    headers:@{}];
        } else {
            XCTFail(@"Unexpected HTTP Method");
            return [OHHTTPStubsResponse responseWithJSONObject:@{@"ok" : @(YES)} statusCode:400 headers:@{}];
        }
    }];
    
    [IAMTokenHelper doStubsForHost:@"iam.bluemix.net"];
    
    OHHTTPStubsHelper *helper = [[OHHTTPStubsHelper alloc] init];
    
    // call to _iam_session endpoint, return cookie in header with 1 minute life
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken1[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
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
    
    // renewal call to _iam_session endpoint, return cookie in header with 1 day life
    [helper addResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        
        XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
        XCTAssert([[TDJSON JSONObjectWithData:request.OHHTTPStubs_HTTPBody options:0 error:nil][@"access_token"] isEqualToString:iamToken2[@"access_token"]]);
        XCTAssert([request.URL.lastPathComponent isEqualToString:@"_iam_session"]);
        XCTAssert([request.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
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
    
    [helper doStubsForHost:@"username.cloudant.com"];
    
    CDTIAMSessionCookieInterceptor *interceptor =
    [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:@"apikey"];
    // create a context with a request which we can use
    NSURL *url = [NSURL URLWithString:@"http://username.cloudant.com"];
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
    
    XCTAssert([IAMTokenHelper currentResponse] == 2);
    XCTAssert([helper currentResponse] == 5);
}

@end
