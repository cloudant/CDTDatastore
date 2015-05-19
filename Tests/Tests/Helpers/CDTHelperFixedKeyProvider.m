//
//  CDTHelperFixedKeyProvider.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 23/02/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTHelperFixedKeyProvider.h"

@interface CDTHelperFixedKeyProvider ()

@property (strong, nonatomic, readonly) CDTEncryptionKey *fixedKey;

@end

@implementation CDTHelperFixedKeyProvider

#pragma mark - Init object
- (instancetype)init
{
    char buffer[CDTENCRYPTIONKEY_KEYSIZE];
    memset(buffer, '*', sizeof(buffer));
    
    NSData *key = [NSData dataWithBytes:buffer length:sizeof(buffer)];
    
    return [self initWithKey:key];
}

- (instancetype)initWithKey:(NSData *)key
{
    self = [super init];
    if (self) {
        _fixedKey = [CDTEncryptionKey encryptionKeyWithData:key];
    }

    return self;
}

#pragma mark - CDTEncryptionKeyProvider methods
- (CDTEncryptionKey *)encryptionKey { return self.fixedKey; }

#pragma mark - Public methods
- (instancetype)negatedProvider
{
    const char *fixedKeyBytes = self.fixedKey.bytes;

    char negatedFixedKeyBytes[CDTENCRYPTIONKEY_KEYSIZE];
    for (NSUInteger i = 0; i < sizeof(negatedFixedKeyBytes); i++) {
        negatedFixedKeyBytes[i] = ~fixedKeyBytes[i];
    }

    NSData *negatedFixedKey =
        [NSData dataWithBytes:negatedFixedKeyBytes length:sizeof(negatedFixedKeyBytes)];

    return [[CDTHelperFixedKeyProvider alloc] initWithKey:negatedFixedKey];
}

@end
