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
#import "CDTEncryptionKeychainStorage.h"
#import "CDTEncryptionKeychainConstants.h"

#import "CDTLogging.h"

@interface CDTEncryptionKeychainManager ()

@property (strong, nonatomic, readonly) CDTEncryptionKeychainStorage *storage;

@end

@implementation CDTEncryptionKeychainManager

#pragma mark - Public methods
- (NSString *)getDPK:(NSString *)password
{
    CDTEncryptionKeychainData *data = [self.storage encryptionKeyData];
    if (!data) {
        return nil;
    }

    NSString *pwKey = [self passwordToKey:password withSalt:data.salt];
    NSString *decryptedKey = [CDTEncryptionKeychainUtils decryptWithKey:pwKey
                                                         withCipherText:data.encryptedDPK
                                                                 withIV:data.IV];

    return decryptedKey;
}

- (BOOL)generateAndStoreDpkUsingPassword:(NSString *)password withSalt:(NSString *)salt
{
    NSString *hexEncodedDpk = [CDTEncryptionKeychainUtils
        generateRandomStringWithBytes:CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE];

    BOOL worked = [self storeDPK:hexEncodedDpk usingPassword:password withSalt:salt];

    return worked;
}

- (BOOL)isKeyChainFullyPopulated
{
    return [self.storage areThereEncryptionKeyData];
}

- (BOOL)clearKeyChain
{
    return [self.storage clearEncryptionKeyData];
}

#pragma mark - Private methods
- (BOOL)storeDPK:(NSString *)dpk usingPassword:(NSString *)password withSalt:(NSString *)salt
{
    NSString *pwKey = [self passwordToKey:password withSalt:salt];

    NSString *hexEncodedIv = [CDTEncryptionKeychainUtils
        generateRandomStringWithBytes:CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE];

    NSString *encyptedDPK =
        [CDTEncryptionKeychainUtils encryptWithKey:pwKey withText:dpk withIV:hexEncodedIv];

    NSNumber *iterations = [NSNumber numberWithInt:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS];

    CDTEncryptionKeychainData *data =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:encyptedDPK
                                                   salt:salt
                                                     iv:hexEncodedIv
                                             iterations:iterations
                                                version:CDTENCRYPTION_KEYCHAIN_KEY_VERSION_NUMBER];

    return [self.storage saveEncryptionKeyData:data];
}

- (NSString *)passwordToKey:(NSString *)password withSalt:(NSString *)salt
{
    return [CDTEncryptionKeychainUtils
        generateKeyWithPassword:password
                        andSalt:salt
                  andIterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS];
}

@end
