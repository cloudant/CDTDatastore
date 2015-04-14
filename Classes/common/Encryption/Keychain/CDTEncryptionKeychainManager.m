//
//  CDTEncryptionKeychainManager.m
//
//
//  Created by Enrique de la Torre Fernandez on 09/04/2015.
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

#import <CommonCrypto/CommonCryptor.h>

#import "CDTEncryptionKeychainManager.h"

#import "CDTEncryptionKeychainUtils.h"
#import "CDTEncryptionKeychainConstants.h"
#import "CDTEncryptionKeychainStorage+KeychainManager.h"

#import "CDTLogging.h"

@interface CDTEncryptionKeychainManager ()

@property (strong, nonatomic, readonly) CDTEncryptionKeychainStorage *storage;

@end

@implementation CDTEncryptionKeychainManager

#pragma mark - Init object
- (instancetype)init
{
    return [self initWithStorage:nil];
}

- (instancetype)initWithStorage:(CDTEncryptionKeychainStorage *)storage
{
    self = [super init];
    if (self) {
        if (storage) {
            _storage = storage;
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Storage is mandatory");
            
            self = nil;
        }
    }
    
    return self;
}

#pragma mark - Public methods
- (NSData *)retrieveEncryptionKeyDataUsingPassword:(NSString *)password
{
    CDTEncryptionKeychainData *data = [self.storage validatedEncryptionKeyData];
    if (!data) {
        return nil;
    }

    NSData *aesKey =
        [CDTEncryptionKeychainUtils generateKeyWithPassword:password
                                                       salt:data.salt
                                                 iterations:data.iterations
                                                     length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];

    NSData *dpk =
        [CDTEncryptionKeychainUtils decryptData:data.encryptedDPK withKey:aesKey iv:data.iv];

    return dpk;
}

- (NSData *)generateEncryptionKeyDataUsingPassword:(NSString *)password
{
    NSData *pbkdf2Salt = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_PBKDF2_SALT_SIZE];

    NSData *aesKey =
        [CDTEncryptionKeychainUtils generateKeyWithPassword:password
                                                       salt:pbkdf2Salt
                                                 iterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS
                                                     length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];

    NSData *aesIv = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE];

    NSData *dpk = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE];
    NSData *encyptedDpk = [CDTEncryptionKeychainUtils encryptData:dpk withKey:aesKey iv:aesIv];

    CDTEncryptionKeychainData *keychainData =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:encyptedDpk
                                                   salt:pbkdf2Salt
                                                     iv:aesIv
                                             iterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS
                                                version:CDTENCRYPTION_KEYCHAIN_KEY_VERSION_NUMBER];

    BOOL isSaved = [self.storage saveEncryptionKeyData:keychainData];

    return (isSaved ? dpk : nil);
}

- (BOOL)encryptionKeyDataAlreadyGenerated
{
    return [self.storage areThereEncryptionKeyData];
}

- (BOOL)clearEncryptionKeyData
{
    return [self.storage clearEncryptionKeyData];
}

@end
