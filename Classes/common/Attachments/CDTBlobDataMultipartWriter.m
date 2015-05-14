//
//  CDTBlobDataMultipartWriter.m
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

#import "CDTBlobDataMultipartWriter.h"

#import "CDTLogging.h"

@interface CDTBlobDataMultipartWriter ()

@property (strong, nonatomic) NSFileHandle *outFileHandle;

@end

@implementation CDTBlobDataMultipartWriter

#pragma mark - Memory management
- (void)dealloc { [self closeBlob]; }

#pragma mark - CDTBlobMultipartWriter methods
- (BOOL)isBlobOpen { return (self.outFileHandle != nil); }

- (BOOL)openBlobAtPath:(NSString *)path
{
    if ([self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is already open");

        return NO;
    }

    self.outFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];

    return [self isBlobOpen];
}

- (BOOL)addData:(NSData *)data
{
    if (![self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is already open");

        return NO;
    }

    [self.outFileHandle writeData:data];

    return YES;
}

- (void)closeBlob
{
    if (![self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is already open");

        return;
    }

    [self.outFileHandle closeFile];
    self.outFileHandle = nil;
}

#pragma mark - Public class methods
+ (instancetype)multipartWriter { return [[[self class] alloc] init]; }

@end
