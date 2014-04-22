//
//  CDTDatastore+Attachments.h
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

#import "CDTDatastore.h"

@class CDTAttachment;

@interface CDTDatastore (Attachments)

/**
 Returns the names of attachments for a document revision.

 @return NSArray of CDTAttachment
 */
-(NSArray*) attachmentsForRev:(CDTDocumentRevision*)rev;

/**
 Returns attachment `name` for the revision.

 @return CDTAttachment or nil no attachment with that name.
 */
-(CDTAttachment*) attachmentNamed:(NSString*)name
                           forRev:(CDTDocumentRevision*)rev;

/**
 Set the content of attachments on a document, creating
 new revision of the document.

 Existing attachments with the same name will be replaced,
 new attachments will be created, and attachments already
 existing on the document which are not included in
 `attachments` will remain as attachments on the document.

 @return New revision.
 */
-(CDTDocumentRevision*) updateAttachments:(NSArray*)attachments
                                   forRev:(CDTDocumentRevision*)rev;

/**
 Remove attachments `names` from a document, creating a new revision.

 @param rev rev to update.
 @param names NSArray of NSStrings, each being an attachment name
 to remove
 @return New revision.
 */
-(CDTDocumentRevision*) removeAttachments:(NSArray*)attachmentNames
                                  fromRev:(CDTDocumentRevision*)rev;

@end
