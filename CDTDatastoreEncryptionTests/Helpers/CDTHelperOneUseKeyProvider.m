//
//  CDTHelperOneUseKeyProvider.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 27/02/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTHelperOneUseKeyProvider.h"

@interface CDTHelperOneUseKeyProvider ()

@property (strong, nonatomic) CDTEncryptionKey *thisKey;

@end

@implementation CDTHelperOneUseKeyProvider

#pragma mark - Init object
- (instancetype)init
{
    self = [super init];
    if (self) {
        _thisKey = nil;
    }

    return self;
}

#pragma mark - CDTEncryptionKeyProvider methods
- (CDTEncryptionKey *)encryptionKey
{
    CDTEncryptionKey *key = self.thisKey;
    if (!self.thisKey) {
        char buffer[CDTENCRYPTIONKEY_KEYSIZE];
        memset(buffer, '*', sizeof(buffer));
        
        NSData *data = [NSData dataWithBytes:buffer length:sizeof(buffer)];
        
        self.thisKey = [CDTEncryptionKey encryptionKeyWithData:data];
    }

    return key;
}

@end
