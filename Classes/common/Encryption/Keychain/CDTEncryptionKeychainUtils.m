//
//  CDTEncryptionKeychainUtils.m
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

#import "CDTEncryptionKeychainUtils.h"
#import "CDTEncryptionKeychainUtils+AES.h"
#import "CDTEncryptionKeychainUtils+Base64.h"
#import "CDTEncryptionKeychainUtils+PBKDF2.h"

#import "CDTEncryptionKeychainConstants.h"

#import "NSData+CDTEncryptionKeychainHexString.h"

NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_LABEL = @"KEYGEN_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_INVALID_ITERATIONS =
    @"Number of iterations must greater than 0";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_EMPTY_PASSWORD =
    @"Password cannot be nil/empty";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_EMPTY_SALT =
    @"Salt cannot be nil/empty";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_PASS_NOT_DERIVED =
    @"Password not derived";

NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_LABEL = @"ENCRYPT_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_MSG_EMPTY_TEXT =
    @"Cannot encrypt empty/nil plaintext";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_MSG_EMPTY_KEY =
    @"Cannot work with an empty/nil key";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_MSG_EMPTY_IV =
    @"Cannot encrypt with empty/nil iv";

NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_LABEL = @"DECRYPT_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_MSG_EMPTY_CIPHER =
    @"Cannot decrypt empty/nil cipher";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_MSG_EMPTY_KEY =
    @"Cannot work with an empty/nil key";
NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_MSG_EMPTY_IV =
    @"Cannot decrypt with empty/nil iv";

@interface CDTEncryptionKeychainUtils ()

@end

@implementation CDTEncryptionKeychainUtils

#pragma mark - Public class methods
+ (NSData *)generateRandomBytesInBufferWithLength:(NSUInteger)length
{
    uint8_t randBytes[length];
    
    int rc = SecRandomCopyBytes(kSecRandomDefault, (size_t)length, randBytes);
    if (rc != 0) {
        return nil;
    }
    
    NSData *data = [NSData dataWithBytes:randBytes length:length];
    
    return data;
}

+ (NSString *)encryptText:(NSString *)text withKey:(NSData *)key iv:(NSData *)iv
{
    if (![text isKindOfClass:[NSString class]] || (text.length < 1)) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_MSG_EMPTY_TEXT];
    }

    if (![key isKindOfClass:[NSData class]] || (key.length < 1)) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_MSG_EMPTY_KEY];
    }

    if (![iv isKindOfClass:[NSData class]] || (iv.length < 1)) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_ENCRYPT_MSG_EMPTY_IV];
    }

    NSData *decryptedData = [text dataUsingEncoding:NSUnicodeStringEncoding];

    NSData *cipherDat = [CDTEncryptionKeychainUtils doEncrypt:decryptedData withKey:key iv:iv];

    NSString *encodedBase64CipherString =
        [CDTEncryptionKeychainUtils base64StringFromData:cipherDat];

    return encodedBase64CipherString;
}

+ (NSString *)decryptText:(NSString *)ciphertext withKey:(NSData *)key iv:(NSData *)iv
{
    if (![ciphertext isKindOfClass:[NSString class]] || (ciphertext.length < 1)) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_MSG_EMPTY_CIPHER];
    }

    if (![key isKindOfClass:[NSData class]] || (key.length < 1)) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_MSG_EMPTY_KEY];
    }

    if (![iv isKindOfClass:[NSData class]] || (iv.length < 1)) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_DECRYPT_MSG_EMPTY_IV];
    }

    NSData *encryptedData = [CDTEncryptionKeychainUtils base64DataFromString:ciphertext];

    NSData *decodedCipher = [CDTEncryptionKeychainUtils doDecrypt:encryptedData withKey:key iv:iv];

    NSString *returnText =
        [[NSString alloc] initWithData:decodedCipher encoding:NSUnicodeStringEncoding];
    if (returnText && ![CDTEncryptionKeychainUtils isBase64Encoded:returnText]) {
        returnText = nil;
    }

    return returnText;
}

+ (NSString *)generateKeyWithPassword:(NSString *)pass
                              andSalt:(NSString *)salt
                        andIterations:(NSInteger)iterations
{
    if (iterations < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_INVALID_ITERATIONS];
    }

    if (![pass isKindOfClass:[NSString class]] || [pass length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_EMPTY_PASSWORD];
    }

    if (![salt isKindOfClass:[NSString class]] || [salt length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_EMPTY_SALT];
    }

    NSData *passData = [pass dataUsingEncoding:NSUTF8StringEncoding];
    NSData *saltData = [salt dataUsingEncoding:NSUTF8StringEncoding];

    NSData *derivedKey =
        [CDTEncryptionKeychainUtils derivePassword:passData
                                          withSalt:saltData
                                        iterations:iterations
                                            length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];
    if (!derivedKey) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_KEYGEN_MSG_PASS_NOT_DERIVED];
    }

    NSString *derivedKeyStr = [derivedKey CDTEncryptionKeychainHexadecimalRepresentation];
    
    return derivedKeyStr;
}

@end
