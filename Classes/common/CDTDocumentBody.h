//
//  CSDatastoreBody.h
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TD_Body;
@class TD_Revision;

/**
 * Represents the JSON content of a document revision.
 *
 * Can return the JSON as an NSData object or a NSDictionary.
 */
@interface CDTDocumentBody : NSObject

-(id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic,strong,readonly) TD_Body *td_body;

-(TD_Revision*)TD_RevisionValue;

@end
