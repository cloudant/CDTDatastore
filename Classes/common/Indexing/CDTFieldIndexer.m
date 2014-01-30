//
//  CDTFieldIndexer.m
//  
//
//  Created by Thomas Blench on 06/02/2014.
//
//

#import "CDTFieldIndexer.h"

#import "CDTDocumentRevision.h"

#import "TD_Revision.h"
#import "TD_Body.h"

@implementation CDTFieldIndexer

-(id)initWithFieldName:(NSString*)fieldName
                  type:(CDTIndexType)type
{
    self = [super init];
    if (self) {
        _fieldName = fieldName;
        _type = type;
        // we'll need a helper to do conversions
        _helper = [[CDTIndexHelper alloc] initWithType:type];
        
    }
    return self;
}

-(NSArray*)indexWithIndexName:(NSString*)indexName
                     revision:(CDTDocumentRevision*)revision
{
    NSObject *value = [[[[revision td_rev] body] properties] valueForKey:_fieldName];
    
    // convert value(s) to appropriate type and pack into array:
    
    // if type string: pack into array of 1
    // else it's an array
    
    // now iterate thru array and attempt to convert all values (convert for int, for string it's a noop)
    // if any conversions failed, they don't go into output array
    
    // return array now has converted value
    
    NSArray *inArray;
    NSMutableArray *outArray = [[NSMutableArray alloc] init];
    
    // TODO - other types?
    if ([value isKindOfClass: [NSString class]] || [value isKindOfClass: [NSNumber class]]) {
        inArray = @[value];
    } else if ([value isKindOfClass: [NSArray class]]) {
        inArray = (NSArray*)value;
    }
    
    for (NSString *rawValue in inArray) {
        NSObject *convertedValue = [_helper convertIndexValue:rawValue];
        if (convertedValue != nil) {
            [outArray addObject:convertedValue];
        }
    }
    
    return outArray;
}

@end
