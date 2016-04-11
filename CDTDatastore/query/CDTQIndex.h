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

extern NSString *const kCDTQJsonType;
extern NSString *const kCDTQTextType;

/**
 * This class provides functionality to manage an index
 */
@interface CDTQIndex : NSObject

@property (nonatomic, strong) NSArray *fieldNames;
@property (nonatomic, strong) NSString *indexName;
@property (nonatomic, strong) NSString *indexType __deprecated;
@property (nonatomic) CDTQIndexType type;
@property (nonatomic, strong) NSDictionary *indexSettings;

/**
 * This function sets the index type to the default setting of "json"
 *
 * @param indexName the index name
 * @param fieldNames the field names in the index
 * @return the Index object or nil if arguments passed in were invalid.
 */
+ (instancetype)index:(NSString *)indexName withFields:(NSArray *)fieldNames;

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray *)fieldNames
               ofType:(NSString *)indexType __deprecated;

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray<NSString *> *)fields
                 type:(CDTQIndexType)type;

/**
 * This function handles index specific validation and ensures that the constructed
 * Index object is valid.
 *
 *
 *
 * @param indexName the index name
 * @param fieldNames the field names in the index
 * @param indexType the index type (json or text)
 * @param indexSettings the optional settings used to configure the index.
 *                      Only supported parameter is 'tokenize' for text indexes only.
 * @return the Index object or nil if arguments passed in were invalid.
 */
+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray *)fieldNames
               ofType:(NSString *)indexType
         withSettings:(NSDictionary *)indexSettings __deprecated;

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray *)fieldNames
                 type:(CDTQIndexType)indexType
         withSettings:(NSDictionary *)indexSettings;

/**
 * Compares the index type and accompanying settings with the passed in arguments.
 *
 * @param indexType the index type to compare to
 * @param indexSettings the indexSettings to compare to as an NSString
 * @return YES/NO - whether there is a match
 */
- (BOOL)compareIndexTypeTo:(NSString *)indexType
         withIndexSettings:(NSString *)indexSettings __deprecated;

- (BOOL)compareToIndexType:(CDTQIndexType)indexType withIndexSettings:(NSString *)indexSettings;

/**
 * Converts the index settings to a JSON string
 *
 * @return the JSON representation of the index settings
 */
- (NSString *)settingsAsJSON;

@end
