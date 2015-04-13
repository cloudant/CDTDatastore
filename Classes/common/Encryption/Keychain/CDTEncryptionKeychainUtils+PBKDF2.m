//
//  CDTEncryptionKeychainUtils+PBKDF2.m
//
//
//  Created by Enrique de la Torre Fernandez on 13/04/2015.
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
#import <CommonCrypto/CommonKeyDerivation.h>

#import "CDTEncryptionKeychainUtils+PBKDF2.h"

#import "CDTLogging.h"

@implementation CDTEncryptionKeychainUtils (PBKDF2)

#pragma mark - Public class methods
+ (NSData *)derivePassword:(NSData *)password
                  withSalt:(NSData *)salt
                iterations:(NSUInteger)iterations
                    length:(NSUInteger)length
{
    NSMutableData *derivedKey = [NSMutableData dataWithLength:length];

    int retVal =
        CCKeyDerivationPBKDF(kCCPBKDF2, password.bytes, password.length, salt.bytes, salt.length,
                             kCCPRFHmacAlgSHA1, (uint)iterations, derivedKey.mutableBytes, length);
    if (retVal != kCCSuccess) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Password not derived. Return: %i", retVal);

        derivedKey = nil;
    }

    return derivedKey;
}

@end
