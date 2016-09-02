//
//  CDTReplay429Interceptor.h
//  CDTDatastore
//
//  Created by tomblench on 23/06/2016.
//  Copyright © 2016 IBM Corporation. All rights reserved.
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
#import "CDTSessionCookieInterceptor.h"
#import "CDTLogging.h"



@interface CDTReplay429Interceptor : NSObject <CDTHTTPInterceptor>

+ (nonnull instancetype)interceptor;
- (nonnull instancetype)init;
- (nonnull instancetype)initWithSleep:(NSTimeInterval)sleep
                           maxRetries:(int)maxRetries NS_DESIGNATED_INITIALIZER;

@end
