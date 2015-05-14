//
//  CDTBlobDataWriter.h
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

#import "CDTBlobWriter.h"

extern NSString *const CDTBlobDataWriterErrorDomain;

typedef NS_ENUM(NSInteger, CDTBlobDataWriterError) {
    CDTBlobDataWriterErrorNoData,
    CDTBlobDataWriterErrorNoPath
};

/**
 Use this class to write data to an attachment. The data provided is written to the attachment
 without further processing, i.e. it is not encrypted.
 
 @see CDTBlobWriter
*/
@interface CDTBlobDataWriter : NSObject <CDTBlobWriter>

+ (instancetype)writer;

@end
