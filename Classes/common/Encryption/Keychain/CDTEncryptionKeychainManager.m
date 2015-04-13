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

#import "NSData+CDTEncryptionKeychainHexString.h"

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

    NSData *nativeKey =
        [CDTEncryptionKeychainManager generateKeyWithPassword:password salt:data.salt];

    NSData *nativeIv =
        [NSData CDTEncryptionKeychainDataFromHexadecimalString:data.IV
                                                      withSize:CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE];

    NSString *decryptedKey =
        [CDTEncryptionKeychainUtils decryptText:data.encryptedDPK withKey:nativeKey iv:nativeIv];

    return decryptedKey;
}

- (BOOL)generateAndStoreDpkUsingPassword:(NSString *)password withSalt:(NSString *)salt
{
    NSData *data = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE];
    NSString *text = [data CDTEncryptionKeychainHexadecimalRepresentation];

    NSData *nativeKey = [CDTEncryptionKeychainManager generateKeyWithPassword:password salt:salt];
    
    NSData *nativeIv = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE];
    NSString *hexEncodedIv = [nativeIv CDTEncryptionKeychainHexadecimalRepresentation];

    NSString *encyptedText =
        [CDTEncryptionKeychainUtils encryptText:text withKey:nativeKey iv:nativeIv];

    NSNumber *iterations = [NSNumber numberWithInt:CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS];

    CDTEncryptionKeychainData *keychainData =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:encyptedText
                                                   salt:salt
                                                     iv:hexEncodedIv
                                             iterations:iterations
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
