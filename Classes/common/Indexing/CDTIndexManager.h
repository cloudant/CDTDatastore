//
//  CDTIndexManager.h
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

#import <Foundation/Foundation.h>
#import "FMDatabaseQueue.h"
#import "CDTIndex.h"  // needed for CDTIndexType - can't forward declare enums

extern NSString *const kCDTQueryOptionSortBy;
extern NSString *const kCDTQueryOptionAscending;
extern NSString *const kCDTQueryOptionDescending;
extern NSString *const kCDTQueryOptionOffset;
extern NSString *const kCDTQueryOptionLimit;

/**
 * Indexing and query erors.
 */
typedef NS_ENUM(NSInteger, CDTIndexError) {
    /**
     * Index name not valid. Names can only contain letters,
     * digits and underscores. They must not start with a digit.
     * For clarity, the validation regex is:
     * `^[a-zA-Z][a-zA-Z0-9_]*$?`
     */
    CDTIndexErrorInvalidIndexName = 1,
    /**
     * An SQL error occurred during indexing or querying.
     */
    CDTIndexErrorSqlError = 2,
    /**
     * An index with this name is already registered.
     * To create an index with the same name, delete the existing one first.
     */
    CDTIndexErrorIndexAlreadyRegistered = 3,
    /**
     * No index with this name was found.
     */
    CDTIndexErrorIndexDoesNotExist = 4,
    /**
     * Key provided could not be used to initialize index manager
     */
    CDTIndexErrorEncryptionKeyError = 5
};

@class CDTDatastore;
@protocol CDTIndexer;

/**
 Enumerator over documents resulting from query.

 Use a forin query to loop over this object:

     for (DocumentRevision revision : queryResultObject) {
         // do something
     }
 */
@interface CDTQueryResult : NSObject <NSFastEnumeration> {
    CDTDatastore *_datastore;
}

- (id)initWithDocIds:(NSArray *)docIds datastore:(CDTDatastore *)datastore;

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained *)buffer
                                    count:(NSUInteger)len;

@property (nonatomic, strong, readonly) NSArray *documentIds;  // of type NSString*

@end

/**
 * Index manager for creating/deleting indexes, ensuring they are up to date, and querying them.
 */
@interface CDTIndexManager : NSObject {
    CDTDatastore *_datastore;
    FMDatabaseQueue *_database;
    NSMutableDictionary *_indexFunctionMap;
    NSRegularExpression *_validFieldRegexp;
}

/**
 * Returns a new CDTIndexManager associated with the CDTDatastore, allowing the documents
 * in that CDTDatastore to be indexed and queried.
 *
 * @param datastore datastore to manage indexes for
 * @param error will point to an NSError object in case of error.
 */
- (id)initWithDatastore:(CDTDatastore *)datastore error:(NSError *__autoreleasing *)error;

- (BOOL)shutdown;

/**---------------------------------------------------------------------------------------
 * @name Registering indexes at app startup
 *  --------------------------------------------------------------------------------------
 */

/**
 * Registers a new index with type CDTIndexTypeString that indexes
 * a top-level field of documents.
 *
 * @param indexName case-sensitive name of the index. Can only contain letters,
 *             digits and underscores. It must not start with a digit.
 * @param fieldName top-level field use for index values
 * @param error will point to an NSError object in case of error.
 *
 * @return YES if successful; NO in case of error.
 *
 * @see CDTFieldIndexer
 * @see CDTIndexType
 */
- (BOOL)ensureIndexedWithIndexName:(NSString *)indexName
                         fieldName:(NSString *)fieldName
                             error:(NSError *__autoreleasing *)error;

/**
 * Registers a new index with a given type that indexes
 * a top-level field of documents.
 *
 * @param indexName case-sensitive name of the index. Can only contain letters,
 *             digits and underscores. It must not start with a digit.
 * @param fieldName top-level field use for index values
 * @param type IndexType of the index.
 * @param error will point to an NSError object in case of error.
 *
 * @return YES if successful; NO in case of error.
 *
 * @see CDTFieldIndexer
 * @see CDTIndexType
 */
- (BOOL)ensureIndexedWithIndexName:(NSString *)indexName
                         fieldName:(NSString *)fieldName
                              type:(CDTIndexType)type
                             error:(NSError *__autoreleasing *)error;

