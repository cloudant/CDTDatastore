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

#pragma mark - Public methods
- (NSData *)getDPK:(NSString *)password
{
    CDTEncryptionKeychainData *data = [self.storage validatedEncryptionKeyData];
    if (!data) {
        return nil;
    }

    NSData *nativeKey =
        [CDTEncryptionKeychainManager generateKeyWithPassword:password salt:data.salt];

    NSData *decryptedDPK =
        [CDTEncryptionKeychainUtils decryptData:data.encryptedDPK withKey:nativeKey iv:data.iv];

    return decryptedDPK;
}

- (BOOL)generateAndStoreDpkUsingPassword:(NSString *)password withSalt:(NSString *)salt
{
    NSData *data = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE];

    NSData *nativeKey = [CDTEncryptionKeychainManager generateKeyWithPassword:password salt:salt];

    NSData *nativeIv = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE];

    NSData *encyptedData =
        [CDTEncryptionKeychainUtils encryptData:data withKey:nativeKey iv:nativeIv];

    CDTEncryptionKeychainData *keychainData =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:encyptedData
                                                   salt:salt
                                                     iv:nativeIv
                                             iterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS
                                                version:CDTENCRYPTION_KEYCHAIN_KEY_VERSION_NUMBER];

    return [self.storage saveEncryptionKeyData:keychainData];
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
+ (NSData *)generateKeyWithPassword:(NSString *)pass salt:(NSString *)salt
{
    NSData *saltData = [salt dataUsingEncoding:NSUTF8StringEncoding];

    return
        [CDTEncryptionKeychainUtils generateKeyWithPassword:pass
                                                       salt:saltData
                                                 iterations:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS
                                                     length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];
}

@end
