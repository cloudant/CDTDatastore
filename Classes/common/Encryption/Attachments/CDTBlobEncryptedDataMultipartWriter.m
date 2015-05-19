//
//  CDTBlobEncryptedDataMultipartWriter.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 18/05/2015.
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

#import "CDTBlobEncryptedDataMultipartWriter.h"

#import "CDTBlobEncryptedDataWriter.h"

#import "CDTLogging.h"

@interface CDTBlobEncryptedDataMultipartWriter ()

@property (strong, nonatomic, readonly) CDTEncryptionKey *encryptionKey;

@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSMutableData *mutableData;

@property (strong, nonatomic) NSData *sha1Digest;

@end

@implementation CDTBlobEncryptedDataMultipartWriter

#pragma mark - Init object
- (instancetype)init { return [self initWithEncryptionKey:nil]; }

- (instancetype)initWithEncryptionKey:(CDTEncryptionKey *)encryptionKey
{
    self = [super init];
    if (self) {
        if (encryptionKey) {
            _encryptionKey = encryptionKey;

            _path = nil;
            _mutableData = nil;

            _sha1Digest = nil;
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Encryption key is mandatory");

            self = nil;
        }
    }

    return self;
}

#pragma mark - CDTBlobMultipartWriter methods
- (BOOL)isBlobOpen { return (self.path != nil); }

- (BOOL)openBlobAtPath:(NSString *)path
{
    if ([self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is already open");

        return NO;
    }

    if (!path || ([path length] == 0)) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Supply a path");

        return NO;
    }

    self.path = path;
    self.mutableData = [NSMutableData data];
    self.sha1Digest = nil;

    return YES;
}

- (BOOL)addData:(NSData *)data
{
    if (!data) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Data is mandatory");

        return NO;
    }

    if (![self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is not open");

        return NO;
    }

    [self.mutableData appendData:data];

    return YES;
}

- (BOOL)closeBlob
{
    if (![self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is not open");

        return NO;
    }

    BOOL success = YES;
    if (self.mutableData.length > 0) {
        CDTBlobEncryptedDataWriter *writer =
            [CDTBlobEncryptedDataWriter writerWithEncryptionKey:self.encryptionKey];

        success = (writer != nil);
        if (!success) {
            CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Encrypted Data writer not created");
        } else {
            [writer useData:self.mutableData];

            success = [writer writeToFile:self.path error:nil];
            if (success) {
                self.sha1Digest = writer.sha1Digest;
            }
        }
    }

    self.path = nil;
    self.mutableData = nil;

    return success;
}

#pragma mark - Public class methods
+ (instancetype)multipartWriterWithEncryptionKey:(CDTEncryptionKey *)encryptionKey
{
    return [[[self class] alloc] initWithEncryptionKey:encryptionKey];
}

@end
