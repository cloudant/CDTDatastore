//
//  CDTIndexer.h
//  
//
//  Created by Thomas Blench on 29/01/2014.
//
//

#import <Foundation/Foundation.h>
#import "CDTIndex.h"

@class CDTDocumentRevision;

@protocol CDTIndexer

-(id)initWithFieldName:(NSString*)fieldName
                  type:(CDTIndexType)type;

-(NSArray*)indexWithIndexName:(NSString*)indexName
                     revision:(CDTDocumentRevision*)revision;

@end
