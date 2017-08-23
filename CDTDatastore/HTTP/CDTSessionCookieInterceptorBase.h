//
//  CDTSessionCookieInterceptorBase.h
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
#import "CDTHTTPInterceptor.h"

@interface CDTSessionCookieInterceptorBase : NSObject <CDTHTTPInterceptor>


/** Form encoded username and password. */
@property (nonnull, strong, nonatomic) NSData *sessionRequestBody;

/** Whether it looks worthwhile for us to make the session request (no bad failures so far). */
@property (nonatomic) BOOL shouldMakeSessionRequest;

/** NSURLSession to use to make calls to _session or _iam_session (shouldn't be same one we're intercepting). */
@property (nonnull, nonatomic, strong) NSURLSession *urlSession;

/** Current session cookie. */
@property (nullable, nonatomic, strong) NSArray<NSHTTPCookie *> *cookies;

- (nullable NSArray<NSHTTPCookie *> *)startNewSessionAtURL:(nonnull NSURL *)url
                                   withBody:(nonnull NSData *)body
                                    session:(nonnull NSURLSession *)session
                      sessionStartedHandler:(BOOL (^_Nonnull)(NSData *_Nonnull data))sessionStartedHandler;

- (nonnull NSURLSessionConfiguration*)customiseSessionConfig:(nonnull NSURLSessionConfiguration*)config;

- (BOOL)hasValidCookieWithName:(nonnull NSString*)cookieName forRequestURL:(nonnull NSURL*)requestUrl;
@end
