//
//  CDTQIndexCreator.m
//
//  Created by Michael Rhodes on 29/09/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTQIndexCreator.h"

#import "CDTQIndexManager.h"
#import "CDTQIndexUpdater.h"
#import "CDTQLogging.h"

#import "CloudantSync.h"
#import "FMDB.h"

@interface CDTQIndexCreator ()

@property (nonatomic, strong) FMDatabaseQueue *database;
@property (nonatomic, strong) CDTDatastore *datastore;

@end

@implementation CDTQIndexCreator

- (instancetype)initWithDatabase:(FMDatabaseQueue *)database datastore:(CDTDatastore *)datastore
{
    self = [super init];
    if (self) {
        _database = database;
        _datastore = datastore;
    }
    return self;
}

#pragma mark Convenience methods

+ (NSString *)ensureIndexed:(NSArray * /* NSString */)fieldNames
                   withName:(NSString *)indexName
                       type:(NSString *)indexType
                 inDatabase:(FMDatabaseQueue *)database
              fromDatastore:(CDTDatastore *)datastore
{
    CDTQIndexCreator *executor =
        [[CDTQIndexCreator alloc] initWithDatabase:database datastore:datastore];
    return [executor ensureIndexed:fieldNames withName:indexName type:indexType];
}

#pragma mark Instance methods

/**
 Add a single, possibly compound, index for the given field names.

 @param fieldNames List of fieldnames in the sort format
 @param indexName Name of index to create.
 @returns name of created index
 */
- (NSString *)ensureIndexed:(NSArray * /* NSString */)fieldNames
                   withName:(NSString *)indexName
                       type:(NSString *)indexType
{
    if (!fieldNames || fieldNames.count == 0) {
        LogError(@"No fieldnames were passed to ensureIndexed");
        return nil;
    }

    if (!indexName) {
        LogError(@"No index name was passed to ensureIndexed");
        return nil;
    }

    fieldNames = [CDTQIndexCreator removeDirectionsFromFields:fieldNames];

    for (NSString *fieldName in fieldNames) {
        if (![CDTQIndexCreator validFieldName:fieldName]) {
            return nil;
        }
    }

    // Check there are no duplicate field names in the array
    NSSet *uniqueNames = [NSSet setWithArray:fieldNames];
    if (uniqueNames.count != fieldNames.count) {
        LogError(@"Cannot create index with duplicated field names %@", fieldNames);
        return nil;
    }

    // Prepend _id and _rev if it's not in the array
    if (![fieldNames containsObject:@"_rev"]) {
        NSMutableArray *tmp = [NSMutableArray arrayWithObject:@"_rev"];
        [tmp addObjectsFromArray:fieldNames];
        fieldNames = [NSArray arrayWithArray:tmp];
    }

    if (![fieldNames containsObject:@"_id"]) {
        NSMutableArray *tmp = [NSMutableArray arrayWithObject:@"_id"];
        [tmp addObjectsFromArray:fieldNames];
        fieldNames = [NSArray arrayWithArray:tmp];
    }

    // Does the index already exist; return success if it does and is same, else fail
    NSDictionary *existingIndexes = [CDTQIndexManager listIndexesInDatabaseQueue:self.database];
    if (existingIndexes[indexName] != nil) {
        NSDictionary *index = existingIndexes[indexName];
        NSString *existingType = index[@"type"];
        NSSet *existingFields = [NSSet setWithArray:index[@"fields"]];
        NSSet *newFields = [NSSet setWithArray:fieldNames];

        if ([existingType isEqualToString:indexType] && [existingFields isEqualToSet:newFields]) {
            BOOL success = [CDTQIndexUpdater updateIndex:indexName
                                              withFields:fieldNames
                                              inDatabase:_database
                                           fromDatastore:_datastore
                                                   error:nil];
            return success ? indexName : nil;
        } else {
            return nil;
        }
    }

    __block BOOL success = YES;

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {

        // Insert metadata table entries
        NSArray *inserts = [CDTQIndexCreator insertMetadataStatementsForIndexName:indexName
                                                                             type:indexType
                                                                       fieldNames:fieldNames];
        for (CDTQSqlParts *sql in inserts) {
            success = success && [db executeUpdate:sql.sqlWithPlaceholders
                                     withArgumentsInArray:sql.placeholderValues];
        }

        // Create the table for the index
        CDTQSqlParts *createTable =
            [CDTQIndexCreator createIndexTableStatementForIndexName:indexName
                                                         fieldNames:fieldNames];
        success = success && [db executeUpdate:createTable.sqlWithPlaceholders
                                 withArgumentsInArray:createTable.placeholderValues];

        // Create the SQLite index on the index table

        CDTQSqlParts *createIndex =
            [CDTQIndexCreator createIndexIndexStatementForIndexName:indexName
                                                         fieldNames:fieldNames];
        success = success && [db executeUpdate:createIndex.sqlWithPlaceholders
                                 withArgumentsInArray:createIndex.placeholderValues];

        if (!success) {
            *rollback = YES;
        }
    }];

    // Update the new index if it's been created
    if (success) {
        success = success && [CDTQIndexUpdater updateIndex:indexName
                                                withFields:fieldNames
                                                inDatabase:_database
                                             fromDatastore:_datastore
                                                     error:nil];
    }

    return success ? indexName : nil;
}

