//
//  CDTIndexManager.m
//
//
//  Created by Thomas Blench on 27/01/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTIndexManager.h"

#import "CDTSQLiteHelpers.h"
#import "CDTDocumentRevision.h"
#import "CDTFieldIndexer.h"
#import "CDTDatastore.h"
#import "CDTQueryBuilder.h"

#import "TD_Database.h"
#import "TD_Body.h"

#import "FMResultSet.h"
#import "FMDatabase.h"
#import "CDTLogging.h"

static NSString *const CDTIndexManagerErrorDomain = @"CDTIndexManagerErrorDomain";

static NSString *const kCDTIndexTablePrefix = @"_t_cloudant_sync_index_";
static NSString *const kCDTExtensionName = @"com.cloudant.indexing";
static NSString *const kCDTIndexMetadataTableName = @"_t_cloudant_sync_indexes_metadata";
static NSString *const kCDTIndexFieldNamePattern = @"^[a-zA-Z][a-zA-Z0-9_]*$";

NSString *const kCDTQueryOptionSortBy = @"sort_by";
NSString *const kCDTQueryOptionAscending = @"ascending";
NSString *const kCDTQueryOptionDescending = @"descending";
NSString *const kCDTQueryOptionOffset = @"offset";
NSString *const kCDTQueryOptionLimit = @"limit";

static const int VERSION = 1;

@interface CDTIndexManager ()

- (CDTIndex *)getIndexWithName:(NSString *)indexName;

- (NSString *)createIndexTable:(NSString *)indexName type:(CDTIndexType)type;

- (BOOL)updateIndex:(CDTIndex *)index error:(NSError *__autoreleasing *)error;

- (BOOL)updateIndex:(CDTIndex *)index
            changes:(TD_RevisionList *)changes
       lastSequence:(long *)lastSequence;

- (BOOL)updateSchema:(int)currentVersion;

@end

@implementation CDTIndexManager

#pragma mark Public methods

- (id)initWithDatastore:(CDTDatastore *)datastore error:(NSError *__autoreleasing *)error
{
    BOOL success = YES;
    self = [super init];
    if (self) {
        _datastore = datastore;
        _indexFunctionMap = [[NSMutableDictionary alloc] init];
        _validFieldRegexp = [[NSRegularExpression alloc] initWithPattern:kCDTIndexFieldNamePattern
                                                                 options:0
                                                                   error:error];

        NSString *dir = [datastore extensionDataFolder:kCDTExtensionName];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:TRUE
                                                   attributes:nil
                                                        error:nil];
        NSString *filename = [NSString pathWithComponents:@[ dir, @"indexes.sqlite" ]];
        _database = [[FMDatabaseQueue alloc] initWithPath:filename];
        if (!_database) {
            // raise error
            if (error) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey :
                        NSLocalizedString(@"Problem opening or creating database.", nil)
                        };
                *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                             code:CDTIndexErrorSqlError
                                         userInfo:userInfo];
            }
            return nil;
        }

        success = [self updateSchema:VERSION];
        if (!success) {
            // raise error
            if (error) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey :
                        NSLocalizedString(@"Problem updating database schema.", nil)
                        };
                *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                             code:CDTIndexErrorSqlError
                                         userInfo:userInfo];
            }
            return nil;
        }
    }
    return self;
}

- (void)dealloc { [self shutdown]; }

- (BOOL)shutdown
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_database close];  // the indexes database
    return YES;
}

- (BOOL)ensureIndexedWithIndexName:(NSString *)indexName
                         fieldName:(NSString *)fieldName
                             error:(NSError *__autoreleasing *)error
{
    return [self ensureIndexedWithIndexName:indexName
                                  fieldName:fieldName
                                       type:CDTIndexTypeString
                                      error:error];
}

- (BOOL)ensureIndexedWithIndexName:(NSString *)indexName
                         fieldName:(NSString *)fieldName
                              type:(CDTIndexType)type
                             error:(NSError *__autoreleasing *)error
{
    CDTFieldIndexer *fi = [[CDTFieldIndexer alloc] initWithFieldName:fieldName type:type];
    return [self ensureIndexedWithIndexName:indexName type:type indexer:fi error:error];
}

