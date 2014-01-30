//
//  CDTIndex.m
//
//
//  Created by Thomas Blench on 27/01/2014.
//
//

#import "CDTIndex.h"

@implementation CDTIndex

- (id)initWithIndexName:(NSString*)indexName
           lastSequence:(long)lastSequence
              fieldType:(CDTIndexType)fieldType
{
    self = [super init];
    if (self) {
        _indexName = indexName;
        _lastSequence = lastSequence;
        _fieldType = fieldType;
    }
    return self;
}

@end

@implementation CDTIndexHelperBase

-(CDTIndexHelper*)initWithType:(CDTIndexType)type
{
    // TODO smarter way of dispatching depending on the type
    switch(type)
    {
        case CDTIndexTypeInteger:
            return [[CDTIntegerIndexHelper alloc] init];
            break;
        case CDTIndexTypeString:
            return [[CDTStringIndexHelper alloc] init];
            break;
    }
    return nil;
}

@end

@implementation CDTIntegerIndexHelper

-(BOOL)valueSupported:(NSObject*)value
{
    return ([value isKindOfClass: [NSNumber class]]);
}

-(NSString*)createSQLTemplateWithPrefix:(NSString*)tablePrefix
                              indexName:(NSString*)indexName
{
    NSString *tableName = [tablePrefix stringByAppendingString:indexName];
    NSString *SQL_INTEGER_INDEX = @"CREATE TABLE %@ ( "
    @"docid TEXT NOT NULL, "
    @"value INTEGER NOT NULL, "
    @"UNIQUE(docid, value) ON CONFLICT IGNORE ); "
    @"CREATE INDEX %@_value_docid ON %@(value, docid);";
    return [NSString stringWithFormat:SQL_INTEGER_INDEX,
            tableName,
            tableName,
            tableName];
}

-(NSString*)typeName
{
    return @"INTEGER";
}

-(NSObject*)convertIndexValue:(NSObject*)object;
{
    if ([object isKindOfClass: [NSString class]]) {
        NSScanner* scan = [NSScanner scannerWithString:(NSString*)object];
        int val;
        [scan scanInt:&val];
        if ([scan isAtEnd]) {
            return [NSNumber numberWithInt:val];
        }
    }
    if ([object isKindOfClass: [NSNumber class]]) {
        return object;
    }
    return nil;
}

@end

@implementation CDTStringIndexHelper

-(NSString*)createSQLTemplateWithPrefix:(NSString*)tablePrefix
                              indexName:(NSString*)indexName
{
    NSString *tableName = [tablePrefix stringByAppendingString:indexName];
    NSString *SQL_INTEGER_INDEX = @"CREATE TABLE %@ ( "
    @"docid TEXT NOT NULL, "
    @"value TEXT NOT NULL, "
    @"UNIQUE(docid, value) ON CONFLICT IGNORE ); "
    @"CREATE INDEX %@_value_docid ON %@(value, docid);";
    
    return [NSString stringWithFormat:SQL_INTEGER_INDEX,
            tableName,
            tableName,
            tableName];
}

-(NSString*)typeName
{
    return @"STRING";
}

-(NSObject*)convertIndexValue:(NSObject*)object;
{
    if ([object isKindOfClass: [NSString class]]) {
        return object;
    }
    return nil;
}

@end

