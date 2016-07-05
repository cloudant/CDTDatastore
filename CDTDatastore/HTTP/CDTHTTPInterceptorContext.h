//
//  CDTURLSessionFilterContext.h
//  
//
//  Created by Rhys Short on 17/08/2015.
//  Copyright (c) 2015 IBM Corp.
//
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

@interface CDTHTTPInterceptorContext : NSObject

@property (readwrite, nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic) BOOL shouldRetry;
@property (nullable, readwrite, nonatomic, strong) NSHTTPURLResponse *response;
/**
 * For storing arbitrary per-context state
 * NOTE: Users are strongly encouranged to use unique keys by ensuring keys are prefixed, eg
 * com.mycompany.MyInterceptor.foo, com.mycompany.MyInterceptor.bar, where:
 * - com.company is the reversed internet domain name
 * - MyInterceptor is the name of the interceptor class
 * - foo and bar describe the values being stored.
 */
@property (readwrite, nonatomic, strong) NSMutableDictionary<NSString*, NSObject*> *state;

/**
 *  Unavaiable, use -initWithRequest
 *
 *  Calling this method from your code will result in
 *  an exception being thrown.
 **/
- (instancetype)init UNAVAILABLE_ATTRIBUTE;

/**
 *  Initalizes a CDTURLSessionInterceptorContext
 *
 *  This is equivalent to calling initWithRequest:request:[NSMutableDictionary dictionary]
 *
 *  @param request the request this context should represent
 *
 **/
- (instancetype)initWithRequest:(NSMutableURLRequest *)request;

/**
 *  Initalizes a CDTURLSessionInterceptorContext
 *
 *  NOTE: electing not to copy the state of a previous interceptor may cause issues (especially for 
 *  interceptors which share state between Request and Response contexts).
 *
 *  @param request the request this context should represent
 *  @param state the initial state of the interceptor pipeline, as key/value pairs
 **/
- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                          state:(NSMutableDictionary *)state NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