- (BOOL)deleteIndexWithIndexName:(NSString *)indexName error:(NSError *__autoreleasing *)error
{
    __block BOOL success = YES;

    NSString *sqlDelete = [NSString
        stringWithFormat:@"delete from %@ where name = :name;", kCDTIndexMetadataTableName];
    NSString *sqlDrop =
        [NSString stringWithFormat:@"drop table %@%@;", kCDTIndexTablePrefix, indexName];

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSDictionary *v = @{ @"name" : indexName };
        success = success && [db executeUpdate:sqlDelete withParameterDictionary:v];
        success = success && [db executeUpdate:sqlDrop];
        if (!success) {
            *rollback = YES;
        }
    }];

    if (success) {
        [_indexFunctionMap removeObjectForKey:indexName];
    } else {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : NSLocalizedString(@"Problem deleting index.", nil)
            };
            *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                         code:CDTIndexErrorSqlError
                                     userInfo:userInfo];
        }
    }

    return success;
}

- (BOOL)updateAllIndexes:(NSError *__autoreleasing *)error
{
    BOOL ok = TRUE;
    NSDictionary *indexes = [self getAllRegisteredIndexes];
    for (CDTIndex *index in [indexes allValues]) {
        [self updateIndex:index error:error];
    }
    return ok;
}

#pragma mark Querying

- (CDTQueryResult *)queryWithPredicate:(NSPredicate *)predicate
                                 error:(NSError *__autoreleasing *)error
{
    return [self queryWithPredicate:predicate options:nil error:error];
}

- (CDTQueryResult *)queryWithPredicate:(NSPredicate *)predicate
                               options:(NSDictionary *)options
                                 error:(NSError *__autoreleasing *)error
{
    CDTQueryBuilderResult *query =
        [CDTQueryBuilder buildWithPredicate:predicate options:options error:error];

    if (query == nil) {
        return nil;  // error is populated by the builder
    }

    // Validate all indexes specified in the predicate exist.
    for (NSString *indexName in query.usedIndexes) {
        if (![self indexExists:indexName
                   description:@"Index named in query does not exist."
                         error:error]) {
            return nil;  // error populated by indexExists:...
        }
    }

    NSMutableArray *docids = [NSMutableArray array];

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *results = [db executeQuery:query.sql withArgumentsInArray:query.values];
        while ([results next]) {
            NSString *docid = [results stringForColumnIndex:0];
            [docids addObject:docid];
        }
    }];

    // now return CDTQueryResult which is an iterator over the documents for these ids
    CDTQueryResult *result = [[CDTQueryResult alloc] initWithDocIds:docids datastore:_datastore];
    return result;
}

- (CDTQueryResult *)queryWithDictionary:(NSDictionary *)query
                                  error:(NSError *__autoreleasing *)error
{
    return [self queryWithDictionary:query options:nil error:error];
}

