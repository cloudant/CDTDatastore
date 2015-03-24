//
//  CDTQSQLOnlyQueryExecutor.m
//  CloudantQueryObjc
//
//  Created by Michael Rhodes on 01/11/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import "CDTQSQLOnlyQueryExecutor.h"
#import <CDTQUnindexedMatcher.h>

@implementation CDTQSQLOnlyQueryExecutor

// MOD: SQL only, so never run matcher
- (CDTQUnindexedMatcher *)matcherForIndexCoverage:(BOOL)indexesCoverQuery
                                         selector:(NSDictionary *)selector
{
    return nil;
}

@end
