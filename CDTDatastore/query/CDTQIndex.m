//
//  CDTQIndex.m
//
//  Created by Al Finkelstein on 2015-04-20
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTQIndex.h"

#import "CDTLogging.h"

NSString *const kCDTQJsonType = @"json";
NSString *const kCDTQTextType = @"text";

static NSString *const kCDTQTextTokenize = @"tokenize";
static NSString *const kCDTQTextDefaultTokenizer = @"simple";

@interface CDTQIndex ()

@end

@implementation CDTQIndex

// Static array of supported index types
+ (NSArray *)validTypes
{
    static NSArray *validTypesArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        validTypesArray = @[ kCDTQJsonType, kCDTQTextType ];
#pragma clang diagnostic pop
    });
    return validTypesArray;
}

// Static array of supported index settings
+ (NSArray *)validSettings
{
    static NSArray *validSettingsArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validSettingsArray = @[ kCDTQTextTokenize ];
    });
    return validSettingsArray;
}

- (instancetype)initWithFields:(NSArray *)fieldNames
                     indexName:(NSString *)indexName
                     indexType:(CDTQIndexType)indexType
                 indexSettings:(NSDictionary *)indexSettings
{
    self = [super init];
    if (self) {
        _fieldNames = fieldNames;
        _indexName = indexName;
        _type = indexType;
        _indexSettings = indexSettings;
    }
    return self;
}

#pragma mark Deprecated creator methods

+ (instancetype)index:(NSString *)indexName withFields:(NSArray *)fieldNames
{
    return [[self class] index:indexName withFields:fieldNames type:CDTQIndexTypeJSON];
}

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray *)fieldNames
               ofType:(NSString *)indexType
{
    return [[self class] index:indexName withFields:fieldNames ofType:indexType withSettings:nil];
}

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray *)fieldNames
               ofType:(NSString *)indexType
         withSettings:(NSDictionary *)indexSettings
{
    CDTQIndexType typeAsEnum = [CDTQIndexManager indexTypeForString:indexType];
    return [[self class] index:indexName
                    withFields:fieldNames
                          type:typeAsEnum
                  withSettings:indexSettings];
}

#pragma mark Enum index type creator methods

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray<NSString *> *)fieldNames
                 type:(CDTQIndexType)type
{
    return [[self class] index:indexName withFields:fieldNames type:type withSettings:nil];
}

+ (instancetype)index:(NSString *)indexName
           withFields:(NSArray *)fieldNames
                 type:(CDTQIndexType)indexType
         withSettings:(NSDictionary *)indexSettings
{
    if (fieldNames.count == 0) {
        CDTLogError(CDTQ_LOG_CONTEXT, @"No field names provided.");
        return nil;
    }
    
    if (indexName.length == 0) {
        CDTLogError(CDTQ_LOG_CONTEXT, @"No index name provided.");
        return nil;
    }

    if (indexType == CDTQIndexTypeJSON && indexSettings) {
        CDTLogWarn(CDTQ_LOG_CONTEXT, @"Index type is JSON, index settings %@ ignored.",
                   indexSettings);
        indexSettings = nil;
    } else if (indexType == CDTQIndexTypeText) {
        if (!indexSettings) {
            indexSettings = @{ kCDTQTextTokenize: kCDTQTextDefaultTokenizer };
            CDTLogDebug(CDTQ_LOG_CONTEXT, @"Index type is text, defaulting settings to %@.",
                        indexSettings);
        } else {
            for (NSString *parameter in [indexSettings allKeys]) {
                if (![[CDTQIndex validSettings] containsObject:parameter.lowercaseString]) {
                    CDTLogError(CDTQ_LOG_CONTEXT, @"Invalid parameter %@ in index settings %@.",
                                parameter, indexSettings);
                    return nil;
                }
            }
        }
    }
    
    return [[[self class] alloc] initWithFields:fieldNames
                                      indexName:indexName
                                      indexType:indexType
                                  indexSettings:indexSettings];
}

-(BOOL) compareIndexTypeTo:(NSString *)indexType withIndexSettings:(NSString *)indexSettings
{
    return [self compareToIndexType:[CDTQIndexManager indexTypeForString:indexType]
                  withIndexSettings:indexSettings];
}

- (BOOL)compareToIndexType:(CDTQIndexType)indexType withIndexSettings:(NSString *)indexSettings
{
    if (self.type != indexType) {
        return NO;
    }
    
    if (!self.indexSettings && !indexSettings) {
        return YES;
    } else if (!self.indexSettings || !indexSettings) {
        return NO;
    }
    
    NSError *error;
    NSData *settingsData = [indexSettings dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *settingsDict = [NSJSONSerialization JSONObjectWithData:settingsData
                                                                 options:kNilOptions
                                                                   error:&error];
    if (!settingsDict) {
        CDTLogError(CDTQ_LOG_CONTEXT, @"Error processing index settings %@", indexSettings);
        return NO;
    }
    
    return [self.indexSettings isEqualToDictionary:settingsDict];
}

-(NSString *) settingsAsJSON {
    if (!self.indexSettings) {
        CDTLogWarn(CDTQ_LOG_CONTEXT, @"Index settings are nil.  Nothing to return.");
        return nil;
    }
    NSError *error;
    NSData *settingsData = [NSJSONSerialization dataWithJSONObject:self.indexSettings
                                                           options:kNilOptions
                                                             error:&error];
    if (!settingsData) {
        CDTLogError(CDTQ_LOG_CONTEXT, @"Error processing index settings %@", self.indexSettings);
        return nil;
    }
    
    return [[NSString alloc] initWithData:settingsData encoding:NSUTF8StringEncoding];
}

#pragma property overrides
/*
 These overrides are needed to ensure both the string and  enum versions of the index type are
 equivalent values.
 */
- (void)setIndexType:(NSString *)indexType
{
    self.type = [CDTQIndexManager indexTypeForString:indexType];
}

- (NSString *)indexType { return [CDTQIndexManager stringForIndexType:self.type]; }
@end