- (CDTQueryResult *)queryWithDictionary:(NSDictionary *)query
                                options:(NSDictionary *)options
                                  error:(NSError *__autoreleasing *)error
{
    // always update indexes at query time
    if (![self updateAllIndexes:error]) {
        return nil;
    }

    // TODO support empty query body for just ordering without where clause
    BOOL first = TRUE;

    NSString *tables;
    NSMutableArray *tablesJoiner = [[NSMutableArray alloc] init];
    NSString *firstTable;
    NSString *currentTable;
    NSString *valueWhereClause;
    NSMutableArray *valueWhereClauseJoiner = [[NSMutableArray alloc] init];
    NSString *idWhereClause;
    NSMutableArray *idWhereClauseJoiner = [[NSMutableArray alloc] init];
    NSMutableArray *queryValues = [[NSMutableArray alloc] init];

    // iterate through query terms and build SQL
    for (NSString *indexName in [query keyEnumerator]) {
        if (![self indexExists:indexName
                   description:@"Index named in query does not exist."
                         error:error]) {
            return nil;
        }

        NSObject *value = [query objectForKey:indexName];

        NSString *valueWhereClauseFragment;

        // keep track of which table we are on
        currentTable = [NSString stringWithFormat:@"%@%@", kCDTIndexTablePrefix, indexName];
        if (first) {
            firstTable = currentTable;
        }

        // keep track of all the tables
        [tablesJoiner addObject:currentTable];

        if ([value isKindOfClass:[NSArray class]]) {
            // key: [value1, value2, ..., valuen] -> where clause of = statements joined by OR
            NSMutableArray *orWhereClauseJoiner = [[NSMutableArray alloc] init];
            for (NSString *theValue in(NSArray *)value) {
                NSString *orWhereClauseFragment =
                    [NSString stringWithFormat:@"%@.value = ?", currentTable];
                [orWhereClauseJoiner addObject:orWhereClauseFragment];
                // accumulate values in array
                [queryValues addObject:theValue];
            }
            valueWhereClauseFragment = [NSString
                stringWithFormat:@"( %@ )", [orWhereClauseJoiner componentsJoinedByString:@" or "]];
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            // key: {min: minVal, max: maxVal} -> where clause of >= and <= statements joined by AND
            NSMutableArray *minMaxWhereClauseJoiner = [[NSMutableArray alloc] init];
            NSObject *minValue = [(NSDictionary *)value objectForKey:@"min"];
            NSObject *maxValue = [(NSDictionary *)value objectForKey:@"max"];
            if (!minValue && !maxValue) {
                // ERROR
            }
            if (minValue) {
                NSString *minValueFragment =
                    [NSString stringWithFormat:@"%@.value >= ?", currentTable];
                [minMaxWhereClauseJoiner addObject:minValueFragment];
                // accumulate values in array
                [queryValues addObject:minValue];
            }
            if (maxValue) {
                NSString *maxValueFragment =
                    [NSString stringWithFormat:@"%@.value <= ?", currentTable];
                [minMaxWhereClauseJoiner addObject:maxValueFragment];
                // accumulate values in array
                [queryValues addObject:maxValue];
            }
            valueWhereClauseFragment = [NSString
                stringWithFormat:@"( %@ )",
                                 [minMaxWhereClauseJoiner componentsJoinedByString:@" and "]];
        } else {
            // key: {value} -> where clause of one = statement
            // NB we are assuming a simple type eg NSString or NSNumber
            valueWhereClauseFragment = [NSString stringWithFormat:@"%@.value = ?", currentTable];
            // accumulate values in array
            [queryValues addObject:value];
        }

        // make where clause for values
        [valueWhereClauseJoiner addObject:valueWhereClauseFragment];

        // make where clause for ids
        if (!first) {
            NSString *idWhereClauseFragment =
                [NSString stringWithFormat:@"%@.docid = %@.docid", firstTable, currentTable];
            [idWhereClauseJoiner addObject:idWhereClauseFragment];
        }

        first = FALSE;
    }

    NSMutableArray *docids = [[NSMutableArray alloc] init];

    // ascending unless told otherwsie
    BOOL descending = NO;

    if (options && [options valueForKey:kCDTQueryOptionDescending]) {
        descending = [[options valueForKey:kCDTQueryOptionDescending] boolValue];
    } else if (options && [options valueForKey:kCDTQueryOptionAscending]) {
        descending = ![[options valueForKey:kCDTQueryOptionAscending] boolValue];
    }

    NSString *orderByClause = @"";
    if (options && [options valueForKey:kCDTQueryOptionSortBy]) {
        NSString *sort = [options valueForKey:kCDTQueryOptionSortBy];

        if (![self indexExists:sort
                   description:@"Index named in sort_by option does not exist."
                         error:error]) {
            return nil;
        }

        currentTable = [NSString stringWithFormat:@"%@%@", kCDTIndexTablePrefix, sort];

        // if the sort by wasn't mentioned in the 'where query' part we'll need to add it here
        // so that the table gets mentioned in the from clause and is joined on docid correctly
        if (![query valueForKey:sort]) {
            [tablesJoiner addObject:currentTable];

            // make where clause for ids
            if (!first) {
                NSString *idWhereClauseFragment =
                    [NSString stringWithFormat:@"%@.docid = %@.docid", firstTable, currentTable];
                [idWhereClauseJoiner addObject:idWhereClauseFragment];
            }
        }
        orderByClause = [NSString
            stringWithFormat:@"order by %@.value %@", currentTable, descending ? @"desc" : @"asc"];
    }

    // now make the query
    NSString *whereClause;
    tables = [tablesJoiner componentsJoinedByString:@", "];
    valueWhereClause = [valueWhereClauseJoiner componentsJoinedByString:@" and "];
    idWhereClause = [idWhereClauseJoiner componentsJoinedByString:@" and "];

    // do we need to join on ids?
    if ([idWhereClauseJoiner count] > 0) {
        whereClause = [NSString stringWithFormat:@"(%@) and (%@)", valueWhereClause, idWhereClause];
    } else {
        whereClause = valueWhereClause;
    }

    NSString *sqlJoin = [NSString stringWithFormat:@"select %@.docid from %@ where %@ %@;",
                                                   firstTable, tables, whereClause, orderByClause];

    // trim down the list of document IDs if offset/limit specified
    // TODO this could be more efficient to do in the SQL?
    int offset = 0;
    int limitCount = 0;
    BOOL limit = NO;

    if ([options valueForKey:kCDTQueryOptionOffset]) {
        offset = [[options valueForKey:kCDTQueryOptionOffset] intValue];
    }
    if ([options valueForKey:kCDTQueryOptionLimit]) {
        limitCount = [[options valueForKey:kCDTQueryOptionLimit] intValue];
        limit = YES;
    }

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *results = [db executeQuery:sqlJoin withArgumentsInArray:queryValues];

        int n = 0;
        [results next];
        for (int i = 0;[results hasAnotherRow]; i++) {
            if (i >= offset && (!limit || n < limitCount)) {
                NSString *docid = [results stringForColumnIndex:0];
                [docids addObject:docid];
                n++;
            }
            [results next];
        }
        [results close];
    }];

    // now return CDTQueryResult which is an iterator over the documents for these ids
    CDTQueryResult *result = [[CDTQueryResult alloc] initWithDocIds:docids datastore:_datastore];
    return result;
}

