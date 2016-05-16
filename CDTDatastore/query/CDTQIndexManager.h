//
//  CDTQIndexManager.h
//
//  Created by Mike Rhodes on 2014-09-27
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CDTQIndexManagerErrorDomain;
extern NSString *const kCDTQIndexTablePrefix;
extern NSString *const kCDTQIndexMetadataTableName;

@class CDTDatastore;
@class CDTQResultSet;
@class CDTDocumentRevision;
@class FMDatabaseQueue;
@class FMDatabase;

/**
 * Query Index types
 */
typedef NS_ENUM(NSUInteger, CDTQIndexType) {
    /**
     * Denotes the index is of type text.
     */
    CDTQIndexTypeText,
    /**
     * Denotes the index of type JSON.
     */
    CDTQIndexTypeJSON,

};

@interface CDTQSqlParts : NSObject

@property (nonatomic, strong) NSString *sqlWithPlaceholders;
@property (nonatomic, strong) NSArray *placeholderValues;

+ (CDTQSqlParts *)partsForSql:(NSString *)sql parameters:(NSArray *)parameters;

@end

/**
 * Indexing and query erors.
 */
typedef NS_ENUM(NSInteger, CDTQQueryError) {
    /**
     * Index name not valid. Names can only contain letters,
     * digits and underscores. They must not start with a digit.
     */
    CDTQIndexErrorInvalidIndexName = 1,
    /**
     * An SQL error occurred during indexing or querying.
     */
    CDTQIndexErrorSqlError = 2,
    /**
     * No index with this name was found.
     */
    CDTQIndexErrorIndexDoesNotExist = 3,
    /**
     * Key provided could not be used to initialize index manager
     */
    CDTQIndexErrorEncryptionKeyError = 4
};

/**
 Main interface to Cloudant query.

 Use the manager to:

 - create indexes
 - delete indexes
 - execute queries
 - update indexes (usually done automatically)
 */
@interface CDTQIndexManager : NSObject

@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) FMDatabaseQueue *database;
@property (nonatomic, readonly, getter = isTextSearchEnabled) BOOL textSearchEnabled;

/**
 Constructs a new CDTQIndexManager which indexes documents in `datastore`
 */
+ (nullable CDTQIndexManager *)
managerUsingDatastore:(CDTDatastore *)datastore
                error:(NSError *__autoreleasing __nullable *__nullable)error;

- (nullable instancetype)initUsingDatastore:(CDTDatastore *)datastore
                                      error:(NSError *__autoreleasing __nullable *__nullable)error;

- (NSDictionary<NSString *, NSArray<NSString *> *> *)listIndexes;

/** Internal */
+ (NSDictionary<NSString *, NSArray<NSString *> *> *)listIndexesInDatabaseQueue:
    (FMDatabaseQueue *)db;
/** Internal */
+ (NSDictionary<NSString *, NSArray<NSString *> *> *)listIndexesInDatabase:(FMDatabase *)db;

- (nullable NSString *)ensureIndexed:(NSArray<NSString *> *)fieldNames;

- (nullable NSString *)ensureIndexed:(NSArray<NSString *> *)fieldNames
                            withName:(NSString *)indexName;

- (nullable NSString *)ensureIndexed:(NSArray<NSString *> *)fieldNames
                            withName:(NSString *)indexName
                                type:(NSString *)type __attribute__((deprecated));

- (nullable NSString *)ensureIndexed:(NSArray<NSString *> *)fieldNames
                            withName:(NSString *)indexName
                                type:(NSString *)type
                            settings:(nullable NSDictionary *)indexSettings __attribute__((deprecated));

- (NSString *)ensureIndexed:(NSArray<NSString *> *)fieldNames
                   withName:(NSString *)indexName
                     ofType:(CDTQIndexType)type;

- (NSString *)ensureIndexed:(NSArray<NSString *> *)fieldNames
                   withName:(NSString *)indexName
                     ofType:(CDTQIndexType)type
                   settings:(nullable NSDictionary *)indexSettings;

- (BOOL)deleteIndexNamed:(NSString *)indexName;

- (BOOL)updateAllIndexes;

- (nullable CDTQResultSet *)find:(NSDictionary *)query;

- (nullable CDTQResultSet *)find:(NSDictionary *)query
                            skip:(NSUInteger)skip
                           limit:(NSUInteger)limit
                          fields:(nullable NSArray *)fields
                            sort:(nullable NSArray *)sortDocument;

/** Internal */
+ (NSString *)tableNameForIndex:(NSString *)indexName;
+ (CDTQIndexType)indexTypeForString:(NSString *)string;
+ (NSString *)stringForIndexType:(CDTQIndexType)indexType;
/** Internal */
+ (BOOL)ftsAvailableInDatabase:(FMDatabaseQueue *)db;

@end
NS_ASSUME_NONNULL_END
