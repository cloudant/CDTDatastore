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

#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>

#import "CDTBlobDataMultipartWriter.h"

#import "CDTLogging.h"

@interface CDTBlobDataMultipartWriter () {
    SHA_CTX _shaCtx;
}

@property (strong, nonatomic) NSFileHandle *outFileHandle;
@property (strong, nonatomic) NSData *sha1Digest;
@property (assign, nonatomic) BOOL wasDataAdded;

@end

@implementation CDTBlobDataMultipartWriter

#pragma mark - Init object
- (instancetype)init
{
    self = [super init];
    if (self) {
        _outFileHandle = nil;
        _sha1Digest = nil;
        _wasDataAdded = NO;
    }

    return self;
}

#pragma mark - Memory management
- (void)dealloc { [self releaseBlob]; }

#pragma mark - CDTBlobMultipartWriter methods
- (BOOL)isBlobOpen { return (self.outFileHandle != nil); }

- (BOOL)openBlobAtPath:(NSString *)path
{
    BOOL success = ![self isBlobOpen];
    if (!success) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is already open");
    } else {
        self.outFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];

        success = [self isBlobOpen];
        if (success) {
            self.sha1Digest = nil;
            self.wasDataAdded = NO;

            SHA1_Init(&_shaCtx);
        }
    }

    return success;
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

    self.wasDataAdded = YES;

    [self.outFileHandle writeData:data];

    SHA1_Update(&_shaCtx, data.bytes, data.length);

    return YES;
}

- (BOOL)closeBlob
{
    if (![self isBlobOpen]) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Blob is not open");

        return NO;
    }

    if (self.wasDataAdded) {
        unsigned char digest[SHA_DIGEST_LENGTH];
        SHA1_Final(digest, &_shaCtx);

        self.sha1Digest = [NSData dataWithBytes:&digest length:sizeof(digest)];
    }

    [self releaseBlob];
    
    return YES;
}

#pragma mark - Private methods
- (void)releaseBlob
{
    if ([self isBlobOpen]) {
        [self.outFileHandle closeFile];
        self.outFileHandle = nil;
    }
}

#pragma mark - Public class methods
+ (instancetype)multipartWriter { return [[[self class] alloc] init]; }

@end