- (NSArray *)uniqueValuesForIndex:(NSString *)indexName error:(NSError *__autoreleasing *)error
{
    if (![self indexExists:indexName
               description:@"Index named in query does not exist."
                     error:error]) {
        return nil;
    }

    NSString *table = [NSString stringWithFormat:@"%@%@", kCDTIndexTablePrefix, indexName];
    NSString *sql = [NSString stringWithFormat:@"select distinct value from %@;", table];
    NSMutableArray *values = [[NSMutableArray alloc] init];

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *results = [db executeQuery:sql];

        [results next];
        while ([results hasAnotherRow]) {
            [values addObject:[results objectForColumnIndex:0]];
            [results next];
        }
        [results close];
    }];
    return values;
}

#pragma mark Private methods

- (CDTIndex *)getIndexWithName:(NSString *)indexName
{
    // TODO validate index name

    NSString *SQL_SELECT_INDEX_BY_NAME =
        [NSString stringWithFormat:@"SELECT name, type, last_sequence FROM %@ WHERE name = ?;",
                                   kCDTIndexMetadataTableName];

    __block CDTIndexType type;
    __block long lastSequence;
    __block BOOL success = false;

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *results = [db executeQuery:SQL_SELECT_INDEX_BY_NAME, indexName];
        [results next];
        if ([results hasAnotherRow]) {
            type = [results longForColumnIndex:1];
            lastSequence = [results longForColumnIndex:2];
            success = true;
        }
        [results close];
    }];
    if (success) {
        return
            [[CDTIndex alloc] initWithIndexName:indexName lastSequence:lastSequence fieldType:type];
    } else {
        return nil;
    }
}

/**
 Return indexes which have been registered this session.

 That is, for which we have an entry in the index name -> function mapping
 which means we can update the index successfully.
 */
