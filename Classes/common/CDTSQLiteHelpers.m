//
//  CDTSQLiteWrapper.m
//
//
//  Created by Thomas Blench on 28/01/2014.
//
//

#import "CDTSQLiteHelpers.h"

// utility to help join clauses with AND/OR, lists with commas, etc
@implementation CDTStringJoiner : NSObject

-(id)initWithSeparator:(NSString*)sep
{
    self = [super init];
    if (self) {
        _first = TRUE;
        _sep = sep;
    }
    return self;
}

-(void)add:(NSString*)part
{
    // ignore empty parts
    if (!part || [part length] == 0) {
        return;
    }
    if (_first) {
        _string = [NSMutableString stringWithString:part];
        _first = FALSE;
    } else {
        [_string appendString:_sep];
        [_string appendString:part];
    }
}

@end

@implementation CDTSQLiteHelpers

+(NSString*)makeUpdatePlaceholders:(NSDictionary*)dict
{
    CDTStringJoiner *joiner = [[CDTStringJoiner alloc] initWithSeparator:@", "];
    for (NSString *key in [dict keyEnumerator]) {
        [joiner add:[NSString stringWithFormat:@"%@=:%@", key, key]];
    }
    return [joiner string];
}

+(NSString*)makeInsertPlaceholders:(NSDictionary*)dict
{
    CDTStringJoiner *joiner = [[CDTStringJoiner alloc] initWithSeparator:@", "];
    for (NSString *key in [dict keyEnumerator]) {
        [joiner add:[NSString stringWithFormat:@":%@", key]];
    }
    return [joiner string];
}

@end
