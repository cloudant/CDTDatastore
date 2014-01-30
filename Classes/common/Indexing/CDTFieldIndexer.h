//
//  CDTFieldIndexer.h
//  
//
//  Created by Thomas Blench on 06/02/2014.
//
//

#import <Foundation/Foundation.h>

#import "CDTIndexer.h"

@interface CDTFieldIndexer : NSObject<CDTIndexer>

{
    NSString *_fieldName;
    CDTIndexHelper *_helper;
    CDTIndexType _type;
}

@end
