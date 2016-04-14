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

#import "CDTDefines.h"
#import "CDTChangedObserver.h"

@class TD_RevisionList;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a single revision of a document in a datastore.
 */
@interface CDTDocumentRevision : NSObject <CDTChangedObserver>

/** Document ID for this document revision. */
@property (nullable, nonatomic, strong, readonly) NSString *docId;
/** Revision ID for this document revision. */
@property (nullable, nonatomic, strong, readonly) NSString *revId;

/** `YES` if this document revision is deleted. */
@property (nonatomic, readonly) BOOL deleted;

@property (nonatomic, readonly) SequenceNumber sequence;

@property (nonatomic, strong) NSMutableDictionary *body;
@property (nonatomic, strong) NSMutableDictionary *attachments;

@property (nonatomic, getter=isChanged) bool changed;

/**
 Indicates if this document revision contains all fields and attachments. If NO, datastore
 will refuse to save.

 This allows for document projections to conform to the CDTDocumentRevision API without
 risking their being saved to the datastore.
 */
- (BOOL)isFullRevision;

- (instancetype)initWithDocId:(nullable NSString *)docId
                   revisionId:(nullable NSString *)revId
                         body:(nullable NSDictionary *)body
                  attachments:(nullable NSDictionary *)attachments;

- (instancetype)initWithDocId:(nullable NSString *)docId
                   revisionId:(nullable NSString *)revId
                         body:(nullable NSDictionary *)body
                      deleted:(BOOL)deleted
                  attachments:(nullable NSDictionary *)attachments
                     sequence:(SequenceNumber)sequence;

/**
 Creates an CDTDocumentRevision from JSON Data
 The json data is expected to come from
 Cloudant or a CouchDB instance.
 
 @deprecated Method is deprecated and will be removed in 2.0, method was designed for a specific 
             internal usecase.

 @param json JSON data to create an object from
 @param documentURL the url of the document
 @param error points to an NSError in case of error

 @return new CDTDocumentRevision instance
*/
+ (nullable CDTDocumentRevision *)createRevisionFromJson:(NSDictionary *)jsonDict
                                             forDocument:(NSURL *)documentURL
                                                   error:(NSError *__autoreleasing __nullable * __nullable)error __attribute__((deprecated));
/**
 Create a new, blank revision which will have an ID generated on saving.
 */
+ (CDTDocumentRevision *)revision;

/**
 Create a new, blank revision with an assigned ID.
 */
+ (CDTDocumentRevision *)revisionWithDocId:(NSString *)docId;

/**
 Create a blank revision with a rev ID, which will be treated as an update when saving.

 In general, not that useful in day-to-day life, where updates will be made to document
 revisions retrieved from a datastore.

 Useful during testing and when it's not necessary to start with an existing revision's
 content.
 */
+ (CDTDocumentRevision *)revisionWithDocId:(NSString *)docId revId:(NSString *)revId;

/**
 Return document content as an NSData object.

 This is often the format an object mapper will require.

 @param error will point to an NSError object in case of error.

 @return document content as an NSData object.
 */
- (nullable NSData *)documentAsDataError:(NSError *__autoreleasing __nullable * __nullable)error;

/**
 Return a copy of this document.

 Dictionary and array objects in the `body` are deep-copied.

 The attachment array is copied, individual `CDTAttachment` objects are not.

 @return copy of this document
 */
- (CDTDocumentRevision *)copy;

@end

NS_ASSUME_NONNULL_END
