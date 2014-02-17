//
//  CDTDocumentRevision.h
//  CloudantSync
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

@class TD_Revision;
@class TD_RevisionList;

/**
 * Represents a single revision of a document in a datastore.
 */
@interface CDTDocumentRevision : NSObject

@property (nonatomic,strong,readonly) NSString *docId;
@property (nonatomic,strong,readonly) NSString *revId;

@property (nonatomic,readonly) BOOL deleted;

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
