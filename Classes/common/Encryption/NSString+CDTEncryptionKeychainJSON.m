//
//  NSString+CDTEncryptionKeychainJSON.m
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

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#import "NSString+CDTEncryptionKeychainJSON.h"

#import "CDTLogging.h"

@implementation NSString (CDTEncryptionKeychainJSON)

#pragma mark - Public methods
- (id)CDTEncryptionKeychainJSONValue
{
    NSError *error = nil;
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    id jsonValue = [NSJSONSerialization
        JSONObjectWithData:data
                   options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves
                     error:&error];

    if (!jsonValue) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Error getting JSON value: %@", error);
    }

    return jsonValue;
}

@end
