//
//  CDTEncryptionKeychainManager.m
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

#import "CDTEncryptionKeychainManager.h"

#import "CDTEncryptionKeychainUtils.h"
#import "CDTEncryptionKeychainConstants.h"
#import "CDTEncryptionKeychainData+KeychainStorage.h"
#import "NSObject+CDTEncryptionKeychainJSON.h"
#import "NSString+CDTEncryptionKeychainJSON.h"

#import "CDTLogging.h"

@interface CDTEncryptionKeychainManager ()

@end

@implementation CDTEncryptionKeychainManager

#pragma mark - Public methods
- (NSString *)getDPK:(NSString *)password
{
    CDTEncryptionKeychainData *data = [self getEncryptionDataFromKeyChain];
    if (!data) {
        return nil;
    }

    NSString *pwKey = [self passwordToKey:password withSalt:data.salt];
    NSString *decryptedKey = [CDTEncryptionKeychainUtils decryptWithKey:pwKey
                                                         withCipherText:data.encryptedDPK
                                                                 withIV:data.IV];

    return decryptedKey;
}

- (BOOL)generateAndStoreDpkUsingPassword:(NSString *)password withSalt:(NSString *)salt
{
    NSString *hexEncodedDpk = [CDTEncryptionKeychainUtils
        generateRandomStringWithBytes:CDTENCRYPTION_KEYCHAIN_DEFAULT_DPK_SIZE];

    BOOL worked = [self storeDPK:hexEncodedDpk usingPassword:password withSalt:salt];

    return worked;
}

- (BOOL)isKeyChainFullyPopulated
{
    if ([self checkDpkDocumentIsInKeychain]) {
        return YES;
    }

    return NO;
}

- (BOOL)clearKeyChain
{
    BOOL worked = NO;

    NSMutableDictionary *dict = [self getDpkDocumentLookupDict];
    [dict removeObjectForKey:(__bridge id)(kSecReturnData)];
    [dict removeObjectForKey:(__bridge id)(kSecMatchLimit)];
    [dict removeObjectForKey:(__bridge id)(kSecReturnAttributes)];
    [dict removeObjectForKey:(__bridge id)(kSecAttrAccount)];

    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)dict);

    if (err == noErr || err == errSecItemNotFound) {
        worked = YES;
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemDelete returned: %d", err);
    }

    return worked;
}

#pragma mark - Private methods
- (BOOL)storeDPK:(NSString *)dpk usingPassword:(NSString *)password withSalt:(NSString *)salt
{
    BOOL worked = NO;

    NSString *pwKey = [self passwordToKey:password withSalt:salt];

    NSString *hexEncodedIv = [CDTEncryptionKeychainUtils
        generateRandomStringWithBytes:CDTENCRYPTION_KEYCHAIN_DEFAULT_IV_SIZE];

    NSString *encyptedDPK =
        [CDTEncryptionKeychainUtils encryptWithKey:pwKey withText:dpk withIV:hexEncodedIv];

    NSNumber *iterations =
        [NSNumber numberWithInt:CDTENCRYPTION_KEYCHAIN_DEFAULT_PBKDF2_ITERATIONS];

    CDTEncryptionKeychainData *data =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:encyptedDPK
                                                   salt:salt
                                                     iv:hexEncodedIv
                                             iterations:iterations
                                                version:CDTENCRYPTION_KEYCHAIN_KEY_VERSION_NUMBER];

    NSString *jsonStr = [[data dictionary] CDTEncryptionKeychainJSONRepresentation];
    NSMutableDictionary *jsonDocStoreDict =
        [self getGenericPwStoreDict:CDTENCRYPTION_KEYCHAIN_KEY_DOCUMENT_ID data:jsonStr];

    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)jsonDocStoreDict, nil);
    if (err == noErr) {
        worked = YES;
    } else if (err == errSecDuplicateItem) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"Doc already exists in keychain");
        worked = NO;
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Unable to store Doc in keychain, SecItemAdd returned: %d", err);
        worked = NO;
    }

    return worked;
}

