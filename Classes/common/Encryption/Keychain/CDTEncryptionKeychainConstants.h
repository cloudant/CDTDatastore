//
//  CDTEncryptionKeychainConstants.h
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

#define CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE 32

#define CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS 10000

#define CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE kCCKeySizeAES256
#define CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE kCCBlockSizeAES128

extern NSString *const CDTENCRYPTION_KEYCHAIN_DEFAULT_ACCOUNT;

extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_KEYGEN;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_ENCRYPT;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_DECRYPT;

extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_TEXT;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_KEY;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_IV;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_INVALID_ITERATIONS;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_PASSWORD;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_SALT;
extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_CIPHER;

extern NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_INVALID_IV_LENGTH;

extern NSString *const CDTENCRYPTION_KEYCHAIN_KEY_VERSION_NUMBER;
extern NSString *const CDTENCRYPTION_KEYCHAIN_KEY_DOCUMENT_ID;
