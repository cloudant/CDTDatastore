//
//  NSData+CDTEncryptionKeychainHexString.m
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

#import "NSData+CDTEncryptionKeychainHexString.h"

NSString *const CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_LABEL = @"HEXADECIMAL_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_MSG =
    @"A hexadecimal string has a even length";

@implementation NSData (CDTEncryptionKeychainHexString)

#pragma mark - Public methods
- (NSString *)CDTEncryptionKeychainHexadecimalRepresentation
{
    NSUInteger dataLength = self.length;
    const unsigned char *dataBytes = self.bytes;

    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (NSUInteger idx = 0; idx < dataLength; idx++) {
        [hexString appendFormat:@"%02x", dataBytes[idx]];
    }

    return [NSString stringWithString:hexString];
}

#pragma mark - Public class methods
+ (NSData *)CDTEncryptionKeychainDataFromHexadecimalString:(NSString *)hexString
{
    /*
     The string represent the hexadecimal values that should be used, so the string "4962"
     represents byte values 0x49  0x62.
     Note that the strings are twice the size since every two characters in the string
     corresponds to a single byte.
     */
    if (([hexString length] % 2) != 0) {
        [NSException raise:CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_LABEL
                    format:CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_MSG];
    }

    NSUInteger size = ([hexString length] / (NSUInteger)2);
    unsigned char buff[size];

    @autoreleasepool
    {
        for (NSUInteger i = 0; i < size; i++) {
            NSString *hexChrStr = [hexString substringWithRange:NSMakeRange(i * 2, 2)];

            NSScanner *scanner = [[NSScanner alloc] initWithString:hexChrStr];
            uint currInt;
            [scanner scanHexInt:&currInt];

            buff[i] = (char)currInt;
        }
    }

    NSData *data = [NSData dataWithBytes:buff length:size];

    return data;
}

@end
