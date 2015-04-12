//
//  CDTEncryptionKeychainData.h
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

#import <Foundation/Foundation.h>

@interface CDTEncryptionKeychainData : NSObject

@property (strong, nonatomic, readonly) NSString *encryptedDPK;
@property (strong, nonatomic, readonly) NSString *salt;
@property (strong, nonatomic, readonly) NSString *IV;
@property (strong, nonatomic, readonly) NSNumber *iterations;
@property (strong, nonatomic, readonly) NSString *version;

- (instancetype)initWithEncryptedDPK:(NSString *)encryptedDPK
                                salt:(NSString *)salt
                                  iv:(NSString *)IV
                          iterations:(NSNumber *)iterations
                             version:(NSString *)version;

+ (instancetype)dataWithEncryptedDPK:(NSString *)encryptedDPK
                                salt:(NSString *)salt
                                  iv:(NSString *)IV
                          iterations:(NSNumber *)iterations
                             version:(NSString *)version;

@end
