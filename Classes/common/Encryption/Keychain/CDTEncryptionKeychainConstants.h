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

#ifndef _CDTEncryptionKeychainConstants_h
#define _CDTEncryptionKeychainConstants_h

#import <CommonCrypto/CommonCryptor.h>

#define CDTENCRYPTION_KEYCHAIN_VERSION @"1.0"

#define CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE 32

#define CDTENCRYPTION_KEYCHAIN_PBKDF2_SALT_SIZE 32
#define CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS (NSInteger)10000

#define CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE kCCKeySizeAES256
#define CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE kCCBlockSizeAES128

#endif