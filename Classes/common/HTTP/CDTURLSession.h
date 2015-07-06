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

@class CDTURLSessionFilterContext;

/** 
 Façade class to NSURLSession, makes completion handlers run on
 the thread which created the object.
 */

@interface CDTURLSession : NSObject

/**
 * Initalises a CDTURLSession without a delegate. Calling this method will result in 
 * completionHandlers being called on the thread which called this method.
 **/
- (instancetype) init;

/**
 * Initalise a CDTURLSession.
 *
 * @param delegate an object that implements NSURLSessionDelegate protocol
 * @param thread the thread which callbacks should be run on
 **/
-(instancetype) initWithDelegate:(id<NSURLSessionDelegate>)delegate callbackThread:(NSThread*)thread;

/**
 * Performs a data task for a request.
 * 
 * @param request The request to make
 * @param completionHandler A block to call when the request completes
 *
 * @return returns a data task to used the make the request. `resume` needs to be called
 * in order for the task to start making the request.
 */
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

@end
