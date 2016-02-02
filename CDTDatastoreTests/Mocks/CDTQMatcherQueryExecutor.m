//
//  CDTQMatcherQueryExecutor.m
//  CloudantQueryObjc
//
//  Created by Michael Rhodes on 01/11/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import "CDTQMatcherQueryExecutor.h"

#import <CDTDatastore/CDTQQuerySqlTranslator.h>
#import <CDTDatastore/CDTQIndexManager.h>
#import <CDTDatastore/CDTDatastore.h>

#import <FMDB/FMDB.h>

@interface CDTQMatcherQueryExecutor ()

@property (nonatomic, strong) NSSet *docIds;

@end

@implementation CDTQMatcherQueryExecutor

- (instancetype)initWithDatabase:(FMDatabaseQueue *)database datastore:(CDTDatastore *)datastore
{
    self = [super initWithDatabase:database datastore:datastore];
    _docIds = [NSSet setWithArray:[datastore getAllDocumentIds]];
    return self;
}

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
    return _docIds;
}

@end
