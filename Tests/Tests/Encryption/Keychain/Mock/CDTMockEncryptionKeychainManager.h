//
//  CDTMockEncryptionKeychainManager.h
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

#import <Foundation/Foundation.h>

#import "CDTEncryptionKey.h"

#define CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_LOADKEY nil
#define CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_GENERATEANDSAVEKEY nil
#define CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_KEYEXISTS NO
#define CDTMOCKENCRYPTIONKEYCHAINMANAGER_DEFAULT_CLEARKEY YES

@interface CDTMockEncryptionKeychainManager : NSObject

@property (assign, nonatomic) BOOL loadKeyUsingPasswordExecuted;
@property (strong, nonatomic) CDTEncryptionKey *loadKeyUsingPasswordResult;

@property (assign, nonatomic) BOOL generateAndSaveKeyProtectedByPasswordExecuted;
@property (strong, nonatomic) CDTEncryptionKey *generateAndSaveKeyProtectedByPasswordResult;

@property (assign, nonatomic) BOOL keyExistsExecuted;
@property (assign, nonatomic) BOOL keyExistsResult;

@property (assign, nonatomic) BOOL clearKeyExecuted;
@property (assign, nonatomic) BOOL clearKeyResult;

- (CDTEncryptionKey *)loadKeyUsingPassword:(NSString *)password;
- (CDTEncryptionKey *)generateAndSaveKeyProtectedByPassword:(NSString *)password;
- (BOOL)keyExists;
- (BOOL)clearKey;

@end
