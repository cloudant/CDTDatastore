//
//  CDTURLSessionTask.h
//
//
//  Created by Rhys Short on 20/08/2015.
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

#import <Foundation/Foundation.h>
#import "CDTMacros.h"

NS_ASSUME_NONNULL_BEGIN

@class CDTURLSession;

@protocol CDTURLSessionTaskDelegate
- (void)receivedData:(nullable NSData *)data;
- (void)receivedResponse:(nullable NSURLResponse *)response;
- (void)requestDidError:(nullable NSError *)error;
@end

@interface CDTURLSessionTask : NSObject

@property (nullable, nonatomic, weak) NSObject<CDTURLSessionTaskDelegate> *delegate;

/*
 * The current state of the task within the session.
 */
@property (readonly) NSURLSessionTaskState state;

/**
 Don't call this initialiser; it will throw an exception.
 */
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;

/*
 * Initalises an instance of CDTURLSessionTask
 *
 *  @param task the NSURLSessionTask to be wrapped
 */
- (instancetype)initWithSession:(CDTURLSession *)session
                        request:(NSURLRequest *)request
                   interceptors:(nullable NSArray *)interceptors NS_DESIGNATED_INITIALIZER;

/*
 * Resumes the execution of this task
 */
- (void)resume;

/* 
 * Marks the task as canceled, and triggers the delegate method
 * URLSession:task:didCompleteWithError:
 */
- (void)cancel;

/**
 * Process the given response. If the when we process the response with the interceptors
 * the request does not need to be retried, we process the response on the given thread, otherwise
 * we retry the request.
 *
 * @param response the response to process
 * @param the thread on which to process the response if the interceptors do not indicate
 *        that we need to retry the request.
 */
- (void)processResponse:(NSURLResponse *)response onThread:(NSThread *)thread;

/**
 * Process the given error. If the when we process the error with the interceptors
 * the request does not need to be retried, we process the error on the given thread, otherwise
 * we retry the request.
 *
 * @param error the error to process
 * @param the thread on which to process the error if the interceptors do not indicate
 *        that we need to retry the request.
 */
- (void)processError:(NSError *)error onThread:(NSThread *)thread;

- (void)completedThread:(NSThread *)thread;

- (void)processData:(nullable NSData*)data;

@end

NS_ASSUME_NONNULL_END
