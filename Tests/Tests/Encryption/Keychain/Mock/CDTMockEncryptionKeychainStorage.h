//
//  CDTMockEncryptionKeychainStorage.h
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 15/04/2015.
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

#import "CDTEncryptionKeychainData.h"

#define CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_DATA nil
#define CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_SAVE YES
#define CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_CLEAR YES
#define CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_ARETHEREDATA NO

@interface CDTMockEncryptionKeychainStorage : NSObject

@property (assign, nonatomic) BOOL encryptionKeyDataExecuted;
@property (strong, nonatomic) CDTEncryptionKeychainData *encryptionKeyDataResult;

@property (assign, nonatomic) BOOL saveEncryptionKeyDataExecuted;
@property (assign, nonatomic) BOOL saveEncryptionKeyDataResult;

@property (assign, nonatomic) BOOL clearEncryptionKeyDataExecuted;
@property (assign, nonatomic) BOOL clearEncryptionKeyDataResult;

@property (assign, nonatomic) BOOL areThereEncryptionKeyDataExecuted;
@property (assign, nonatomic) BOOL areThereEncryptionKeyDataResult;

- (CDTEncryptionKeychainData *)encryptionKeyData;
- (BOOL)saveEncryptionKeyData:(CDTEncryptionKeychainData *)data;
- (BOOL)clearEncryptionKeyData;
- (BOOL)areThereEncryptionKeyData;

@end
