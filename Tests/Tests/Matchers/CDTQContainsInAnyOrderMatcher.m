//
//  CDTQContainsInAnyOrderMatcher.m
//  CloudantSync
//
//  Created by Al Finkelstein on 06/09/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <Foundation/Foundation.h>
#import "CDTQContainsInAnyOrderMatcher.h"

EXPMatcherImplementationBegin(containsInAnyOrder,(NSArray * expected))

BOOL actualIsNil = (actual == nil);
BOOL expectedIsNil = (expected == nil);

prerequisite(^BOOL {
    return !(actualIsNil || expectedIsNil);
});


match(^BOOL {

    BOOL matches = YES;
    
    if([actual count] != [expected count]){
        return NO;
    }
    
    for(id element in expected){
        if([actual containsObject:element]){
            continue;
        }
        matches = NO;
        break;
    }
    
    return matches;
    
});

failureMessageForTo(^NSString * {
    if (actualIsNil) {
        return @"the actual value is nil/null";
    } else if (expectedIsNil) {
        return @"the expected value is nil/null";
    } else {
        return [NSString stringWithFormat:@"expected values: %@, got values %@", expected, actual];
    }
    
    
});

failureMessageForNotTo(^NSString * {
    if (actualIsNil) {
        return @"the actual value is nil/null";
    } else if (expectedIsNil) {
        return @"the expected value is nil/null";
    } else {
        return [NSString stringWithFormat:@"expected values: %@, got values %@", expected, actual];
    }
    
});

EXPMatcherImplementationEnd