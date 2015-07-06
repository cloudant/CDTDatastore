//
//  CDTURLSession.h
//  HttpTest
//
//  Created by tomblench on 12/03/2015.
//  Copyright (c) 2015 tomblench. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDTURLSessionResponseFilter.h"
#import "CDTURLSessionRequestFilter.h"

@class CDTURLSessionFilterContext;

/** 
 Façade class to NSURLSession with Request and Response filters.
 */

@interface CDTURLSession : NSObject

@property (nonatomic) int numberOfRetries;

- (instancetype) init;
- (void) addResponseFilter:(NSObject<CDTURLSessionResponseFilter>*)filter;
- (void) addRequestFilter:(NSObject<CDTURLSessionRequestFilter>*)filter;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithContext:(CDTURLSessionFilterContext*)context
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

@end
