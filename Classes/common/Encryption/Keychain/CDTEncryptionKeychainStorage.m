//
//  CDTEncryptionKeychainStorage.m
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

#import "CDTEncryptionKeychainStorage.h"

#import "CDTEncryptionKeychainConstants.h"

#import "CDTLogging.h"

#define CDTENCRYPTION_KEYCHAINSTORAGE_KEY_DOCUMENTID @"CDTDatastoreKey"

@interface CDTEncryptionKeychainStorage ()

@property (strong, nonatomic, readonly) NSString *service;
@property (strong, nonatomic, readonly) NSString *account;

@end

@implementation CDTEncryptionKeychainStorage

#pragma mark - Init object
- (instancetype)init
{
    return [self initWithIdentifier:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        if (identifier) {
            _service = CDTENCRYPTION_KEYCHAINSTORAGE_KEY_DOCUMENTID;
            _account = identifier;
        } else {
            self = nil;
            
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"identifier is mandatory");
        }
    }
    
    return self;
}

#pragma mark - Public methods
- (CDTEncryptionKeychainData *)encryptionKeyData
{
    CDTEncryptionKeychainData *encryptionData = nil;

    NSData *data = nil;
    NSMutableDictionary *lookupDict =
        [CDTEncryptionKeychainStorage genericPwLookupDictWithService:self.service
                                                             account:self.account];

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)lookupDict, (void *)&data);
    if (err == noErr) {
        id unarchiveObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];

        if ([unarchiveObject isKindOfClass:[CDTEncryptionKeychainData class]]) {
            encryptionData = unarchiveObject;
        } else {
            CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"Data found can is not as expected");
        }
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemCopyMatching returned: %d", err);
    }

    return encryptionData;
}

- (BOOL)saveEncryptionKeyData:(CDTEncryptionKeychainData *)data
{
    BOOL worked = NO;

    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:data];
    NSMutableDictionary *dataStoreDict =
        [CDTEncryptionKeychainStorage genericPwStoreDictWithService:self.service
                                                            account:self.account
                                                               data:archivedData];

    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)dataStoreDict, nil);
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

- (BOOL)clearEncryptionKeyData
{
    BOOL worked = NO;

    NSMutableDictionary *dict =
        [CDTEncryptionKeychainStorage genericPwLookupDictWithService:self.service
                                                             account:self.account];
    [dict removeObjectForKey:(__bridge id)(kSecMatchLimit)];
    [dict removeObjectForKey:(__bridge id)(kSecReturnAttributes)];
    [dict removeObjectForKey:(__bridge id)(kSecReturnData)];

#warning Will we delete all accounts?
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

- (BOOL)areThereEncryptionKeyData
{
    BOOL result = NO;

    NSData *data = nil;
    NSMutableDictionary *lookupDict =
        [CDTEncryptionKeychainStorage genericPwLookupDictWithService:self.service
                                                             account:self.account];

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)lookupDict, (void *)&data);
    if (err == noErr) {
        result = ((data != nil) && (data.length > 0));

        if (!result) {
            CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"Found a match in keychain, but it was empty");
        }
    } else if (err == errSecItemNotFound) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"DPK doc not found in keychain");
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemCopyMatching returned: %d", err);
    }

    return result;
}

#pragma mark - Private class methods
+ (NSMutableDictionary *)genericPwLookupDictWithService:(NSString *)service
                                                account:(NSString *)account
{
    NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
    
    [genericPasswordQuery setObject:(__bridge id)kSecClassGenericPassword
                             forKey:(__bridge id)kSecClass];
    [genericPasswordQuery setObject:service forKey:(__bridge id<NSCopying>)(kSecAttrService)];
    [genericPasswordQuery setObject:account forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];

    // Use the proper search constants, return only the attributes of the first match.
    [genericPasswordQuery setObject:(__bridge id)kSecMatchLimitOne
                             forKey:(__bridge id<NSCopying>)(kSecMatchLimit)];
    [genericPasswordQuery setObject:(__bridge id)kCFBooleanFalse
                             forKey:(__bridge id<NSCopying>)(kSecReturnAttributes)];
    [genericPasswordQuery setObject:(__bridge id)kCFBooleanTrue
                             forKey:(__bridge id<NSCopying>)(kSecReturnData)];
    
    return genericPasswordQuery;
}

+ (NSMutableDictionary *)genericPwStoreDictWithService:(NSString *)service
                                               account:(NSString *)account
                                                  data:(NSData *)data
{
    NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
    
    [genericPasswordQuery setObject:(__bridge id)kSecClassGenericPassword
                             forKey:(__bridge id)kSecClass];
    [genericPasswordQuery setObject:service forKey:(__bridge id<NSCopying>)(kSecAttrService)];
    [genericPasswordQuery setObject:account forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];

    [genericPasswordQuery setObject:data forKey:(__bridge id<NSCopying>)(kSecValueData)];

#warning This does not look like the best option
    [genericPasswordQuery setObject:(__bridge id)(kSecAttrAccessibleAlways)
                             forKey:(__bridge id<NSCopying>)(kSecAttrAccessible)];

    return genericPasswordQuery;
}

@end
