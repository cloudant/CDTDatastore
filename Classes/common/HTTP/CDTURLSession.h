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
-(instancetype) initWithDelegate:(id<NSURLSessionDelegate>)delegate;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

@end
