//
//  CDTBlobRawData.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 05/05/2015.
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

#import "CDTBlobRawData.h"

#import "CDTLogging.h"

@interface CDTBlobRawData ()

@property (strong, nonatomic, readonly) NSData *rawData;

@end

@implementation CDTBlobRawData

#pragma mark - Init object
- (instancetype)init { return [self initWithRawData:nil]; }

- (instancetype)initWithRawData:(NSData *)rawData
{
    self = [super init];
    if (self) {
        if (rawData) {
            _rawData = rawData;
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Param is mandatory");

            self = nil;
        }
    }

    return self;
}

#pragma mark - CDTBlob methods
- (NSData *)data { return self.rawData; }

@end
