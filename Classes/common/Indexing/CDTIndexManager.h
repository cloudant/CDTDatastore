//
//  CDTIndexManager.h
//
//
//  Created by Thomas Blench on 27/01/2014.
//
//

#import <Foundation/Foundation.h>
#import "FMDatabaseQueue.h"
#import "CDTIndex.h" // needed for CDTIndexType - can't forward declare enums

/**
 * Indexing erors:
 */
typedef NS_ENUM(NSInteger, CDTIndexError) {
    CDTIndexErrorInvalidIndexName = 1,
    CDTIndexErrorSqlError = 2,
    CDTIndexErrorIndexAlreadyRegistered = 3,
    CDTIndexErrorIndexDoesNotExist = 4
};

@class CDTQuery;
@class CDTDatastore;
@protocol CDTIndexer;

/**
 * Enumerator over documents resulting from query
 */
@interface CDTQueryResult : NSObject<NSFastEnumeration>
{
    CDTDatastore *_datastore;
}

-(id)initWithDocIds:(NSArray*)docIds
          datastore:(CDTDatastore*)datastore;

-(NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained*)stackbuf count:(NSUInteger)len;

@property (nonatomic,strong,readonly) NSArray *documentIds; // of type NSString*

@end

/**
 * Index manager for creating/deleting indexes, ensuring they are up to date, and querying.
 */
@interface CDTIndexManager : NSObject
{
    CDTDatastore *_datastore;
    FMDatabaseQueue *_database;
    NSMutableDictionary *_indexFunctionMap;
    NSRegularExpression *_validFieldRegexp;
}

-(id)initWithDatastore:(CDTDatastore*)datastore
                 error:(NSError * __autoreleasing *)error;

-(BOOL)ensureIndexedWithIndexName:(NSString*)indexName
                        fieldName:(NSString*)fieldName
                            error:(NSError * __autoreleasing *)error;

-(BOOL)ensureIndexedWithIndexName:(NSString*)indexName
                        fieldName:(NSString*)fieldName
                             type:(CDTIndexType)type
                            error:(NSError * __autoreleasing *)error;

-(BOOL)ensureIndexedWithIndexName:(NSString*)indexName
                             type:(CDTIndexType)type
                    indexFunction:(NSObject<CDTIndexer>*)indexFunction
                            error:(NSError * __autoreleasing *)error;

-(BOOL)updateAllIndexes:(NSError * __autoreleasing *)error;

-(BOOL)deleteIndexWithIndexName:(NSString*)indexName
                          error:(NSError * __autoreleasing *)error;

-(CDTQueryResult*) queryWithDictionary:(NSDictionary*)query
                                 error:(NSError * __autoreleasing *)error;

-(CDTQueryResult*) queryWithDictionary:(NSDictionary*)query
                               options:(NSDictionary*)options
                                 error:(NSError * __autoreleasing *)error;

-(NSArray*) uniqueValuesForIndex:(NSString*)indexName
                           error:(NSError * __autoreleasing *)error;


@end