- (NSDictionary *)getAllRegisteredIndexes
{
    NSArray *registeredIndexes = [_indexFunctionMap allKeys];

    NSString *SQL_SELECT_INDEX_BY_NAME = [NSString
        stringWithFormat:@"SELECT name, type, last_sequence FROM %@;", kCDTIndexMetadataTableName];

    NSMutableDictionary *indexes = [[NSMutableDictionary alloc] init];

    __block NSString *indexName;
    __block CDTIndexType type;
    __block long lastSequence;

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *results = [db executeQuery:SQL_SELECT_INDEX_BY_NAME];
        [results next];
        while ([results hasAnotherRow]) {
            indexName = [results stringForColumnIndex:0];

            // If index isn't registered with ensureIndexed yet, then skip it.
            if ([registeredIndexes containsObject:indexName]) {
                type = [results longForColumnIndex:1];
                lastSequence = [results longForColumnIndex:2];
                CDTIndex *index = [[CDTIndex alloc] initWithIndexName:indexName
                                                         lastSequence:lastSequence
                                                            fieldType:type];
                [indexes setObject:index forKey:indexName];
            }

            [results next];
        }
        [results close];
    }];
    return indexes;
}

- (NSString *)createIndexTable:(NSString *)indexName type:(CDTIndexType)type
{
    CDTIndexHelper *helper = [CDTIndexHelper indexHelperForType:type];
    if (helper) {
        NSString *sql =
            [helper createSQLTemplateWithPrefix:kCDTIndexTablePrefix indexName:indexName];
        return sql;
    }
    return nil;
}

- (BOOL)updateIndex:(CDTIndex *)index error:(NSError *__autoreleasing *)error
{
    BOOL success = TRUE;
    TDChangesOptions options = {.limit = 10000,
                                .contentOptions = 0,
                                .includeDocs = TRUE,
                                .includeConflicts = FALSE,
                                .sortBySequence = TRUE};

    TD_RevisionList *changes;
    long lastSequence = [index lastSequence];

    do {
        changes = [[_datastore database] changesSinceSequence:lastSequence
                                                      options:&options
                                                       filter:nil
                                                       params:nil];
        success = success && [self updateIndex:index changes:changes lastSequence:&lastSequence];
    } while (success && [changes count] > 0);

    // raise error
    if (!success) {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : NSLocalizedString(@"Problem updating index.", nil)
            };
            *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                         code:CDTIndexErrorSqlError
                                     userInfo:userInfo];
        }
    }
    return success;
}

- (BOOL)updateIndex:(CDTIndex *)index
            changes:(TD_RevisionList *)changes
       lastSequence:(long *)lastSequence
{
    __block bool success = YES;

    NSString *tableName = [kCDTIndexTablePrefix stringByAppendingString:[index indexName]];

    NSString *strDelete = @"delete from %@ where docid = :docid;";
    NSString *sqlDelete = [NSString stringWithFormat:strDelete, tableName];

    NSString *strInsert = @"insert into %@ (docid, value) values (:docid, :value);";
    NSString *sqlInsert = [NSString stringWithFormat:strInsert, tableName];

    NSObject<CDTIndexer> *f =
        (NSObject<CDTIndexer> *)[_indexFunctionMap valueForKey:[index indexName]];
    // we'll need a helper to do conversions
    CDTIndexHelper *helper = [CDTIndexHelper indexHelperForType:[index fieldType]];

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {

        for (TD_Revision *rev in changes) {
            NSString *docID = [rev docID];

            // Delete
            NSDictionary *dictDelete = @{ @"docid" : docID };
            [db executeUpdate:sqlDelete withParameterDictionary:dictDelete];

            // Insert new values if the rev isn't deleted
            if (!rev.deleted) {
                CDTDocumentRevision *docRev =
                    [[CDTDocumentRevision alloc] initWithDocId:rev.docID
                                                    revisionId:rev.revID
                                                          body:rev.body.properties
                                                       deleted:rev.deleted
                                                   attachments:@{}
                                                      sequence:rev.sequence];
                NSArray *valuesInsert = [f valuesForRevision:docRev indexName:[index indexName]];
                for (NSObject *rawValue in valuesInsert) {
                    NSObject *convertedValue = [helper convertIndexValue:rawValue];
                    if (convertedValue) {
                        NSDictionary *dictInsert = @{ @"docid" : docID, @"value" : convertedValue };
                        success = success &&
                                  [db executeUpdate:sqlInsert withParameterDictionary:dictInsert];
                    }
                }
            }
            if (!success) {
                // TODO fill in error
                *rollback = true;
                break;
            }
            *lastSequence = [rev sequence];
        }
    }];

    // if there was a problem, we rolled back, so the sequence won't be updated
    if (success) {
        return [self updateIndexLastSequence:[index indexName] lastSequence:*lastSequence];
    } else {
        return FALSE;
    }
}

