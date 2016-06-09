//
//  CDTURLSession.h
//
//  Created by Rhys Short.
//  Copyright (c) 2015 IBM Corp.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import "CDTURLSessionTask.h"
#import "CDTMacros.h"
#import "CDTNSURLSessionConfigurationDelegate.h"

@class CDTHTTPInterceptorContext;

/**
 Façade class to NSURLSession, makes completion handlers run on
 the thread which created the object.
 */

NS_ASSUME_NONNULL_BEGIN

@interface CDTURLSession : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

/**
 * Initalises a CDTURLSession without a delegate and an empty array of interceptors. Calling this 
 * method will result in completionHandlers being called on the thread which called this method.
 **/
- (instancetype)init;

/**
 * Initalise a CDTURLSession.
 *
 * @param thread the thread which callbacks should be run on.
 * @param requestInterceptors array of interceptors that should be run before each request is made.
 * @param sessionConfigDelegate the delegate used to customise the NSURLSessionConfiguration.
 **/
- (instancetype)initWithCallbackThread:(NSThread *)thread
                   requestInterceptors:(nullable NSArray *)requestInterceptors
                 sessionConfigDelegate:(nullable NSObject<CDTNSURLSessionConfigurationDelegate> *)
                                           sessionConfigDelegate NS_DESIGNATED_INITIALIZER;

/**
 * Performs a data task for a request.
 * 
 * @param request The request to make
 * @param taskDelegate The CDTURLSessionTaskDelegate to invoke to handle responses to the request.
 *
 * @return returns a task to used the make the request. `resume` needs to be called
 * in order for the task to start making the request.
 */
- (CDTURLSessionTask *)dataTaskWithRequest:(NSURLRequest *)request
                              taskDelegate:
                                  (nullable NSObject<CDTURLSessionTaskDelegate> *)taskDelegate;

/**
 * Creates a NSURLSessionDataTask for the given request and associates the given CDTURLSessionTask
 * with it.
 *
 * @param request The request to make
 * @param task The CDTURLSessionTask to be associated with the returned NSURLSessionDataTask.
 *
 * @return returns an NSURLSessionDataTask.
 */
- (NSURLSessionDataTask *)createDataTaskWithRequest:(NSURLRequest *)request
                                 associatedWithTask:(CDTURLSessionTask *)task;

/**
 * Disassociates an NSURLSessionDataTask from any CDTURLSessionTask it was previously associated
 * with via a call to NSURLSessionDataTask:createDataTaskWithRequest:associatedWithTask:
 * The given task is also cancelled since once it is disassociated from the CDTURLSessionTask any
 * response will not be processed.
 *
 * @param task The NSURLSessionDataTask to be disassociated from any CDTURLSessionTask.
 */
- (void)disassociateTask:(NSURLSessionDataTask *)task;

- (void) waitForFreeSlot;

@end

NS_ASSUME_NONNULL_END
