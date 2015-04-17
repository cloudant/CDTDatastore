//
//  CDTEncryptionKeychainManager.h
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

#import <Foundation/Foundation.h>

#import "CDTEncryptionKeychainStorage.h"

/**
 Use this class to generate a Data Protection Key (DPK), i.e. a strong password that can be used
 later on for other purposes like ciphering a database.
 
 The generated DPK is automatically encrypted and saved to the keychain, for this reason, it is
 neccesary to provide a password to generate and retrieve the DPK.
 */
@interface CDTEncryptionKeychainManager : NSObject

/**
 Initialise a manager with a CDTEncryptionKeychainStorage instance.
 
 A CDTEncryptionKeychainStorage gives access to the keychain throught an identifier, this means
 that the DPK saved to the keychain is bound to this identifier. If a new manager is created with
 a storage pointing to another identifier, the previous DPK will not be accesible. So you can
 create as many DPKs as you want as long as you provide different identifiers.
 
 @param storage 
 
 @see CDTEncryptionKeychainStorage
 */
- (instancetype)initWithStorage:(CDTEncryptionKeychainStorage *)storage;

/**
 Returns the decrypted Data Protection Key (DPK) from the keychain.
 
 @param password Password used to decrypt the DPK
 
 @return The DPK
 */
- (NSData *)retrieveEncryptionKeyDataUsingPassword:(NSString *)password;

/**
 Generates a Data Protection Key (DPK), encrypts it, and stores it inside the keychain.
 
 @param password Password used to encrypt the DPK
 
 @return The DPK
 */
- (NSData *)generateEncryptionKeyDataUsingPassword:(NSString *)password;

/**
 Checks if the encrypted Data Protection Key (DPK) is inside the keychain.
 
 @return YES if the encrypted DPK is inside the keychain, NO otherwise
 */
- (BOOL)encryptionKeyDataAlreadyGenerated;

/**
 Clears security metadata from the keychain.
 
 @return Success (true) or failure (false)
 */
- (BOOL)clearEncryptionKeyData;

@end
