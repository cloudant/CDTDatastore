//
//  CDTBlobWriter.h
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 06/05/2015.
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
 This protocol defines the methods to create or overwrite an attachment.
 */
@protocol CDTBlobWriter

/**
 SHA1 digest of the data ready to store in the attachment.
 
 It will be nil if there is no data or a buffer with size MD5_DIGEST_LENGTH in case some data
 was supplied before.
 */
@property (strong, nonatomic, readonly) NSData *sha1Digest;

/**
 Use this method to inform/supply the data to store in the attachment.

 @param data Data to store in the attachment
 */
- (void)useData:(NSData *)data;

/**
 Overwrite the content of an attachment with the data provided before. If the file does not exist,
 it will create it.

 @param path Path to the attachment or where the attachment will be created
 @param error Output param that will point to an error (if there is any)

 @return YES (if the operation succeed) or NO (if there is an error)
 */
- (BOOL)writeToFile:(NSString *)path error:(NSError **)error;

@end
