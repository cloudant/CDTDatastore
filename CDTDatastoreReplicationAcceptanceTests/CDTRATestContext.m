//
//  CDTRATestContext.m
//  ReplicationAcceptance
//
//  Created by Rhys Short on 09/09/2015.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTRATestContext.h"
#import "XCTest/XCTest.h"

@implementation CDTRATestContext

- (instancetype)initWithContext:(CDTHTTPInterceptorContext *)context
{
    self = [super initWithRequest:context.request state:[context.state mutableCopy]];
    if (self) {
        self.response = context.response;
    }
    return self;
}

@end

@implementation TestRequestPiplineInterceptor1

- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    return [[CDTRATestContext alloc] initWithContext:context];
}

@end

@implementation TestRequestPiplineInterceptor2

- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    self.expectedContextFound = [context class] == [CDTRATestContext class];
    return context;
}

@end

@implementation TestResponsePiplineInterceptor1

- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    return [[CDTRATestContext alloc] initWithContext:context];
}

@end

@implementation TestResponsePiplineInterceptor2

- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    self.expectedContextFound = [context class] == [CDTRATestContext class];
    return context;
}

@end
