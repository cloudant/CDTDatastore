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

@interface CDTEncryptionKeychainManager : NSObject

/**
 * Returns the decrypted Data Protection Key (DPK) from the keychain.
 *
 * @param password Password used to decrypt the DPK
 *
 * @return The DPK
 */
- (NSString *)getDPK:(NSString *)password;

/**
 * Generates the Data Protection Key (DPK) locally, encrypts it, and stores it inside the keychain.
 *
 * @param password Password used for the Client Based Key (CBK) to encrypt the DPK
 * @param salt The salt
 *
 * @return Success (true) or failure (false)
 */
- (BOOL)generateAndStoreDpkUsingPassword:(NSString *)password withSalt:(NSString *)salt;

/**
 * Checks if the encrypted Data Protection Key (DPK) is inside the keychain.
 *
 * @return True if the encrypted DPK is inside the keychain, false otherwise
 */
- (BOOL)isKeyChainFullyPopulated;

/**
 * Clears JSONStore security metadata from the keychain.
 *
 * @return Success (true) or failure (false)
 */
- (BOOL)clearKeyChain;

@end