- (BOOL)updateIndexLastSequence:(NSString *)indexName lastSequence:(long)lastSequence
{
    __block BOOL success = TRUE;

    NSDictionary *v = @{
        @"name" : indexName,
        @"last_sequence" : [NSNumber numberWithLong:lastSequence]
    };
    NSString *template = @"update %@ set last_sequence = :last_sequence where name = :name;";
    NSString *sql = [NSString stringWithFormat:template, kCDTIndexMetadataTableName];

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        success = success && [db executeUpdate:sql withParameterDictionary:v];
        if (!success) {
            *rollback = YES;
        }
    }];
    return success;
}

- (BOOL)ensureIndexedWithIndexName:(NSString *)indexName
                              type:(CDTIndexType)type
                           indexer:(NSObject<CDTIndexer> *)indexer
                             error:(NSError *__autoreleasing *)error
{
    // validate index name
    if (![self isValidIndexName:indexName error:error]) {
        return NO;
    }
    // already registered?
    if ([_indexFunctionMap objectForKey:indexName]) {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : NSLocalizedString(
                    @"Index already registered with a call to ensureIndexed this session.", nil),
                NSLocalizedFailureReasonErrorKey :
                    NSLocalizedString(@"Index already registered?", nil),
                NSLocalizedRecoverySuggestionErrorKey :
                    NSLocalizedString(@"Index already registered?", nil)
            };
            *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                         code:CDTIndexErrorIndexAlreadyRegistered
                                     userInfo:userInfo];
        }
        return NO;
    }

    __block CDTIndex *index = [self getIndexWithName:indexName];
    __block BOOL success = YES;
    NSMutableDictionary *indexFunctionMap = _indexFunctionMap;
    __weak CDTIndexManager *weakSelf = self;

    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (index == nil) {
            NSString *sqlCreate = [weakSelf createIndexTable:indexName type:type];
            // TODO splitting up statement, should do somewhere else?
            for (NSString *str in [sqlCreate componentsSeparatedByString:@";"]) {
                if ([str length] != 0) {
                    success = success && [db executeUpdate:str];
                }
            }

            // same as insertIndexMetaData
            NSDictionary *v = @{
                @"name" : indexName,
                @"last_sequence" : [NSNumber numberWithInt:0],
                @"type" : @(type)
            };
            NSString *strInsert = @"insert into %@ values (:name, :type, :last_sequence);";
            NSString *sqlInsert = [NSString stringWithFormat:strInsert, kCDTIndexMetadataTableName];

            success = success && [db executeUpdate:sqlInsert withParameterDictionary:v];
        } else {
            CDTLogWarn(CDTINDEX_LOG_CONTEXT, @"not creating index, it was there already");
        }
        if (success) {
            [indexFunctionMap setObject:indexer forKey:indexName];
        } else {
            // raise error, either creating the table or doing the insert
            *rollback = YES;
        }
    }];

    // this has to happen outside that tx
    if (success) {
        if (index == nil) {
            // we just created it, re-get it
            index = [self getIndexWithName:indexName];
        }
        // update index will populate error if necessary
        success = success && [self updateIndex:index error:error];
    }

    return success;
}

