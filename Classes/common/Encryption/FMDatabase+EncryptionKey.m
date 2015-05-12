//
//  FMDatabase+EncryptionKey.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 27/04/2015.
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

#import "FMDatabase+EncryptionKey.h"

#import "TDMisc.h"
#import "CDTLogging.h"

@implementation FMDatabase (EncryptionKey)

NSString *const FMDatabaseEncryptionKeyErrorDomain = @"FMDatabaseEncryptionKeyErrorDomain";

#pragma mark - Public methods
- (BOOL)setKeyWithProvider:(id<CDTEncryptionKeyProvider>)provider error:(NSError **)error
{
    BOOL success = YES;
    NSError *thisError = nil;
    
    // Get the key
    CDTEncryptionKey *encryptionKey = [provider encryptionKey];

    // Set the key (if there is any)
    if (encryptionKey) {
        NSString *hexEncryptionKey = TDHexFromBytes(encryptionKey.bytes, CDTENCRYPTIONKEY_KEYSIZE);
        success = [self setKey:hexEncryptionKey];
        if (!success) {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT,
                        @"Key to decrypt DB at %@ not set. DB can not be opened.",
                        [self databasePath]);

            NSString *desc = NSLocalizedString(@"Key to decrypt DB not set", nil);
            thisError = [NSError errorWithDomain:FMDatabaseEncryptionKeyErrorDomain
                                            code:FMDatabaseEncryptionKeyErrorKeyNotSet
                                        userInfo:@{NSLocalizedDescriptionKey : desc}];
        }
    }

    // Try to read the db
    if (success) {
        success = (sqlite3_exec(self.sqliteHandle, "SELECT count(*) FROM sqlite_master;", NULL,
                                NULL, NULL) == SQLITE_OK);
        if (!success) {
            if (encryptionKey) {
                CDTLogError(
                    CDTDATASTORE_LOG_CONTEXT,
                    @"DB at %@ can not be deciphered with provided key. DB can not be opened.",
                    [self databasePath]);

                NSString *desc = NSLocalizedString(
                    @"DB can not be deciphered with provided key or DB is not encrypted", nil);
                thisError =
                    [NSError errorWithDomain:FMDatabaseEncryptionKeyErrorDomain
                                        code:FMDatabaseEncryptionKeyErrorWrongKeyOrDBNotEncrypted
                                    userInfo:@{NSLocalizedDescriptionKey : desc}];
            } else {
                CDTLogError(CDTDATASTORE_LOG_CONTEXT,
                            @"DB at %@ is encrypted but no key was provided. DB can not be opened.",
                            [self databasePath]);

                NSString *desc = NSLocalizedString(@"DB is encrypted but no key was provided", nil);
                thisError =
                    [NSError errorWithDomain:FMDatabaseEncryptionKeyErrorDomain
                                        code:FMDatabaseEncryptionKeyErrorNoKeyProvidedForEncryptedDB
                                    userInfo:@{NSLocalizedDescriptionKey : desc}];
            }
        }
    }

    // Return
    if (!success && error) {
        *error = thisError;
    }

    return success;
}

@end
