//
//  NSString+CharBufferFromHexString.m
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

#import "NSString+CharBufferFromHexString.h"

#import "CDTEncryptionKeychainConstants.h"

NSString *const CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_LABEL = @"AES_ERROR";
NSString *const CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_MSG_FORMAT =
    @"String must be %i hex characters or %i bytes (%i bits)";


@implementation NSString (CharBufferFromHexString)

#pragma mark - Public methods
- (unsigned char *)charBufferFromHexStringWithSize:(int)size
{
    /*
     Make sure the key length represents 32 byte (256 bit) values. The string represent the
     hexadecimal
     values that should be used, so the string "4962" represents byte values 0x49  0x62.
     Note that the constant value is the actual byte size, and the strings are twice that size
     since every two characters in the string corresponds to a single byte.
     */
    if ([self length] != (NSUInteger)(size * 2)) {
        [NSException
             raise:CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_LABEL
            format:CDTENCRYPTION_KEYCHAIN_HEXSTRING_ERROR_MSG_FORMAT, 2 * size, size, 8 * size];
    }

    unsigned char *buff = malloc(size);

    for (int i = 0; i < size; i++) {
        int hexStrIdx = i * 2;
        NSString *hexChrStr = [self substringWithRange:NSMakeRange(hexStrIdx, 2)];

        NSScanner *scanner = [[NSScanner alloc] initWithString:hexChrStr];
        uint currInt;
        [scanner scanHexInt:&currInt];

        buff[i] = (char)currInt;
    }

    return buff;
}

@end
