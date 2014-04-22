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

/**
 Base class for attachments in the datastore.
 */
@interface CDTAttachment : NSObject

// common
@property (nonatomic,strong) NSString* name;

/** Mimetype string */
@property (nonatomic,strong) NSString* type;

/* Size in bytes, may be -1 if not known (e.g., HTTP URL for new attachment) */
@property (nonatomic) NSInteger size;

// get stream for file, caller must close() when done
-(NSInputStream*) getInputStream;

+(CDTAttachment*)attachmentWithData:(NSData*)data
                               name:(NSString*)name
                               type:(NSString*)type;

@end

/**
 An attachment retrieved from the datastore.
 
 These attachment objects are immutable as they represent
 revisions already in the database.
 */
@interface CDTSavedAttachment : CDTAttachment

@property (nonatomic) NSInteger revpos;
@property (nonatomic) NSInteger sequence;

/** sha of file, used for file path on disk. */
@property (nonatomic) NSData* key;

-initWithFilePath:(NSString*)filePath;

@end

/**
 An attachment to be inserted into the database.
 
 These attachments are created by application code, usually
 by class methods on CDTAttachment, and are passed to
 the -setAttachments method on CDTDatastore.
 */
@interface CDTUnsavedDataAttachment : CDTAttachment

/** For example, TBD exactly what to use. */
@property (nonatomic,strong) NSData* data;

@end
