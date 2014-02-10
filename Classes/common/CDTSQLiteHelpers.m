//
//  CDTSQLiteWrapper.m
//
//
//  Created by Thomas Blench on 28/01/2014.
//
//

#import "CDTSQLiteHelpers.h"

@implementation CDTSQLiteHelpers

+(NSString*)makeUpdatePlaceholders:(NSDictionary*)dict
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    for (NSString *key in [dict keyEnumerator]) {
        [arr addObject:[NSString stringWithFormat:@"%@=:%@", key, key]];
    }
    return [arr componentsJoinedByString:@", "];
}

+(NSString*)makeInsertPlaceholders:(NSDictionary*)dict
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    for (NSString *key in [dict keyEnumerator]) {
        [arr addObject:[NSString stringWithFormat:@":%@", key]];
    }
    return [arr componentsJoinedByString:@", "];
}

@end