/**
 * Registers an index with the datastore and make it available for
 * use within the application.
 *
 * The name passed to this function is the one specified at query time,
 * via -queryWithDictionary:error:.
 *
 * The call will block until the given index is up to date.
 *
 * @param indexName case-sensitive name of the index. Can only contain letters, digits and
 *        underscores. It must not start with a digit.
 * @param type type of the index.
 * @param indexer an object conforming to the CDTIndexer protocol. The method
 *        [CDTIndexer valuesForRevision:indexName:] is used to map between a document
 *        and indexed value(s).
 * @param error will point to an NSError object in case of error.
 *
 * @return YES if successful; NO in case of error.
 *
 * @see CDTIndexer
 * @see CDTIndexType
 */
- (BOOL)ensureIndexedWithIndexName:(NSString *)indexName
                              type:(CDTIndexType)type
                           indexer:(NSObject<CDTIndexer> *)indexer
                             error:(NSError *__autoreleasing *)error;

/**---------------------------------------------------------------------------------------
 * @name Maintaining indexes
 *  --------------------------------------------------------------------------------------
 */

/**
 * Makes sure all indexes are up to date.
 *
 * Each index records the last document indexed using the
 * CDTDatastore object's sequence number. This call causes the
 * changes the the CDTDatastore since the last indexed sequence
 * number to be added to all the indexes that this CDTIndexManager
 * knows about.
 *
 * @param error will point to an NSError object in case of error.
 *
 * @return YES if successful; NO in case of error.
 */
- (BOOL)updateAllIndexes:(NSError *__autoreleasing *)error;

/**
 * Deletes an index.
 *
 * The database table associated with the index will be dropped and all index values destroyed.
 *
 * @param indexName name of the index to delete
 * @param error will point to an NSError object in case of error.
 *
 * @return YES if successful; NO in case of error.
 */

- (BOOL)deleteIndexWithIndexName:(NSString *)indexName error:(NSError *__autoreleasing *)error;

/**---------------------------------------------------------------------------------------
 * @name Querying
 *  --------------------------------------------------------------------------------------
 */

/**
 * Execute query with NSPredicate.
 *
 * Use for/in loop or any other enumeration to retrieve the results.
 * If only the Document IDs are required, then access the documentIds property.
 *
 * @param predicate NSPredicate expressing query.
 * @param error will point to an NSError object in case of error.
 *
 * @return CDTQueryResult object for enumeration or retrieving Document IDs; or nil in case of
 *         error.
 *
 */
- (CDTQueryResult *)queryWithPredicate:(NSPredicate *)predicate
                                 error:(NSError *__autoreleasing *)error;

/**
 * Execute query with NSPredicate.
 *
 * Use for/in loop or any other enumeration to retrieve the results.
 * If only the Document IDs are required, then access the documentIds property.
 *
 * @param predicate NSPredicate expressing query.
 * @param options key/value pairs specifying options.
 * @param error will point to an NSError object in case of error.
 *
 * @return CDTQueryResult object for enumeration or retrieving Document IDs; or nil in case of
 *         error.
 *
 */
- (CDTQueryResult *)queryWithPredicate:(NSPredicate *)predicate
                               options:(NSDictionary *)options
                                 error:(NSError *__autoreleasing *)error;
/**
 * Execute query. See TODO for details of query syntax.
 *
 * Use for/in loop or any other enumeration to retrieve the results.
 * If only the Document IDs are required, then access the documentIds property.
 *
 * @param query key/value pairs expressing query.
 * @param error will point to an NSError object in case of error.
 *
 * @return CDTQueryResult object for enumeration or retrieving Document IDs; or nil in case of
 *         error.
 *
 */
- (CDTQueryResult *)queryWithDictionary:(NSDictionary *)query
                                  error:(NSError *__autoreleasing *)error;

/**
 * Execute query with additional options. See TODO for details of query syntax.
 *
 * Use for/in loop or any other enumeration to retrieve the results.
 * If only the Document IDs are required, then access the documentIds property.
 *
 * @param query key/value pairs specifying query.
 * @param options key/value pairs specifying options.
 * @param error will point to an NSError object in case of error.
 *
 * @return CDTQueryResult object for enumeration or retrieving Document IDs; or nil in case of
 *         error.
 */
- (CDTQueryResult *)queryWithDictionary:(NSDictionary *)query
                                options:(NSDictionary *)options
                                  error:(NSError *__autoreleasing *)error;

/**
 * Return an array of unique values for the given index.
 *
 * The unique values will be determined by the database's DISTINCT operator and will depend on the
 * data type.
 *
 * @param indexName the index to fetch the unique values for.
 * @param error will point to an NSError object in case of error.
 *
 * @return an NSArray of unique values. The type of the array members will be determined by the
 *         Indexer's implementation of [CDTIndexer valuesForRevision:indexName:].
 */
- (NSArray *)uniqueValuesForIndex:(NSString *)indexName error:(NSError *__autoreleasing *)error;

@end