- (CDTEncryptionKeychainData *)getEncryptionDataFromKeyChain
{
    NSMutableDictionary *lookupDict = [self getDpkDocumentLookupDict];

    NSData *theData = nil;

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)lookupDict, (void *)&theData);

    if (err == noErr) {
        NSString *jsonStr = [[NSString alloc] initWithBytes:[theData bytes]
                                                     length:[theData length]
                                                   encoding:NSUTF8StringEncoding];

        id jsonDoc = [jsonStr CDTEncryptionKeychainJSONValue];

        if (jsonDoc != nil && [jsonDoc isKindOfClass:[NSDictionary class]]) {
            CDTEncryptionKeychainData *encryptionData =
                [CDTEncryptionKeychainData dataWithDictionary:jsonDoc];
            if (!encryptionData) {
                CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"Stored dictionary is not complete");

                return nil;
            }

            // Ensure the num derivations saved, matches what we have
            int iters = [encryptionData.iterations intValue];

            if (iters != CDTENCRYPTION_KEYCHAIN_DEFAULT_PBKDF2_ITERATIONS) {
                CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                           @"Number of iterations stored, does NOT match the constant value %u",
                           CDTENCRYPTION_KEYCHAIN_DEFAULT_PBKDF2_ITERATIONS);

                return nil;
            }

            return encryptionData;
        }
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemCopyMatching returned: %d", err);
    }

    return nil;
}

- (BOOL)checkDpkDocumentIsInKeychain
{
    NSData *dpkData = nil;

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)[self getDpkDocumentLookupDict],
                                       (void *)&dpkData);

    if (err == noErr) {
        NSString *dpk = [[NSString alloc] initWithBytes:[dpkData bytes]
                                                 length:[dpkData length]
                                               encoding:NSUTF8StringEncoding];

        if (dpk != nil && [dpk length] > 0) {
            return YES;

        } else {
            // Found a match in keychain, but it was empty
            return NO;
        }

    } else if (err == errSecItemNotFound) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"DPK doc not found in keychain");

        return NO;
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemCopyMatching returned: %d", err);

        return NO;
    }
}

- (NSString *)passwordToKey:(NSString *)password withSalt:(NSString *)salt
{
    return [CDTEncryptionKeychainUtils
        generateKeyWithPassword:password
                        andSalt:salt
                  andIterations:CDTENCRYPTION_KEYCHAIN_DEFAULT_PBKDF2_ITERATIONS];
}

- (NSMutableDictionary *)getDpkDocumentLookupDict
{
    NSMutableDictionary *dpkQuery =
        [self getGenericPwLookupDict:CDTENCRYPTION_KEYCHAIN_KEY_DOCUMENT_ID];
    return dpkQuery;
}

- (NSMutableDictionary *)getGenericPwLookupDict:(NSString *)identifier
{
    NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
    [genericPasswordQuery setObject:(__bridge id)kSecClassGenericPassword
                             forKey:(__bridge id)kSecClass];
    [genericPasswordQuery setObject:CDTENCRYPTION_KEYCHAIN_DEFAULT_ACCOUNT
                             forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [genericPasswordQuery setObject:identifier forKey:(__bridge id<NSCopying>)(kSecAttrService)];

    // Use the proper search constants, return only the attributes of the first match.
    [genericPasswordQuery setObject:(__bridge id)kSecMatchLimitOne
                             forKey:(__bridge id<NSCopying>)(kSecMatchLimit)];
    [genericPasswordQuery setObject:(__bridge id)kCFBooleanFalse
                             forKey:(__bridge id<NSCopying>)(kSecReturnAttributes)];
    [genericPasswordQuery setObject:(__bridge id)kCFBooleanTrue
                             forKey:(__bridge id<NSCopying>)(kSecReturnData)];
    return genericPasswordQuery;
}

- (NSMutableDictionary *)getGenericPwStoreDict:(NSString *)identifier data:(NSString *)theData
{
    NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
    [genericPasswordQuery setObject:(__bridge id)kSecClassGenericPassword
                             forKey:(__bridge id)kSecClass];
    [genericPasswordQuery setObject:CDTENCRYPTION_KEYCHAIN_DEFAULT_ACCOUNT
                             forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [genericPasswordQuery setObject:identifier forKey:(__bridge id<NSCopying>)(kSecAttrService)];
    [genericPasswordQuery setObject:[theData dataUsingEncoding:NSUTF8StringEncoding]
                             forKey:(__bridge id<NSCopying>)(kSecValueData)];
    [genericPasswordQuery setObject:(__bridge id)(kSecAttrAccessibleAlways)
                             forKey:(__bridge id<NSCopying>)(kSecAttrAccessible)];

    return genericPasswordQuery;
}

@end
