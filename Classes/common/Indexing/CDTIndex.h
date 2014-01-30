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

@protocol CDTIndexHelperDelegate

-(NSObject*)convertIndexValue:(NSObject*)object;
-(NSString*)createSQLTemplateWithPrefix:(NSString*)tablePrefix
                              indexName:(NSString*)indexName;
-(NSString*)typeName;

@end

@interface CDTIndexHelperBase : NSObject

-(id)initWithType:(CDTIndexType)type;

@end

typedef CDTIndexHelperBase<CDTIndexHelperDelegate> CDTIndexHelper;

@interface CDTIntegerIndexHelper : CDTIndexHelper;

@end

@interface CDTStringIndexHelper : CDTIndexHelper;

@end
