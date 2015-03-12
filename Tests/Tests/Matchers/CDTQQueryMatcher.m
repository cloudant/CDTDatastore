//
//  CDTQQueryMatcher.m
//  CloudantQueryObjc
//
//  Created by Rhys Short on 21/01/2015.
//  Copyright (c) 2015 IBM Corp. All rights reserved.
//

#import "CDTQQueryMatcher.h"

EXPMatcherImplementationBegin(beTheSameQueryAs, (NSDictionary * expected))

prerequisite(^BOOL {
    
    return [actual isKindOfClass:[NSDictionary class]];
    
});


match(^BOOL {
    
    BOOL matches = YES;
    NSDictionary * actualQuery = (NSDictionary*)actual;
    
    //first we check if dictionary has the same number of keys
    if([actualQuery count] != [expected count]){
        return NO;
    }

    for (id key in expected){
        if([actualQuery objectForKey:key]){
            //we have a key for that object
            id object = [actualQuery objectForKey:key];
            
            if([object isKindOfClass:[NSArray class]] && [[expected objectForKey:key]isKindOfClass:[NSArray class]]){
                
                NSArray * expectedArray = (NSArray *)[expected objectForKey:key];
                NSArray * actualArray = (NSArray *)[actualQuery objectForKey:key];
                
                if([expectedArray count] == [actualArray count]){
                    for(id element in expectedArray){
                        if(![actualArray containsObject:element]){
                            matches = NO;
                            break;
                        }
                    }
                }
                
            } else {
                if(![object isEqual:[expected objectForKey:key]]){
                    matches = NO;
                    break;
                }
            }
        } else {
            matches = NO;
            break;
        }
    }
    
    
    
    return matches;
    
});

failureMessageForTo(^NSString * {
        return [NSString stringWithFormat:@"expected values: %@, got values %@ some are missing",
                expected,
                actual];
    
});

failureMessageForNotTo(^NSString * {
        return [NSString stringWithFormat:@"expected values: %@, got values %@",
                expected,
                actual];
    
});

EXPMatcherImplementationEnd
