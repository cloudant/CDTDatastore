//
//  CDTMockEncryptionKeychainManager.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 21/04/2015.
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

#import "CDTMockEncryptionKeychainManager.h"

@interface CDTMockEncryptionKeychainManager ()

@end

@implementation CDTMockEncryptionKeychainManager

#pragma mark - Init object
- (instancetype)init
{
    self = [super init];
    if (self) {
        _loadKeyUsingPasswordExecuted = NO;
        _loadKeyUsingPasswordResult = CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_LOADKEY;

        _generateAndSaveKeyProtectedByPasswordExecuted = NO;
        _generateAndSaveKeyProtectedByPasswordResult =
            CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_GENERATEANDSAVEKEY;

        _keyExistsExecuted = NO;
        _keyExistsResult = CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_KEYEXISTS;

        _clearKeyExecuted = NO;
        _clearKeyResult = CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_CLEARKEY;
    }

    return self;
}

#pragma mark - Public methods
- (NSData *)loadKeyUsingPassword:(NSString *)password
{
    self.loadKeyUsingPasswordExecuted = YES;

    return self.loadKeyUsingPasswordResult;
}

- (NSData *)generateAndSaveKeyProtectedByPassword:(NSString *)password
{
    self.generateAndSaveKeyProtectedByPasswordExecuted = YES;

    return self.generateAndSaveKeyProtectedByPasswordResult;
}

- (BOOL)keyExists
{
    self.keyExistsExecuted = YES;

    return self.keyExistsResult;
}

- (BOOL)clearKey
{
    self.clearKeyExecuted = YES;

    return self.clearKeyResult;
}

@end
