//
//  CDTSQLiteWrapper.h
//  
//
//  Created by Thomas Blench on 28/01/2014.
//
//

#import <Foundation/Foundation.h>

@interface CDTSQLiteHelpers : NSObject

+(NSString*)makeUpdatePlaceholders:(NSDictionary*)dict;
+(NSString*)makeInsertPlaceholders:(NSDictionary*)dict;

@end