/**
 Validate the field name string is usable.

 The only restriction so far is that the parts don't start with
 a $ sign, as this makes the query language ambiguous.
 */
+ (BOOL)validFieldName:(NSString *)fieldName
{
    NSArray *parts = [fieldName componentsSeparatedByString:@"."];
    for (NSString *part in parts) {
        if ([part hasPrefix:@"$"]) {
            LogError(@"Field names cannot start with a $ in field %@", fieldName);
            return NO;
        }
    }
    return YES;
}

/**
 We don't support directions on field names, but they are an optimisation so
 we can discard them safely.
 */
+ (NSArray /*NSDictionary or NSString*/ *)removeDirectionsFromFields:(NSArray *)fieldNames
{
    NSMutableArray *result = [NSMutableArray array];

    for (NSObject *field in fieldNames) {
        if ([field isKindOfClass:[NSDictionary class]]) {
            NSDictionary *specifier = (NSDictionary *)field;
            if (specifier.count == 1) {
                NSString *fieldName = [specifier allKeys][0];
                [result addObject:fieldName];
            }
        } else if ([field isKindOfClass:[NSString class]]) {
            [result addObject:field];
        }
    }

    return result;
}

+ (NSArray /*CDTQSqlParts*/ *)insertMetadataStatementsForIndexName:(NSString *)indexName
                                                              type:(NSString *)indexType
                                                        fieldNames:
                                                            (NSArray /*NSString*/ *)fieldNames
{
    if (!indexName) {
        return nil;
    }

    if (!fieldNames || fieldNames.count == 0) {
        return nil;
    }

    NSMutableArray *result = [NSMutableArray array];
    for (NSString *fieldName in fieldNames) {
        NSString *sql = @"INSERT INTO %@ "
                         "(index_name, index_type, field_name, last_sequence) "
                         "VALUES (?, ?, ?, 0);";
        sql = [NSString stringWithFormat:sql, kCDTQIndexMetadataTableName];

        CDTQSqlParts *parts =
            [CDTQSqlParts partsForSql:sql parameters:@[ indexName, indexType, fieldName ]];
        [result addObject:parts];
    }
    return result;
}

+ (CDTQSqlParts *)createIndexTableStatementForIndexName:(NSString *)indexName
                                             fieldNames:(NSArray /*NSString*/ *)fieldNames
{
    if (!indexName) {
        return nil;
    }

    if (!fieldNames || fieldNames.count == 0) {
        return nil;
    }

    NSString *tableName = [CDTQIndexManager tableNameForIndex:indexName];
    NSMutableArray *clauses = [NSMutableArray array];
    for (NSString *fieldName in fieldNames) {
        NSString *clause = [NSString stringWithFormat:@"\"%@\" NONE", fieldName];
        [clauses addObject:clause];
    }

    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE %@ ( %@ );", tableName,
                                               [clauses componentsJoinedByString:@", "]];
    return [CDTQSqlParts partsForSql:sql parameters:@[]];
}

+ (CDTQSqlParts *)createIndexIndexStatementForIndexName:(NSString *)indexName
                                             fieldNames:(NSArray /*NSString*/ *)fieldNames
{
    if (!indexName) {
        return nil;
    }

    if (!fieldNames || fieldNames.count == 0) {
        return nil;
    }

    NSString *tableName = [CDTQIndexManager tableNameForIndex:indexName];
    NSString *sqlIndexName = [tableName stringByAppendingString:@"_index"];

    NSMutableArray *clauses = [NSMutableArray array];
    for (NSString *fieldName in fieldNames) {
        [clauses addObject:[NSString stringWithFormat:@"\"%@\"", fieldName]];
    }

    NSString *sql = [NSString stringWithFormat:@"CREATE INDEX %@ ON %@ ( %@ );", sqlIndexName,
                                               tableName, [clauses componentsJoinedByString:@", "]];
    return [CDTQSqlParts partsForSql:sql parameters:@[]];
}

@end
