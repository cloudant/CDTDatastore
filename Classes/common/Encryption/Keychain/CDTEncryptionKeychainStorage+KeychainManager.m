//
//  CDTEncryptionKeychainStorage+KeychainManager.m
//  
//
//  Created by Enrique de la Torre Fernandez on 14/04/2015.
//
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTEncryptionKeychainStorage+KeychainManager.h"

#import "CDTEncryptionKeychainConstants.h"

#import "CDTLogging.h"

@implementation CDTEncryptionKeychainStorage (KeychainManager)

#pragma mark - Public methods
- (CDTEncryptionKeychainData *)validatedEncryptionKeyData
{
    CDTEncryptionKeychainData *data = [self encryptionKeyData];
    if (!data) {
        return nil;
    }
    
    // Ensure the num derivations saved, matches what we have
    if ([data.iterations intValue] != CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Number of stored iterations does NOT match the constant value %i",
                   CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS);
        
        return nil;
    }
    
    // Ensure IV has the correct length
    if (data.iv.length != CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"IV does not have the expected size: %i bytes",
                   CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE);
        
        return nil;
    }
    
    return data;
}

@end
