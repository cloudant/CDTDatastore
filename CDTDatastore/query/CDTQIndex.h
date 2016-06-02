//
//  CDTQIndex.h
//
//  Created by Al Finkelstein on 2015-04-20
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import "CDTQIndexManager.h"


NS_ASSUME_NONNULL_BEGIN

extern NSString *const kCDTQJsonType __deprecated;
extern NSString *const kCDTQTextType __deprecated;

/**
 * This class provides functionality to manage an index
 */
@interface CDTQIndex : NSObject

@property (nullable, nonatomic, strong) NSArray<NSString *> *fieldNames;
@property (nonatomic, strong) NSString *indexName;
@property (nonatomic, strong) NSString *indexType __deprecated;
@property (nullable, nonatomic, strong) NSDictionary *indexSettings;
@property (nonatomic) CDTQIndexType type;

/**
 * This function sets the index type to the default setting of "json"
 *
 * @param indexName the index name
 * @param fieldNames the field names in the index
 * @return the Index object or nil if arguments passed in were invalid.
 */
+ (nullable instancetype)index:(NSString *)indexName withFields:(NSArray<NSString *> *)fieldNames;

+ (nullable instancetype)index:(NSString *)indexName
                    withFields:(NSArray<NSString *> *)fieldNames
                        ofType:(NSString *)indexType __deprecated;

/**
 * Creates a CDTIndex object
 *
 * @param indexName the index name
 * @param fieldNames the field names in the index
 * @param type the index type
 * @return the Index object or nil if arguments passed in were invalid.
 */
+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray<NSString *> *)fieldNames
                 type:(CDTQIndexType)type;

/**
 * This function handles index specific validation and ensures that the constructed
 * Index object is valid.
 *
 * @deprecated This has been deprecated use +index:withFields:type:withSettings instead
 *
 * @param indexName the index name
 * @param fieldNames the field names in the index
 * @param indexType the index type (json or text)
 * @param indexSettings the optional settings used to configure the index.
 *                      Only supported parameter is 'tokenize' for text indexes only.
 * @return the Index object or nil if arguments passed in were invalid.
 */
+ (nullable instancetype)index:(NSString *)indexName
                    withFields:(NSArray<NSString *> *)fieldNames
                        ofType:(NSString *)indexType
                  withSettings:(nullable NSDictionary<NSString *, NSString *> *)indexSettings __deprecated;

/**
 * This function handles index specific validation and ensures that the constructed
 * Index object is valid.
 *
 * @param indexName the index name
 * @param fieldNames the field names in the index
 * @param indexType the index type (json or text)
 * @param indexSettings the optional settings used to configure the index.
 *                      Only supported parameter is 'tokenize' for text indexes only.
 * @return the Index object or nil if arguments passed in were invalid.
 */
+ (nullable instancetype)index:(NSString *)indexName
                    withFields:(NSArray *)fieldNames
                          type:(CDTQIndexType)indexType
                  withSettings:(nullable NSDictionary *)indexSettings;

/**
 * Compares the index type and accompanying settings with the passed in arguments.
 *
 * @deprecated This has been deprecated use compareToIndexType:withIndexSettings instead
 *
 * @param indexType the index type to compare to
 * @param indexSettings the indexSettings to compare to as an NSString
 * @return YES/NO - whether there is a match
 */
- (BOOL)compareIndexTypeTo:(NSString *)indexType
         withIndexSettings:(NSString *)indexSettings __deprecated;

/**
 * Compares the index type and accompanying settings with the passed in arguments.
 *
 * @param indexType the index type to compare to
 * @param indexSettings the indexSettings to compare to as an NSString
 * @return YES/NO - whether there is a match
 */
- (BOOL)compareToIndexType:(CDTQIndexType)indexType
         withIndexSettings:(nullable NSString *)indexSettings;

/**
 * Converts the index settings to a JSON string
 *
 * @return the JSON representation of the index settings
 */
- (NSString *)settingsAsJSON;

@end

NS_ASSUME_NONNULL_END