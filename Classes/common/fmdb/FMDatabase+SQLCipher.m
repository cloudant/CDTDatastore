//
//  FMDatabase+SQLCipher.m
//  
//
//  Created by Enrique de la Torre Fernandez on 29/03/2015.
//
//

#import "FMDatabase+SQLCipher.h"

#import "CDTLogging.h"

NSString* const FMDatabaseStandardSQLiteHeader = @"SQLite format 3";

@implementation FMDatabase (SQLCipher)

#pragma mark - Public methods
- (BOOL)setValidKey:(NSString *)key
{
    BOOL result = [self setKey:key];
    if (!result) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT,
                    @"Key to de-encrypt DB at %@ not set. DB can not be opened.",
                    [self databasePath]);
    } else {
        // Verify if it is the right key
        result = (sqlite3_exec(self.sqliteHandle, "SELECT count(*) FROM sqlite_master;", NULL, NULL,
                               NULL) == SQLITE_OK);
        if (!result) {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT,
                        @"DB at %@ can not be deciphered with provided key. DB can not be opened.",
                        [self databasePath]);
        }
    }
    
    return result;
}

#pragma mark - Public class methods
+ (FMDatabaseUnencrypted)isDatabaseUnencryptedAtPath:(NSString *)path
{
    // Load file
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fileHandle) {
        return kFMDatabaseUnencryptedNotFound;
    }

    // Read first 15 bytes
    NSUInteger sqliteHeaderLength = [FMDatabaseStandardSQLiteHeader length];
    NSData *data = [fileHandle readDataOfLength:sqliteHeaderLength];

    char buffer[sqliteHeaderLength + 1];
    memset(buffer, '\0', sizeof(buffer));
    [data getBytes:buffer length:(sizeof(buffer) - 1)];

    // Compare: if the file starts with the default text, we assume that the file is not encrypted
    NSString *str = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];

    return ([FMDatabaseStandardSQLiteHeader isEqualToString:str]
                ? kFMDatabaseUnencryptedIsUnencrypted
                : kFMDatabaseUnencryptedIsEncrypted);
}

@end
