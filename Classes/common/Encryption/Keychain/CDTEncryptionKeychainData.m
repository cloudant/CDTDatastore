//
//  CDTEncryptionKeychainData.m
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

#import "CDTEncryptionKeychainData.h"

#import "CDTLogging.h"

@interface CDTEncryptionKeychainData ()

@end

@implementation CDTEncryptionKeychainData

#pragma mark - Init object
- (instancetype)init
{
    return [self initWithEncryptedDPK:nil salt:nil iv:nil iterations:nil version:nil];
}

- (instancetype)initWithEncryptedDPK:(NSString *)encryptedDPK
                                salt:(NSString *)salt
                                  iv:(NSString *)IV
                          iterations:(NSNumber *)iterations
                             version:(NSString *)version
{
    self = [super init];
    if (self) {
        if (encryptedDPK && salt && IV && iterations && version) {
            _encryptedDPK = encryptedDPK;
            _salt = salt;
            _IV = IV;
            _iterations = iterations;
            _version = version;
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"All params are mandatory");

            self = nil;
        }
    }

    return self;
}

#pragma mark - Public class methods
+ (instancetype)dataWithEncryptedDPK:(NSString *)encryptedDPK
                                salt:(NSString *)salt
                                  iv:(NSString *)IV
                          iterations:(NSNumber *)iterations
                             version:(NSString *)version
{
    return [[[self class] alloc] initWithEncryptedDPK:encryptedDPK
                                                 salt:salt
                                                   iv:IV
                                           iterations:iterations
                                              version:version];
}

@end
