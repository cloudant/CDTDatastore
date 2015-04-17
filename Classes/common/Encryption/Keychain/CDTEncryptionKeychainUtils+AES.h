//
//  CDTEncryptionKeychainUtils+AES.h
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

/**
 Utility class to encrypt/decrypt a NSData based on AES algorithim:
 http://en.wikipedia.org/wiki/Advanced_Encryption_Standard
 */
@interface CDTEncryptionKeychainUtils (AES)

/**
 Decrypts a buffer by using a key and an Initialization Vector (IV).

 @param data The encrypted data to decrypt
 @param key The key used for decryption
 @param iv The IV used for decryption

 @return The decrypted data
 */
+ (NSData *)doDecrypt:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 Encrypts a buffer by using a key and an Initialization Vector (IV).

 @param data The data to encrypt
 @param key The key used for encryption
 @param iv The IV used for encryption

 @return The encrypted data
 */
+ (NSData *)doEncrypt:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

@end
