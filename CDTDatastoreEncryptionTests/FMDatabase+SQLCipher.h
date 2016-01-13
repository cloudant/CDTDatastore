//
//  FMDatabase+SQLCipher.h
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 29/03/2015.
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

#import <FMDB/FMDatabase.h>

/** Value type returned by +isDatabaseUnencryptedAtPath: */
typedef enum {
    kFMDatabaseUnencryptedIsEncrypted = 0,
    kFMDatabaseUnencryptedIsUnencrypted,
    kFMDatabaseUnencryptedNotFound
} FMDatabaseUnencrypted;

@interface FMDatabase (SQLCipher)

/**
 * Check if a SQLite database is not encrypted. A SQLite file starts with 'SQLite format 3'; this
 * method assumes that if the file starts with this text, it is a database and it is not encrypted.
 *
 * @param path path to the database
 *
 * @return kFMDatabaseUnencryptedIsUnencrypted if the file starts with the expected text.
 * kFMDatabaseUnencryptedIsEncrypted if the file starts with any other text.
 * kFMDatabaseUnencryptedNotFound if the file does not exist.
 */
+ (FMDatabaseUnencrypted)isDatabaseUnencryptedAtPath:(NSString *)path;

@end
