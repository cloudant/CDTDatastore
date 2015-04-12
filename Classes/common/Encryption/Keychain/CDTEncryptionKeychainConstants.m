//
//  CDTEncryptionKeychainConstants.m
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

#import "CDTEncryptionKeychainConstants.h"

int const CDTkChosenCipherKeySize = 32;
int const CDTkChosenCipherIVSize = 16;

NSString *const CDTENCRYPTION_KEYCHAIN_BASE64_REGEX = @"^[a-zA-Z0-9\\+=\\/]{%u}$";

NSString *const CDTENCRYPTION_KEYCHAIN_DEFAULT_ACCOUNT = @"cdtdatastore";

int const CDTENCRYPTION_KEYCHAIN_DEFAULT_DPK_SIZE = 32;
int const CDTENCRYPTION_KEYCHAIN_DEFAULT_IV_SIZE = 16;
int const CDTENCRYPTION_KEYCHAIN_DEFAULT_PBKDF2_ITERATIONS = 10000;

NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL = @"ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_KEYGEN = @"KEYGEN_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_ENCRYPT = @"ENCRYPT_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_LABEL_DECRYPT = @"DECRYPT_ERROR";

NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_TEXT = @"Cannot encrypt empty/nil plaintext";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_KEY = @"Cannot work with an empty/nil key";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_IV = @"Cannot encrypt with empty/nil iv";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_INVALID_ITERATIONS =
    @"Number of iterations must greater than 0";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_PASSWORD = @"Password cannot be nil/empty";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_SALT = @"Salt cannot be nil/empty";
NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_EMPTY_CIPHER = @"Cannot decrypt empty/nil cipher";

NSString *const CDTENCRYPTION_KEYCHAIN_ERROR_MSG_INVALID_IV_LENGTH =
    @"IV must be 32 hex characters or 16 bytes (128 bits)";

NSString *const CDTENCRYPTION_KEYCHAIN_KEY_VERSION_NUMBER = @"1.0";
NSString *const CDTENCRYPTION_KEYCHAIN_KEY_DOCUMENT_ID = @"CDTDatastoreKey";
