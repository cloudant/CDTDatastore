//
//  CDTAttachment.h
//
//
//  Created by Michael Rhodes on 24/03/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <Foundation/Foundation.h>

#import "CDTDefines.h"

#import "CDTBlobReader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Base class for attachments in the datastore.

 This object is an abstract class, in use at least. Attachments
 that are read from the database will always be CDTSavedAttachment
 objects, indicating that they've come from the database.
 Attachments to be added to the database will be objects of type,
 by naming convention alone, CDTUnsaved<something>Attachment.

 The idea is that unsaved attachments can come from various places,
 and developers using this library can subclass CDTAttachment,
 implementing the -getInputStream method as needed for their
 needs. The library provides some unsaved attachment classes
 for convenience and as examples:

   - CDTUnsavedDataAttachment: provides a wrapped around an
       NSData instance to be added as an attachment.


 */
@interface CDTAttachment : NSObject

// common
@property (nonatomic, strong, readonly) NSString *name;

/** Mimetype string */
@property (nonatomic, strong, readonly) NSString *type;

/* Size in bytes, may be -1 if not known (e.g., HTTP URL for new attachment) */
@property (nonatomic, readonly) NSInteger size;

/** Subclasses should call this to initialise instance vars */
- (instancetype)initWithName:(NSString *)name
                        type:(NSString *)type
                        size:(NSInteger)size;

/** Get unopened input stream for this attachment */
- (nullable NSData *)dataFromAttachmentContent;

@end

/**
 An attachment retrieved from the datastore.

 These attachment objects are immutable as they represent
 revisions already in the database.
 */
@interface CDTSavedAttachment : CDTAttachment

@property (nonatomic, readonly) NSInteger revpos;
@property (nonatomic, readonly) SequenceNumber sequence;
@property (nonatomic, readonly) TDAttachmentEncoding encoding;

/** sha of file, used for file path on disk. */
@property (nonatomic, readonly) NSData *key;

- (instancetype)initWithBlob:(id<CDTBlobReader>)blob
                        name:(NSString *)name
                        type:(NSString *)type
                        size:(NSInteger)size
                      revpos:(NSInteger)revpos
                    sequence:(SequenceNumber)sequence
                         key:(NSData *)keyData
                    encoding:(TDAttachmentEncoding)encoding;

@end

/**
 An attachment to be inserted into the database, using
 data from an NSData instance as input data for the attachment.
 */
@interface CDTUnsavedDataAttachment : CDTAttachment

/**
 Create a new unsaved attachment using an NSData instance
 as the source of attachment data.
 */
- (instancetype)initWithData:(NSData *)data
                        name:(NSString *)name
                        type:(NSString *)type;

@end

/**
 An attachment to be inserted into the database, using
 data from a file as input data for the attachment.
 */
@interface CDTUnsavedFileAttachment : CDTAttachment

- (nullable instancetype)initWithPath:(NSString *)filePath
                                 name:(NSString *)name
                                 type:(NSString *)type;

@end
NS_ASSUME_NONNULL_END
