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

#import "TD_Revision.h"

@class TD_RevisionList;
@class CDTMutableDocumentRevision;

/**
 * Represents a single revision of a document in a datastore.
 */
@interface CDTDocumentRevision : NSObject

/** Document ID for this document revision. */
@property (nonatomic,strong,readonly) NSString *docId;
/** Revision ID for this document revision. */
@property (nonatomic,strong,readonly) NSString *revId;

/** `YES` if this document revision is deleted. */
@property (nonatomic,readonly) BOOL deleted;

@property (nonatomic,readonly) SequenceNumber sequence;


/**
 Creates an CDTDocumentRevision from JSON Data
 The json data is expected to have been outputted from
 cloudant or a CouchDB instance.
 
 @param json Json data to create an object from
 @param error points to an NSError in case of error
 
 @return new CDTDocument Revision instance
*/
+(CDTDocumentRevision*)createRevisionFromJson:(NSData*)json error:(NSError * __autoreleasing *) error;

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *) revId
              body:(NSDictionary *)body
           deleted:(BOOL) deleted
       attachments:(NSDictionary *) attachments;

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *) revId
              body:(NSDictionary *)body
           deleted:(BOOL) deleted;

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *)revId
              body:(NSDictionary *)body
           deleted:(BOOL)deleted
          sequence:(SequenceNumber)sequence;

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *)revId
              body:(NSDictionary *)body
           deleted:(BOOL)deleted
       attachments:(NSDictionary *)attachments
          sequence:(SequenceNumber)sequence;

/** 
 Return document content as an NSData object.
 
 This is often the format an object mapper will require.

 @param error will point to an NSError object in case of error.
 
 @return document content as an NSData object.
 */
-(NSData*)documentAsDataError:(NSError * __autoreleasing *)error;

/**
 Return document content as an NSDictionary object.

 @return document content as an NSDictionary object.
 */
-(NSDictionary*)documentAsDictionary __deprecated;

/**
 Return a mutable copy of this document.
 
 @return mutable copy of this document
 */
-(CDTMutableDocumentRevision*)mutableCopy;

-(NSDictionary*)body;

-(NSDictionary*)attachments;

@end
