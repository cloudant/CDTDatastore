//
//  CDTEncryptionKeychainManager+Internal.h
//  
//
//  Created by Enrique de la Torre Fernandez on 15/04/2015.
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

/**
 This category is only for testing purposes. It presents some of the private methods used by
 CDTEncryptionKeychainManager to complete its job.
 
 Notice that although all these methods are instance methods, none of them modifies the state of a
 CDTEncryptionKeychainManager instance or writes to disk, however they are easier to override
 this way.
 */
@interface CDTEncryptionKeychainManager (Internal)

- (BOOL)validatedEncryptionKeyData:(CDTEncryptionKeychainData *)data;

- (NSData *)generateDpk;

- (CDTEncryptionKeychainData *)keychainDataToStoreDpk:(NSData *)dpk
                                encryptedWithPassword:(NSString *)password;

- (NSData *)generatePBKDF2Salt;
- (NSData *)generateAESKeyUsingPBKDF2ToDerivePassword:(NSString *)password
                                             withSalt:(NSData *)salt
                                           iterations:(NSInteger)iterations
                                               length:(NSUInteger)length;

- (NSData *)generateAESIv;

- (NSData *)encryptDpk:(NSData *)dpk usingAESWithKey:(NSData *)key iv:(NSData *)iv;
- (NSData *)decryptCipheredDpk:(NSData *)cipheredDpk usingAESWithKey:(NSData *)key iv:(NSData *)iv;

@end
