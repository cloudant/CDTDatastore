//
//  CDTQSQLOnlyIndexManager.m
//  CloudantQueryObjc
//
//  Created by Michael Rhodes on 01/11/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import "CDTQSQLOnlyIndexManager.h"

#import "CDTQSQLOnlyQueryExecutor.h"

@implementation CDTQSQLOnlyIndexManager

+ (CDTQIndexManager *)managerUsingDatastore:(CDTDatastore *)datastore
                                      error:(NSError *__autoreleasing *)error
{
    return [[CDTQSQLOnlyIndexManager alloc] initUsingDatastore:datastore error:error];
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

    CDTQSQLOnlyQueryExecutor *queryExecutor =
        [[CDTQSQLOnlyQueryExecutor alloc] initWithDatabase:self.database datastore:self.datastore];
    return [queryExecutor find:query
                  usingIndexes:[self listIndexes]
                          skip:skip
                         limit:limit
                        fields:fields
                          sort:sortDocument];
}

@end
