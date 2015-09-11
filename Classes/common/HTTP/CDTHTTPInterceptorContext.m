//
//  CDTHTTPInterceptorContext.m
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

#import "CDTHTTPInterceptorContext.h"

@implementation CDTHTTPInterceptorContext

-(instancetype)init {
    NSAssert(NO, @"Call the designated initaliser");
    return nil;
}

- (instancetype)initWithRequest:(NSMutableURLRequest *)request {
    NSParameterAssert(request);
    self = [super init];
    
    if (self) {
        _request = request;
        _shouldRetry = NO;
    }
    return self;
}

@end
