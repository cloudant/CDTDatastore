//
//  CDTQEitherMatcher.m
//  CloudantQueryObjc
//
//  Created by Rhys Short on 21/01/2015.
//  Copyright (c) 2015 IBM Corp. All rights reserved.
//

#import "CDTQEitherMatcher.h"

EXPMatcherImplementationBegin(isEqualToEither, (id expected,id otherExpected))

match(^BOOL {
    
    return [actual isEqual:expected] || [actual isEqual:otherExpected];
    
});

failureMessageForTo(^NSString * {
    return [NSString stringWithFormat:@"expected: %@ or %@, got values %@ some are missing",
            expected,
            otherExpected,
            actual];
    
});

failureMessageForNotTo(^NSString * {
    return [NSString stringWithFormat:@"expected neither: %@ or %@, got values %@",
            expected,
            otherExpected,
            actual];
    
});

EXPMatcherImplementationEnd
