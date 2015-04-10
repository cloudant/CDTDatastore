//
//  CDTEncryptionKeychainUtils+Base64.m
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

#import "CDTEncryptionKeychainUtils+Base64.h"

#import "CDTEncryptionKeychainConstants.h"

#import "TDBase64.h"

@implementation CDTEncryptionKeychainUtils (Base64)

#pragma mark - Public class methods
+ (NSString *)base64StringFromData:(NSData *)data
{
    return [TDBase64 encode:data];
}

+ (NSData *)base64DataFromString:(NSString *)string
{
    return [TDBase64 decode:string];
}

+ (BOOL)isBase64Encoded:(NSString *)str
{
    NSString *pattern =
    [[NSString alloc] initWithFormat:CDTENCRYPTION_KEYCHAIN_BASE64_REGEX, [str length]];
    
    NSError *error = NULL;
    NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSUInteger numMatch =
    [regex numberOfMatchesInString:str options:0 range:NSMakeRange(0, [str length])];
    if (numMatch != 1 || [error code] != 0) {
        return NO;
    }
    return YES;
}

@end
