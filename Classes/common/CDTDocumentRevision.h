//
//  CDTDocumentRevision.h
//  CloudantSync
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TD_Revision;
@class TD_RevisionList;

/**
 * Represents a single revision of a document in a datastore.
 */
@interface CDTDocumentRevision : NSObject

@property (nonatomic,strong,readonly) NSString *docId;
@property (nonatomic,strong,readonly) NSString *revId;

@property (nonatomic,strong,readonly) NSDictionary *attachments;
@property (nonatomic,strong,readonly) NSString *localSeq;
@property (nonatomic,strong,readonly) TD_RevisionList *revs;
@property (nonatomic,strong,readonly) NSArray *revsInfo;
@property (nonatomic,strong,readonly) NSArray *conflicts;

@property (nonatomic,strong,readonly) TD_Revision *td_rev;


-(id)initWithTDRevision:(TD_Revision*)rev;


-(NSData*)documentAsDataError:(NSError * __autoreleasing *)error;
-(NSDictionary*)documentAsDictionary;

@end
