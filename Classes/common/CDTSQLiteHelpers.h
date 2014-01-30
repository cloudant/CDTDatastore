//
//  CDTSQLiteWrapper.h
//  
//
//  Created by Thomas Blench on 28/01/2014.
//
//

#import <Foundation/Foundation.h>

@interface CDTStringJoiner : NSObject

-(id)initWithSeparator:(NSString*)sep;
-(void)add:(NSString*)part;

@property (nonatomic,strong,readonly) NSString *sep;
@property (nonatomic,strong,readonly) NSMutableString *string;
@property BOOL first;

@end

@interface CDTSQLiteHelpers : NSObject

+(NSString*)makeUpdatePlaceholders:(NSDictionary*)dict;
+(NSString*)makeInsertPlaceholders:(NSDictionary*)dict;

@end

