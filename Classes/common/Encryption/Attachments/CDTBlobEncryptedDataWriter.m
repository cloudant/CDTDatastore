//
//  CDTBlobEncryptedDataWriter.m
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

#import "CDTBlobEncryptedDataWriter.h"

#import "CDTBlobEncryptedDataUtils.h"
#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTBlobDataWriter.h"

#import "CDTLogging.h"

@interface CDTBlobEncryptedDataWriter ()

@property (strong, nonatomic, readonly) NSData *key;
@property (strong, nonatomic, readonly) CDTBlobDataWriter *writer;

@end

@implementation CDTBlobEncryptedDataWriter

#pragma mark - Init object
- (instancetype)init { return [self initWithEncryptionKey:nil]; }

- (instancetype)initWithEncryptionKey:(CDTEncryptionKey *)encryptionKey
{
    self = [super init];
    if (self) {
        if (encryptionKey) {
            _key = encryptionKey.data;
            _writer = [CDTBlobDataWriter writer];
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Encryption key is mandatory");

            self = nil;
        }
    }

    return self;
}

#pragma mark - CDTBlobWriter methods
- (NSData *)sha1Digest { return self.writer.sha1Digest; }

- (void)useData:(NSData *)data
{
    NSData *encryptedData = nil;
    if (data) {
        NSData *iv = CDTBlobEncryptedDataDefaultIV();
        encryptedData = [CDTEncryptionKeychainUtils doEncrypt:data withKey:self.key iv:iv];
    }

    [self.writer useData:encryptedData];
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error
{
    return [self.writer writeToFile:path error:error];
}

#pragma mark - Public class methods
+ (instancetype)writerWithEncryptionKey:(CDTEncryptionKey *)encryptionKey
{
    return [[[self class] alloc] initWithEncryptionKey:encryptionKey];
}

@end
