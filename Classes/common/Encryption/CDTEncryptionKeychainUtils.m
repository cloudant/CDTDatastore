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

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#import "CDTEncryptionKeychainConstants.h"

@interface CDTEncryptionKeychainUtils ()

@end

@implementation CDTEncryptionKeychainUtils

#pragma mark - Public class methods
+ (NSString *)generateRandomStringWithBytes:(int)bytes
{
    uint8_t randBytes[bytes];

    int rc = SecRandomCopyBytes(kSecRandomDefault, (size_t)bytes, randBytes);
    if (rc != 0) {
        return nil;
    }

    NSMutableString *hexEncoded = [NSMutableString new];
    for (int i = 0; i < bytes; i++) {
        [hexEncoded appendString:[NSString stringWithFormat:@"%02x", randBytes[i]]];
    }

    NSString *randomStr = [NSString stringWithFormat:@"%@", hexEncoded];

    return randomStr;
}

+ (NSString *)encryptWithKey:(NSString *)key withText:(NSString *)text withIV:(NSString *)iv
{
    if (![text isKindOfClass:[NSString class]] || [text length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_ENCRYPT
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_TEXT];
    }

    if (![key isKindOfClass:[NSString class]] || [key length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_ENCRYPT
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_KEY];
    }

    if (![iv isKindOfClass:[NSString class]] || [iv length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_ENCRYPT
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_IV];
    }

    NSData *decryptedData = [text dataUsingEncoding:NSUnicodeStringEncoding];
    NSData *cipherDat = [CDTEncryptionKeychainUtils doEncrypt:decryptedData key:key withIV:iv];

    NSString *encodedBase64CipherString =
        [CDTEncryptionKeychainUtils base64StringFromData:cipherDat
                                                  length:(int)text.length
                                               isSafeUrl:NO];
    return encodedBase64CipherString;
}

+ (NSString *)decryptWithKey:(NSString *)key
              withCipherText:(NSString *)ciphertext
                      withIV:(NSString *)iv
         checkBase64Encoding:(BOOL)checkBase64Encoding
{
    if (![ciphertext isKindOfClass:[NSString class]] || [ciphertext length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_DECRYPT
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_CIPHER];
    }

    if (![key isKindOfClass:[NSString class]] || [key length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_DECRYPT
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_KEY];
    }

    if (![iv isKindOfClass:[NSString class]] || [iv length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_DECRYPT
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_IV];
    }

    NSData *encryptedData = [CDTEncryptionKeychainUtils base64DataFromString:ciphertext];
    NSData *decodedCipher = [CDTEncryptionKeychainUtils doDecrypt:encryptedData key:key withIV:iv];

    NSString *returnText =
        [[NSString alloc] initWithData:decodedCipher encoding:NSUnicodeStringEncoding];

    if (returnText != nil) {
        if (checkBase64Encoding && ![CDTEncryptionKeychainUtils isBase64Encoded:returnText]) {
            returnText = nil;
        }
    }

    return returnText;
}

+ (NSString *)generateKeyWithPassword:(NSString *)pass
                              andSalt:(NSString *)salt
                        andIterations:(NSInteger)iterations
{
    if (iterations < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_KEYGEN
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_INVALID_ITERATIONS];
    }

    if (![pass isKindOfClass:[NSString class]] || [pass length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_KEYGEN
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_PASSWORD];
    }

    if (![salt isKindOfClass:[NSString class]] || [salt length] < 1) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_KEYGEN
                    format:@"%@", CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_SALT];
    }

    NSData *passData = [pass dataUsingEncoding:NSUTF8StringEncoding];
    NSData *saltData = [salt dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *derivedKey = [NSMutableData dataWithLength:kCCKeySizeAES256];

    int retVal = CCKeyDerivationPBKDF(kCCPBKDF2, passData.bytes, pass.length, saltData.bytes,
                                      salt.length, kCCPRFHmacAlgSHA1, (int)iterations,
                                      derivedKey.mutableBytes, kCCKeySizeAES256);

    if (retVal != kCCSuccess) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_KEYGEN
                    format:@"Return value: %d", retVal];
    }

    NSMutableString *derivedKeyStr = [NSMutableString stringWithCapacity:kCCKeySizeAES256 * 2];
    const unsigned char *dataBytes = [derivedKey bytes];

    for (int idx = 0; idx < kCCKeySizeAES256; idx++) {
        [derivedKeyStr appendFormat:@"%02x", dataBytes[idx]];
    }

    derivedKey = nil;
    dataBytes = nil;

    return [NSString stringWithString:derivedKeyStr];
}

@end
