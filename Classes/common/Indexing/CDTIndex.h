//
//  CDTIndex.h
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

/**
 * The datatype used for an index.
 *
 * See each enum value for conversion details.
 */
typedef NS_ENUM(NSInteger, CDTIndexType) {
    /**
     * Integer index type.
     * Supports any NSNumber type.
     * Additionally NSStrings are supported, if they can be successfully converted to an NSNumber.
     * Strings which fail conversion are returned as nil and are not indexed.
     *
     */
    CDTIndexTypeInteger,
    /**
     * String index type.
     * Supports only NSStrings.
     * No conversion is performed.
     */
    CDTIndexTypeString
};

// fwd defs for typedef which follows
@class CDTIndexHelperBase;
@protocol CDTIndexHelperDelegate;

/*
 * Typedef for convenience - all helper classes should extend this type as they will need to
 * implement the CDTIndexHelperBase interface and conform to the CDTIndexHelperDelegate protocol
 */
typedef CDTIndexHelperBase<CDTIndexHelperDelegate> CDTIndexHelper;

@interface CDTIndex : NSObject

@property (nonatomic, strong, readonly) NSString *indexName;
@property (nonatomic, readonly) long lastSequence;
@property (nonatomic, readonly) CDTIndexType fieldType;

- (id)initWithIndexName:(NSString *)indexName
           lastSequence:(long)lastSequence
              fieldType:(CDTIndexType)fieldType;

@end

/*
 * Protocol adopted by classes to help indexers deal with issues arising from use of different data
 * types.
 *
 * In order to extend the types which indexes support, it will be necessary to create new classes
 * conforming to this protocol.  Additionally, [CDTIndexHelperBase indexHelperForType:] will need to
 * have its implementation augmented to support the new helper class.
 */
@protocol CDTIndexHelperDelegate

/*
 * Converts the given NSOjbect to a value suitable for inserting into the index.
 *
 * Each class conforming to the CDTIndexHelperDelegate converts values to index into a uniform data
 * type before the value is inserted into the index.
 *
 * @param object object to convert
 */
- (NSObject *)convertIndexValue:(NSObject *)object;

/*
 * Returns the SQL string for generating the index table in the database.
 *
 * @param tablePrefix prefix to use for table names in SQL
 * @param indexName the name of the index to create SQL for
 */
- (NSString *)createSQLTemplateWithPrefix:(NSString *)tablePrefix indexName:(NSString *)indexName;

@end

/*
 * Interface implemented by classes to help indexers deal with issues arising from use of different
 * data types.
 */
@interface CDTIndexHelperBase : NSObject

/*
 * Return the correct CDTIndexHelper subclass (CDTIntegerIndexHelper, CDTStringIndexHelper, etc)
 * based on the type.
 *
 * In order to extend the types which indexes support, it will be necessary to augment the
 * implementation of this method.
 *
 * @param type the data type of the index
 *
 * @return the appropriate helper subclass, or nil if no subclass could be found.
 */
+ (CDTIndexHelper *)indexHelperForType:(CDTIndexType)type;

@end

/*
 * Default helper for integer types
 */
@interface CDTIntegerIndexHelper : CDTIndexHelper
;

@end

/*
 * Default helper for string types
 */
@interface CDTStringIndexHelper : CDTIndexHelper
;

@end
