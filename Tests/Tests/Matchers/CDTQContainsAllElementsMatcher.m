//
//  CDTQContainsAllElementsMatcher.m
//  CloudantQueryObjc
//
//  Created by Rhys Short on 21/01/2015.
//  Copyright (c) 2015 IBM Corp.  All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDTQContainsAllElementsMatcher.h"

EXPMatcherImplementationBegin(containsAllElements,(NSArray * expected))

BOOL actualIsNil = (actual == nil);
BOOL expectedIsNil = (expected == nil);

prerequisite(^BOOL {
    return !(actualIsNil || expectedIsNil);
});


match(^BOOL {

    BOOL matches = YES;
    
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
        return [NSString stringWithFormat:@"expected values: %@, got values %@ some are missing",
                expected,
                actual];
    }
    
    
});

failureMessageForNotTo(^NSString * {
    if (actualIsNil) {
        return @"the actual value is nil/null";
    } else if (expectedIsNil) {
        return @"the expected value is nil/null";
    } else {
        return [NSString stringWithFormat:@"expected values: %@, got values %@ some are not missing",
                expected,
                actual];
    }
    
});

EXPMatcherImplementationEnd