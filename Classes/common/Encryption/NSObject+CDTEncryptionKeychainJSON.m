//
//  NSObject+CDTEncryptionKeychainJSON.m
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

#import "NSObject+CDTEncryptionKeychainJSON.h"

#import "CDTLogging.h"

@implementation NSObject (CDTEncryptionKeychainJSON)

#pragma mark - Public methods
- (NSData *)CDTEncryptionKeychainJSONData
{
    return [self CDTEncryptionKeychainJSONDataWithOption:0];
}

- (NSString *)CDTEncryptionKeychainJSONRepresentation
{
    return [[NSString alloc] initWithData:[self CDTEncryptionKeychainJSONData]
                                 encoding:NSUTF8StringEncoding];
}

#pragma mark - Private methods
- (NSData *)CDTEncryptionKeychainJSONDataWithOption:(int)options
{
    NSError *error = nil;

    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:options error:&error];
    if (!data) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Failed to get Data with JSONObject: %@", error);
    }

    return data;
}

@end
