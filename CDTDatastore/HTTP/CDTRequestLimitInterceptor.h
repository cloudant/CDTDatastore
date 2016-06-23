//
//  CDTRequestLimitInterceptor.h
//  CDTDatastore
//
//  Created by tomblench on 23/06/2016.
//  Copyright © 2016 IBM Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDTSessionCookieInterceptor.h"
#import "CDTLogging.h"



@interface CDTRequestLimitInterceptor : NSObject <CDTHTTPInterceptor>

+ (nonnull instancetype)interceptor;
- (nonnull instancetype)init;
- (nonnull instancetype)initWithSleep:(NSTimeInterval)sleep
                           maxRetries:(int)maxRetries NS_DESIGNATED_INITIALIZER;

@end
