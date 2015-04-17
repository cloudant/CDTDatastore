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

#import "CDTLogging.h"

@interface CDTEncryptionKeychainManager ()

@property (strong, nonatomic, readonly) CDTEncryptionKeychainStorage *storage;

@end

@implementation CDTEncryptionKeychainManager

#pragma mark - Init object
- (instancetype)init { return [self initWithStorage:nil]; }

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
    CDTEncryptionKeychainData *data = [self.storage encryptionKeyData];
    if (!data || ![self validatedEncryptionKeyData:data]) {
        return nil;
    }
    
    NSData *aesKey =
        [self generateAESKeyUsingPBKDF2ToDerivePassword:password
                                               withSalt:data.salt
                                             iterations:data.iterations
                                                 length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];

    NSData *dpk = [self decryptCipheredDpk:data.encryptedDPK usingAESWithKey:aesKey iv:data.iv];

    return dpk;
}

- (NSData *)generateEncryptionKeyDataUsingPassword:(NSString *)password
{
    NSData *dpk = nil;

    if (![self encryptionKeyDataAlreadyGenerated]) {
        dpk = [self generateDpk];

        CDTEncryptionKeychainData *keychainData =
            [self keychainDataToStoreDpk:dpk encryptedWithPassword:password];

        if (![self.storage saveEncryptionKeyData:keychainData]) {
            dpk = nil;
        }
    }

    return dpk;
}

- (BOOL)encryptionKeyDataAlreadyGenerated { return [self.storage areThereEncryptionKeyData]; }

- (BOOL)clearEncryptionKeyData { return [self.storage clearEncryptionKeyData]; }

#pragma mark - CDTEncryptionKeychainManager+Internal methods
- (BOOL)validatedEncryptionKeyData:(CDTEncryptionKeychainData *)data
{
    // Ensure the num derivations saved, matches what we have
    if (data.iterations != CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Number of stored iterations does NOT match the constant value %li",
                   (long)CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS);

        return NO;
    }

    // Ensure IV has the correct length
    if (data.iv.length != CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"IV does not have the expected size: %i bytes",
                   CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE);

        return NO;
    }

    return YES;
}

- (NSData *)generateDpk
{
    NSData *dpk = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE];

    return dpk;
}

- (CDTEncryptionKeychainData *)keychainDataToStoreDpk:(NSData *)dpk
                                encryptedWithPassword:(NSString *)password
{
    NSData *pbkdf2Salt = [self generatePBKDF2Salt];

    NSData *aesKey =
        [self generateAESKeyUsingPBKDF2ToDerivePassword:password
                                               withSalt:pbkdf2Salt
                                             iterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS
                                                 length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];

    NSData *aesIv = [self generateAESIv];

    NSData *encryptedDpk = [self encryptDpk:dpk usingAESWithKey:aesKey iv:aesIv];

    CDTEncryptionKeychainData *keychainData =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:encryptedDpk
                                                   salt:pbkdf2Salt
                                                     iv:aesIv
                                             iterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS
                                                version:CDTENCRYPTION_KEYCHAIN_VERSION];

    return keychainData;
}

- (NSData *)generatePBKDF2Salt
{
    NSData *salt = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_PBKDF2_SALT_SIZE];

    return salt;
}

- (NSData *)generateAESKeyUsingPBKDF2ToDerivePassword:(NSString *)password
                                             withSalt:(NSData *)salt
                                           iterations:(NSInteger)iterations
                                               length:(NSUInteger)length
{
    NSData *aesKey = [CDTEncryptionKeychainUtils generateKeyWithPassword:password
                                                                    salt:salt
                                                              iterations:iterations
                                                                  length:length];

    return aesKey;
}

- (NSData *)generateAESIv
{
    NSData *iv = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE];

    return iv;
}

- (NSData *)encryptDpk:(NSData *)dpk usingAESWithKey:(NSData *)key iv:(NSData *)iv
{
    NSData *encyptedDpk = [CDTEncryptionKeychainUtils encryptData:dpk withKey:key iv:iv];

    return encyptedDpk;
}

- (NSData *)decryptCipheredDpk:(NSData *)cipheredDpk usingAESWithKey:(NSData *)key iv:(NSData *)iv
{
    NSData *dpk = [CDTEncryptionKeychainUtils decryptData:cipheredDpk withKey:key iv:iv];

    return dpk;
}

@end
