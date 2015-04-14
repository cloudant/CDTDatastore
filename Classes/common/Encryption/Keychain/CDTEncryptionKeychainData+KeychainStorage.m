//
//  CDTEncryptionKeychainData+KeychainStorage.m
//
//
//  Created by Enrique de la Torre Fernandez on 12/04/2015.
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

#import "CDTEncryptionKeychainData+KeychainStorage.h"

#import "CDTEncryptionKeychainConstants.h"

#import "NSData+CDTEncryptionKeychainHexString.h"

NSString *const CDTENCRYPTION_KEYCHAINSTORAGE_KEY_DPK = @"dpk";
NSString *const CDTENCRYPTION_KEYCHAINSTORAGE_KEY_SALT = @"jsonSalt";
NSString *const CDTENCRYPTION_KEYCHAINSTORAGE_KEY_IV = @"iv";
NSString *const CDTENCRYPTION_KEYCHAINSTORAGE_KEY_ITERATIONS = @"iterations";
NSString *const CDTENCRYPTION_KEYCHAINSTORAGE_KEY_VERSION = @"version";

@implementation CDTEncryptionKeychainData (KeychainStorage)

#pragma mark - Public methods
- (NSDictionary *)dictionary
{
    NSString *ivHex = [self.iv CDTEncryptionKeychainHexadecimalRepresentation];

    NSDictionary *dic = @{
        CDTENCRYPTION_KEYCHAINSTORAGE_KEY_DPK : self.encryptedDPK,
        CDTENCRYPTION_KEYCHAINSTORAGE_KEY_SALT : self.salt,
        CDTENCRYPTION_KEYCHAINSTORAGE_KEY_IV : ivHex,
        CDTENCRYPTION_KEYCHAINSTORAGE_KEY_ITERATIONS : self.iterations,
        CDTENCRYPTION_KEYCHAINSTORAGE_KEY_VERSION : self.version
    };

    return dic;
}

#pragma mark - Public class methods
+ (instancetype)dataWithDictionary:(NSDictionary *)dictionary
{
    NSString *encryptedDPK = dictionary[CDTENCRYPTION_KEYCHAINSTORAGE_KEY_DPK];
    NSString *salt = dictionary[CDTENCRYPTION_KEYCHAINSTORAGE_KEY_SALT];
    NSString *ivHex = dictionary[CDTENCRYPTION_KEYCHAINSTORAGE_KEY_IV];
    NSNumber *iterations = dictionary[CDTENCRYPTION_KEYCHAINSTORAGE_KEY_ITERATIONS];
    NSString *version = dictionary[CDTENCRYPTION_KEYCHAINSTORAGE_KEY_VERSION];

    NSData *iv = [NSData CDTEncryptionKeychainDataFromHexadecimalString:ivHex];

    return [[self class] dataWithEncryptedDPK:encryptedDPK
                                         salt:salt
                                           iv:iv
                                   iterations:iterations
                                      version:version];
}

@end
