//
//  CDTBlobEncryptedDataReader.m
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

#import "CDTBlobEncryptedDataReader.h"

#import "CDTBlobEncryptedDataUtils.h"
#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTLogging.h"

@interface CDTBlobEncryptedDataReader ()

@property (strong, nonatomic, readonly) NSString *path;
@property (strong, nonatomic, readonly) NSData *key;
@property (strong, nonatomic, readonly) NSData *iv;

@end

@implementation CDTBlobEncryptedDataReader

- (instancetype)init { return [self initWithPath:nil encryptionKey:nil]; }

- (instancetype)initWithPath:(NSString *)path encryptionKey:(CDTEncryptionKey *)encryptionKey
{
    self = [super init];
    if (self) {
        if (path && ([path length] > 0) && encryptionKey) {
            _path = path;
            _key = encryptionKey.data;
            _iv = CDTBlobEncryptedDataDefaultIV();
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"All params are mandatory");

            self = nil;
        }
    }

    return self;
}

#pragma mark - CDTBlobReader methods
- (NSData *)dataWithError:(NSError **)error
{
    NSData *data = nil;

    NSError *thisError = nil;
    NSData *encryptedData = [NSData dataWithContentsOfFile:self.path
                                                   options:NSDataReadingMappedIfSafe
                                                     error:&thisError];
    if (encryptedData) {
        data = [CDTEncryptionKeychainUtils doDecrypt:encryptedData withKey:self.key iv:self.iv];
    } else {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Data object could not be created with file %@: %@",
                    self.path, thisError);

        if (error) {
            *error = thisError;
        }
    }

    return data;
}

- (NSInputStream *)inputStreamWithOutputLength:(UInt64 *)outputLength
{
    NSData *data = [self dataWithError:nil];
    if (!data) {
        return nil;
    }

    if (outputLength) {
        *outputLength = data.length;
    }

    return [NSInputStream inputStreamWithData:data];
}

#pragma mark - Public class methods
+ (instancetype)readerWithPath:(NSString *)path encryptionKey:(CDTEncryptionKey *)encryptionKey
{
    return [[[self class] alloc] initWithPath:path encryptionKey:encryptionKey];
}

@end
