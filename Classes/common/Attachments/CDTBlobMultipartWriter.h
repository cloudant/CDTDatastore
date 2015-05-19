//
//  CDTBlobMultipartWriter.h
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 14/05/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <Foundation/Foundation.h>

/**
 This protocol defines the methods to add/append data to an attachment.
 */
@protocol CDTBlobMultipartWriter <NSObject>

/**
 SHA1 digest of the data added to the attachment.
 
 It will be set to nil after the blob is open and a value will be assigned only after the blob is
 closed (and if some data was added before).
 */
@property (strong, nonatomic, readonly) NSData *sha1Digest;

/**
 @return YES if the attachment was open before or NO in other case
 */
- (BOOL)isBlobOpen;

/**
 Prepare an attachment to write data in it.
 
 If the attachment is already open, it has to fail. Also, after opening an attachment, the file
 pointer is moved to the beginning of the file.
 
 @param path Path where the attachment is located
 
 @return YES if the attachment was open or NO in other case
 */
- (BOOL)openBlobAtPath:(NSString *)path;

/**
 Add data at the file pointer's current position and move it forward.
 
 If the attachment is not open, it has to fail.
 
 @param data Data to append to the attachment
 
 @return YES if the data was added or NO in other case.
 */
- (BOOL)addData:(NSData *)data;

/**
 Use this method to signal that there are no more data to add.
 
 If the attachment is not open, it has to fail.
 
 @return YES if all added data is in the attachment.
 */
- (BOOL)closeBlob;

@end
