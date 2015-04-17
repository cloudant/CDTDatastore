//
//  CDTMockEncryptionKeychainStorage.m
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

#import "CDTMockEncryptionKeychainStorage.h"

@interface CDTMockEncryptionKeychainStorage ()

@end

@implementation CDTMockEncryptionKeychainStorage

#pragma mark - Init object
- (instancetype)init
{
    self = [super init];
    if (self) {
        _encryptionKeyDataExecuted = NO;
        _encryptionKeyDataResult = CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_DATA;
        
        _saveEncryptionKeyDataExecuted = NO;
        _saveEncryptionKeyDataResult = CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_SAVE;
        
        _clearEncryptionKeyDataExecuted = NO;
        _clearEncryptionKeyDataResult = CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_CLEAR;
        
        _areThereEncryptionKeyDataExecuted = NO;
        _areThereEncryptionKeyDataResult = CDTMOCKENCRYPTIONKEYCHAINSTORAGE_DEFAULT_ARETHEREDATA;
    }
    
    return self;
}

#pragma mark - Public methods
- (CDTEncryptionKeychainData *)encryptionKeyData
{
    self.encryptionKeyDataExecuted = YES;
    
    return self.encryptionKeyDataResult;
}

- (BOOL)saveEncryptionKeyData:(CDTEncryptionKeychainData *)data
{
    self.saveEncryptionKeyDataExecuted = YES;
    
    return self.saveEncryptionKeyDataResult;
}

- (BOOL)clearEncryptionKeyData
{
    self.clearEncryptionKeyDataExecuted = YES;
    
    return self.clearEncryptionKeyDataResult;
}

- (BOOL)areThereEncryptionKeyData
{
    self.areThereEncryptionKeyDataExecuted = YES;
    
    return self.areThereEncryptionKeyDataResult;
}

@end
