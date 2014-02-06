//
//  CDTIndex.h
//
//
//  Created by Thomas Blench on 27/01/2014.
//
//

#import <Foundation/Foundation.h>

/**
 * <p>
 * The datatype used for an index.
 * </p>
 * <p>
 * CDTIndexTypeInteger supports any NSNumber type.
 * Additionally NSStrings are supported, if they can be successfully converted to an NSNumber.
 * Strings which fail conversion are returned as nil and are not indexed.
 * </p>
 * <p>
 * CDTIndexTypeString supports only NSStrings.
 * No conversion is performed.
 * </p>
 */
typedef NS_ENUM(NSInteger, CDTIndexType) {
    CDTIndexTypeInteger,
    CDTIndexTypeString
};

@interface CDTIndex : NSObject

@property (nonatomic,strong,readonly) NSString *indexName;
@property (nonatomic,readonly) long lastSequence;
@property (nonatomic,readonly) CDTIndexType fieldType;

- (id)initWithIndexName:(NSString*)indexName
           lastSequence:(long)lastSequence
              fieldType:(CDTIndexType)fieldType;

@end

/**
 * <p>
 * Protocol adopted by classes to help indexers deal with issues arising from use of different data types.
 * </p>
 * <p>
 * In order to extend the types which indexes support, it will be necessary to create new classes conforming to this protocol.
 * Additionally, -(CDTIndexHelper*)initWithType:(CDTIndexType)type will need to be extended to support the new helper class.
 * </p>
 */
@protocol CDTIndexHelperDelegate

/**
 * <p>
 * Converts the given NSOjbect to a value suitable for inserting
 * into the index.
 * </p>
 * <p>Each class conforming to the CDTIndexHelperDelegate converts values to index into a uniform
 * data type before the value is inserted into the index.
 * </p>
 */
-(NSObject*)convertIndexValue:(NSObject*)object;

/**
 * Returns the SQL string for generating the index table in the database.
 */
-(NSString*)createSQLTemplateWithPrefix:(NSString*)tablePrefix
                              indexName:(NSString*)indexName;

/**
 * Returns the SQL type name for this type.
 */
-(NSString*)typeName;

@end

/**
 * <p>
 * Interface implemented by classes to help indexers deal with issues arising from use of different data types.
 * </p>
 * <p>
 * It will not generally be necessary to override -(id)initWithType:(CDTIndexType)type;
 * </p>
 */
 @interface CDTIndexHelperBase : NSObject

-(id)initWithType:(CDTIndexType)type;

@end

/**
 * <p>
 * Typedef for convenience - all helper classes should extend this type as they will need to implement the CDTIndexHelperBase interface and conform to the CDTIndexHelperDelegate protocol
 * </p>
 */
typedef CDTIndexHelperBase<CDTIndexHelperDelegate> CDTIndexHelper;

/**
 * <p>
 * Default helper for integer types
 * </p>
 */
@interface CDTIntegerIndexHelper : CDTIndexHelper;

@end

/**
 * <p>
 * Default helper for string types
 * </p>
 */
@interface CDTStringIndexHelper : CDTIndexHelper;

@end
