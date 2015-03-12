//
//  CDTQMatcherQueryExecutor.m
//  CloudantQueryObjc
//
//  Created by Michael Rhodes on 01/11/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import "CDTQMatcherQueryExecutor.h"

#import <CDTQQuerySqlTranslator.h>
#import <CDTQIndexManager.h>

#import <FMDB.h>

@implementation CDTQMatcherQueryExecutor

// MOD: indexesCoverQuery always false; return just a blank node (we don't execute it anyway).
- (CDTQChildrenQueryNode *)translateQuery:(NSDictionary *)query 
                                  indexes:(NSDictionary *)indexes 
                        indexesCoverQuery:(BOOL *)indexesCoverQuery
{
    *indexesCoverQuery = NO;
    return [[CDTQAndQueryNode alloc] init];
}

// MOD: just return all doc IDs rather than executing the query nodes
- (NSSet*)executeQueryTree:(CDTQQueryNode*)node inDatabase:(FMDatabase*)db
{
    NSDictionary *indexes = [CDTQIndexManager listIndexesInDatabase:db];
    
    NSMutableSet *docIdSet = [NSMutableSet set];
    NSSet *neededFields = [NSSet setWithObject:@"_id"];
    NSString *allDocsIndex = [CDTQQuerySqlTranslator chooseIndexForFields:neededFields
                                                              fromIndexes:indexes];
    
    NSString *tableName = [CDTQIndexManager tableNameForIndex:allDocsIndex];
    NSString *sql = @"SELECT _id FROM %@;";
    sql = [NSString stringWithFormat:sql, tableName];
    FMResultSet *rs = [db executeQuery:sql];
    while ([rs next]) {
        [docIdSet addObject:[rs stringForColumn:@"_id"]];
    }
    [rs close];
    
    return docIdSet;
}


@end
