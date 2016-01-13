//
//  CDTQMatcherIndexManager.m
//  CloudantQueryObjc
//
//  Created by Michael Rhodes on 01/11/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import "CDTQMatcherIndexManager.h"

#import "CDTQMatcherQueryExecutor.h"

@implementation CDTQMatcherIndexManager

+ (CDTQIndexManager *)managerUsingDatastore:(CDTDatastore *)datastore
                                      error:(NSError *__autoreleasing *)error
{
    return [[CDTQMatcherIndexManager alloc] initUsingDatastore:datastore error:error];
}

- (CDTQResultSet *)find:(NSDictionary *)query
                   skip:(NSUInteger)skip
                  limit:(NSUInteger)limit
                 fields:(NSArray *)fields
                   sort:(NSArray *)sortDocument
{
    if (!query) {
        return nil;
    }

    if (![self updateAllIndexes]) {
        return nil;
    }

    CDTQMatcherQueryExecutor *queryExecutor =
        [[CDTQMatcherQueryExecutor alloc] initWithDatabase:self.database datastore:self.datastore];
    return [queryExecutor find:query
                  usingIndexes:[self listIndexes]
                          skip:skip
                         limit:limit
                        fields:fields
                          sort:sortDocument];
}

@end
