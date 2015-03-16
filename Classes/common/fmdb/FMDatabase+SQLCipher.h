//
//  FMDatabase+SQLCipher.h
//  
//
//  Created by Enrique de la Torre Fernandez on 29/03/2015.
//
//

#import "FMDatabase.h"

/** Value type returned by +isDatabaseUnencryptedAtPath: */
typedef enum {
    kFMDatabaseUnencryptedIsEncrypted = 0,
    kFMDatabaseUnencryptedIsUnencrypted,
    kFMDatabaseUnencryptedNotFound
} FMDatabaseUnencrypted;

@interface FMDatabase (SQLCipher)

/**
 * Set encryption key and validate if the database can be deciphered with it
 *
 * @param key The key to be used.
 *
 * @return YES if success, NO is the key is not set or data can not deciphered with it
 */
- (BOOL)setValidKey:(NSString*)key;

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