- (BOOL)updateSchema:(int)currentVersion
{
    NSString *SCHEMA_INDEX =
        @"CREATE TABLE _t_cloudant_sync_indexes_metadata ( " @"        name TEXT NOT NULL, "
        @"        type INTEGER NOT NULL, " @"        last_sequence INTEGER NOT NULL);";

    __block BOOL success = YES;

    // get current version
    [_database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *results = [db executeQuery:@"pragma user_version;"];
        [results next];
        int version = 0;
        if ([results hasAnotherRow]) {
            version = [results intForColumnIndex:0];
        }
        if (version < currentVersion) {
            // update version in pragma
            // NB we format the entire sql here because pragma doesn't seem to allow ? placeholders
            success =
                success && [db executeUpdate:[NSString stringWithFormat:@"pragma user_version = %d",
                                                                        currentVersion]];
            success = success && [db executeUpdate:SCHEMA_INDEX];
            if (!success) {
                *rollback = YES;
            }
        } else {
            success = YES;
        }
        [results close];
    }];

    return success;
}

- (BOOL)indexExists:(NSString *)indexName
        description:(NSString *)description
              error:(NSError *__autoreleasing *)error
{
    // validate index name
    if (![self isValidIndexName:indexName error:error]) {
        return NO;
    }
    // ... and check it exists
    if (![self getIndexWithName:indexName]) {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : NSLocalizedString(description, nil),
                NSLocalizedFailureReasonErrorKey :
                    [NSString stringWithFormat:@"There is no index "
                                                "with the name \"%@\".",
                                               indexName],
                NSLocalizedRecoverySuggestionErrorKey :
                    NSLocalizedString(@"Call one of the "
                                       "ensureIndexed… methods to create the index as required.",
                                      nil)
            };
            *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                         code:CDTIndexErrorIndexDoesNotExist
                                     userInfo:userInfo];
        }
        return NO;
    }

    return YES;
}

- (BOOL)isValidIndexName:(NSString *)indexName error:(NSError *__autoreleasing *)error
{
    NSUInteger matches =
        [_validFieldRegexp numberOfMatchesInString:indexName
                                           options:0
                                             range:NSMakeRange(0, indexName.length)];
    if (matches == 0) {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : NSLocalizedString(@"Index name is not valid.", nil),
                NSLocalizedFailureReasonErrorKey :
                    [NSString stringWithFormat:
                                  @"Index name \"%@\" does not match regex ^[a-zA-Z][a-zA-Z0-9_]*$",
                                  indexName],
                NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(
                    @"Use an index which matches regex ^[a-zA-Z][a-zA-Z0-9_]*$?", nil)
            };
            *error = [NSError errorWithDomain:CDTIndexManagerErrorDomain
                                         code:CDTIndexErrorInvalidIndexName
                                     userInfo:userInfo];
        }
        return NO;
    }
    return YES;
}

@end

#pragma mark CDTQueryResult class

@implementation CDTQueryResult

- (id)initWithDocIds:(NSArray *)docIds datastore:(CDTDatastore *)datastore
{
    self = [super init];
    if (self) {
        _documentIds = docIds;
        _datastore = datastore;
    }
    return self;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained[])buffer
                                    count:(NSUInteger)len
{
    if (state->state == 0) {
        state->state = 1;
        // this is our index into docids list
        state->extra[0] = 0;
        // number of mutations, although we ignore this
        state->mutationsPtr = &state->extra[1];
    }
    // get our current index for this batch
    unsigned long *index = &state->extra[0];

    NSRange range;
    range.location = (unsigned int)*index;
    range.length = MIN((len), ([_documentIds count] - range.location));

    // get documents for this batch of documentids
    NSArray *batchIds = [_documentIds subarrayWithRange:range];
    __unsafe_unretained NSArray *docs = [_datastore getDocumentsWithIds:batchIds];

    int i;
    for (i = 0; i < range.length; i++) {
        buffer[i] = docs[i];
    }
    // update index ready for next time round
    (*index) += i;

    state->itemsPtr = buffer;
    return i;
}

@end
