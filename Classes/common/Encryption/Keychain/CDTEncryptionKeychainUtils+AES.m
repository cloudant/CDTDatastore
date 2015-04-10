//
//  CDTEncryptionKeychainUtils+AES.m
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

#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTEncryptionKeychainConstants.h"
#import "NSString+CharBufferFromHexString.h"

@implementation CDTEncryptionKeychainUtils (AES)

#pragma mark - Public class methods
+ (NSData *)doDecrypt:(NSData *)data key:(NSString *)key withIV:(NSString *)iv
{
    return [CDTEncryptionKeychainUtils applyOperation:kCCDecrypt toData:data withKey:key iv:iv];
}

+ (NSData *)doEncrypt:(NSData *)data key:(NSString *)key withIV:(NSString *)iv
{
    return [CDTEncryptionKeychainUtils applyOperation:kCCEncrypt toData:data withKey:key iv:iv];
}

#pragma mark - Private class method
+ (NSData *)applyOperation:(CCOperation)operation
                    toData:(NSData *)data
                   withKey:(NSString *)key
                        iv:(NSString *)iv
{
    unsigned char *nativeIv = [iv charBufferFromHexStringWithSize:CDTkChosenCipherIVSize];
    unsigned char *nativeKey = [key charBufferFromHexStringWithSize:CDTkChosenCipherKeySize];

    // Generate context
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus cryptorStatus =
        CCCryptorCreate(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, nativeKey,
                        CDTkChosenCipherKeySize, nativeIv, &cryptor);
    NSAssert((cryptorStatus == kCCSuccess) && cryptor, @"Cryptographic context not created");

    // Encrypt
    size_t dataOutSize = CCCryptorGetOutputLength(cryptor, (size_t)[data length], true);
    void *dataOut = malloc(dataOutSize);

    size_t dataOutPartialSize = 0;
    cryptorStatus = CCCryptorUpdate(cryptor, [data bytes], (size_t)[data length], dataOut,
                                    dataOutSize, &dataOutPartialSize);
    NSAssert(cryptorStatus == kCCSuccess, @"Data not encrypted (update)");

    size_t dataOutTotalSize = dataOutPartialSize;

    cryptorStatus = CCCryptorFinal(cryptor, dataOut + dataOutPartialSize,
                                   dataOutSize - dataOutPartialSize, &dataOutPartialSize);
    NSAssert(cryptorStatus == kCCSuccess, @"Data not encrypted (final)");

    dataOutTotalSize += dataOutPartialSize;

    // Free context
    CCCryptorRelease(cryptor);
    
    bzero(nativeKey, CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE);
    free(nativeKey);
    
    bzero(nativeIv, CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE);
    free(nativeIv);

    // Return
    NSData *processedData = [NSData dataWithBytesNoCopy:dataOut length:dataOutTotalSize];

    return processedData;
}

@end
