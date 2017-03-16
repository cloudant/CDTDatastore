//
//  CDTHTTPInterceptorContext.m
//  
//
//  Created by Rhys Short on 17/08/2015.
//  Copyright © 2015, 2016 IBM Corporation. All rights reserved.
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

@interface CDTHTTPInterceptorContext ()
@property NSMutableDictionary<NSString *, NSObject *> *internalState;
@end

@implementation CDTHTTPInterceptorContext


-(instancetype)init {
    NSAssert(NO, @"Call the designated initialiser");
    return nil;
}

- (instancetype)initWithRequest:(NSMutableURLRequest*)request {
    return [self initWithRequest:request state:[NSMutableDictionary dictionary]];
}

- (instancetype)initWithRequest:(NSMutableURLRequest*)request
                          state:(NSMutableDictionary*)state {
    NSParameterAssert(request);
    self = [super init];
    
    if (self) {
        _request = request;
        _shouldRetry = NO;
        _internalState = state;
    }
    return self;
}

- (NSObject*)stateForKey:(NSString*)key {
    return self.internalState[key];
}
- (void)setState:(NSObject *)value forKey:(NSString *)key
{
    [self.internalState setValue:value forKey:key];
}

- (NSDictionary *)state { return [self.internalState copy]; }
@end
