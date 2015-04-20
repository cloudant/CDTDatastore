//
//  CDTEncryptionKeychainStorage.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 12/04/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
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

#import "CDTLogging.h"

#define CDTENCRYPTION_KEYCHAINSTORAGE_SERVICE_VALUE \
    @"com.cloudant.sync.CDTEncryptionKeychainStorage.keychain.service"

#define CDTENCRYPTION_KEYCHAINSTORAGE_ARCHIVE_KEY \
    @"com.cloudant.sync.CDTEncryptionKeychainStorage.archive.key"

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
            _service = CDTENCRYPTION_KEYCHAINSTORAGE_SERVICE_VALUE;
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
    NSMutableDictionary *query =
        [CDTEncryptionKeychainStorage genericPwLookupDictWithService:self.service
                                                             account:self.account];

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, (void *)&data);
    if (err == noErr) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        [unarchiver setRequiresSecureCoding:YES];

        encryptionData = [unarchiver decodeObjectOfClass:[CDTEncryptionKeychainData class]
                                                  forKey:CDTENCRYPTION_KEYCHAINSTORAGE_ARCHIVE_KEY];

        [unarchiver finishDecoding];
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemCopyMatching returned: %d", err);
    }

    return encryptionData;
}

- (BOOL)saveEncryptionKeyData:(CDTEncryptionKeychainData *)data
{
    BOOL success = NO;

    NSMutableData *archivedData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archivedData];
    [archiver setRequiresSecureCoding:YES];
    [archiver encodeObject:data forKey:CDTENCRYPTION_KEYCHAINSTORAGE_ARCHIVE_KEY];
    [archiver finishEncoding];
    
    NSMutableDictionary *dataStoreDict =
        [CDTEncryptionKeychainStorage genericPwStoreDictWithService:self.service
                                                            account:self.account
                                                               data:archivedData];

    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)dataStoreDict, nil);
    if (err == noErr) {
        success = YES;
    } else if (err == errSecDuplicateItem) {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"Doc already exists in keychain");
        success = NO;
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Unable to store Doc in keychain, SecItemAdd returned: %d", err);
        success = NO;
    }

    return success;
}

- (BOOL)clearEncryptionKeyData
{
    BOOL success = NO;

    NSMutableDictionary *dict =
        [CDTEncryptionKeychainStorage genericPwLookupDictWithService:self.service
                                                             account:self.account];
    [dict removeObjectForKey:(__bridge id)(kSecMatchLimit)];
    [dict removeObjectForKey:(__bridge id)(kSecReturnAttributes)];
    [dict removeObjectForKey:(__bridge id)(kSecReturnData)];

    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)dict);

    if (err == noErr || err == errSecItemNotFound) {
        success = YES;
    } else {
        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                   @"Error getting DPK doc from keychain, SecItemDelete returned: %d", err);
    }

    return success;
}

- (BOOL)encryptionKeyDataExists
{
    BOOL result = NO;

    NSData *data = nil;
    NSMutableDictionary *query =
        [CDTEncryptionKeychainStorage genericPwLookupDictWithService:self.service
                                                             account:self.account];

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, (void *)&data);
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

    [genericPasswordQuery setObject:(__bridge id)(kSecAttrAccessibleAfterFirstUnlock)
                             forKey:(__bridge id<NSCopying>)(kSecAttrAccessible)];

    return genericPasswordQuery;
}

@end
