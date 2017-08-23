//
//  OHHTTPStubsHelper.m
//
//  Copyright © 2017 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

// helper to sequence a number of stubbed responses

#import "OHHTTPStubsHelper.h"

@implementation OHHTTPStubsHelper

- (id) init
{
    if (self = [super init]) {
        _currentResponse = 0;
        _responses = [NSMutableArray array];
    }
    return self;
}

- (void) addResponse:(OHHTTPStubsResponseBlock)responseBlock
{
    [_responses addObject:responseBlock];
}
- (void) doStubsForHost:(NSString*)host
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *__nonnull request) {
        return [[request.URL host] isEqualToString:host];
    } withStubResponse:^OHHTTPStubsResponse *__nonnull(NSURLRequest *__nonnull request) {
        if (_currentResponse < _responses.count) {
            return [_responses objectAtIndex:_currentResponse++](request);
        } else {
            return [OHHTTPStubsResponse
                    responseWithJSONObject:@{
                                             @"error" : @"Failed",
                                             @"reason" : @"More requests were made than expected by the tests."
                                             }
                    statusCode:555
                    headers:@{}
                    ];
        }
    }];
}

@end
