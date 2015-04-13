//
//  CDTEncryptionKeychainUtils.h
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

#import <Foundation/Foundation.h>

extern NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_LABEL_KEYGEN;
extern NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_LABEL_ENCRYPT;
extern NSString *const CDTENCRYPTION_KEYCHAIN_UTILS_ERROR_LABEL_DECRYPT;

@interface CDTEncryptionKeychainUtils : NSObject

/**
 * Generates a buffer with random bytes in it.
 *
 * @param bytes Number of bytes in the buffer
 *
 * @return The buffer, nil if the operation fails
 */
+ (NSData *)generateRandomBytesInBufferWithLength:(NSUInteger)length;

/**
 * Encrypts an NSString by using a key and an Initialization Vector (IV).
 *
 * @param text The text to encrypt
 * @param key The key used for encryption
 * @param iv The IV used for encryption
 *
 * @return The encrypted text
 */
+ (NSString *)encryptText:(NSString *)text withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Decrypts an NSString by using a key and an Initialization Vector (IV).
 *
 * @param ciphertext The encrypted text to decrypt
 * @param key The key used for decryption
 * @param iv The IV used for decryption
 *
 * @return The decrypted text
 */
+ (NSString *)decryptText:(NSString *)ciphertext withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Generates a key by using the PBKDF2 algorithm.
 *
 * @param pass The password that is used to generate the key
 * @param salt The salt that is used to generate the key
 * @param iterations The number of iterations that is passed to the key generation algorithm
 *
 * @return The generated key
 */
+ (NSString *)generateKeyWithPassword:(NSString *)pass
                              andSalt:(NSString *)salt
                        andIterations:(NSInteger)iterations;

@end
