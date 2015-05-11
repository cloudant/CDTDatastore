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
 Define the methods to store data in an attachment without exposing its path.
 */
@protocol CDTBlobWriter <NSObject>

/**
 Overwrite the content of an attachment with the data provided as a parameter. If the file does
 not exist, it will create it.
 
 Notice that this method has to work properly with the other methods defined in this protocol, i.e.
 will it succeed or will it fail if the blob is open?
 
 @param data Data to store in the attachment
 @param error Output param that will point to an error (if there is any)
 
 @return YES (if the operation succeed) or NO (if there is an error)
 */
- (BOOL)createBlobWithData:(NSData *)data error:(NSError **)error;

/**
 @return YES if the attachment was open before or NO in other case
 */
- (BOOL)isBlobOpen;

/**
 Prepare an attachment to write data in it.
 
 @return YES if the attachment was open (or it was already open) or NO in other case
 */
- (BOOL)openBlobToAddData;

/**
 Add data to the end of the attachment.
 
 Although this protocol does not enforce it, the attachment should be open before adding data.
 
 @param data Data to append to the attachment
 
 @return YES if the data was added or NO in other case.
 */
- (BOOL)addData:(NSData *)data;

/**
 Use this method to signal that there are no more data to add.
 */
- (void)closeBlob;

@end
