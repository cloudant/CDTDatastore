//
//  TD_Database+BlobFilenames.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 29/05/2015.
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

#import <FMDB/FMDB.h>

#import "TD_Database+BlobFilenames.h"

#import "TDMisc.h"
#import "CDTMisc.h"

#import "CDTLogging.h"

#define TDDATABASE_MAX_NUMBER_OF_TRIES_TO_GENERATE_AVAILABLE_FILENAME 200

NSString *const TDDatabaseBlobFilenamesTableName = @"attachments_key_filename";
NSString *const TDDatabaseBlobFilenamesIndexName = @"attachments_key_filename_index";

NSString *const TDDatabaseBlobFilenamesColumnKey = @"key";
NSString *const TDDatabaseBlobFilenamesColumnFilename = @"filename";

NSString *const TDDatabaseBlobFilenamesFileExtension = @"blob";

@implementation TD_Database (BlobFilenames)

#pragma mark - Public class methods
+ (NSString *)sqlCommandToCreateBlobFilenamesTable
{
    NSString *cmd =
        [NSString stringWithFormat:
                      @"CREATE TABLE %@ (%@ TEXT PRIMARY KEY, %@ TEXT); CREATE INDEX %@ ON %@(%@);",
                      TDDatabaseBlobFilenamesTableName, TDDatabaseBlobFilenamesColumnKey,
                      TDDatabaseBlobFilenamesColumnFilename, TDDatabaseBlobFilenamesIndexName,
                      TDDatabaseBlobFilenamesTableName, TDDatabaseBlobFilenamesColumnFilename];

    return cmd;
}

+ (NSString *)generateAndInsertFilenameBasedOnKey:(TDBlobKey)key
                 intoBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *hexKey = TDHexFromBytes(key.bytes, sizeof(key.bytes));
    NSString *filename = [TD_Database appendExtensionToName:hexKey];

    BOOL success =
        [TD_Database insertFilename:filename withHexKey:hexKey intoBlobFilenamesTableInDatabase:db];

    return (success ? filename : nil);
}

+ (NSString *)generateAndInsertRandomFilenameBasedOnKey:(TDBlobKey)key
                       intoBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *filename =
        [TD_Database generateAvailableBlobFilenameInBlobFilenamesTableInDatabase:db];
    if (filename) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Use filename %@", filename);
        
        NSString *hexKey = TDHexFromBytes(key.bytes, sizeof(key.bytes));

        BOOL success = [TD_Database insertFilename:filename
                                        withHexKey:hexKey
                  intoBlobFilenamesTableInDatabase:db];
        if (!success) {
            filename = nil;
        }
    }

    return filename;
}

+ (NSUInteger)countRowsInBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSUInteger count = 0;

    NSString *query =
        [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", TDDatabaseBlobFilenamesTableName];
    FMResultSet *r = [db executeQuery:query];

    @try {
        if ([r next]) {
            count = [r intForColumnIndex:0];
        }
    }
    @finally { [r close]; }

    return count;
}

+ (NSArray *)rowsInBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSMutableArray *allRows = [NSMutableArray array];

    NSString *query = [NSString
        stringWithFormat:@"SELECT %@, %@ FROM %@", TDDatabaseBlobFilenamesColumnKey,
                         TDDatabaseBlobFilenamesColumnFilename, TDDatabaseBlobFilenamesTableName];
    FMResultSet *r = [db executeQuery:query];

    @try {
        while ([r next]) {
            NSString *hexKey = [r stringForColumn:TDDatabaseBlobFilenamesColumnKey];
            NSData *keyData = dataFromHexadecimalString(hexKey);

            TDBlobKey key;
            [keyData getBytes:key.bytes];

            NSString *blobFilename = [r stringForColumn:TDDatabaseBlobFilenamesColumnFilename];

            TD_DatabaseBlobFilenameRow *oneRow =
                [TD_DatabaseBlobFilenameRow rowWithKey:key blobFilename:blobFilename];

            [allRows addObject:oneRow];
        }
    }
    @finally { [r close]; }

    return allRows;
}

+ (NSString *)filenameForKey:(TDBlobKey)key inBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *filename = nil;
    
    NSString *query = [NSString
        stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = :%@", TDDatabaseBlobFilenamesColumnFilename,
                         TDDatabaseBlobFilenamesTableName, TDDatabaseBlobFilenamesColumnKey,
                         TDDatabaseBlobFilenamesColumnKey];

    NSString *hexKey = TDHexFromBytes(key.bytes, sizeof(key.bytes));
    NSDictionary *parameters = @{TDDatabaseBlobFilenamesColumnKey : hexKey};

    FMResultSet *r = [db executeQuery:query withParameterDictionary:parameters];

    @try {
        if ([r next]) {
            filename = [r stringForColumn:TDDatabaseBlobFilenamesColumnFilename];
        }
    }
    @finally { [r close]; }
    
    return filename;
}

+ (BOOL)isThereARowWithFilename:(NSString *)filename inBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    BOOL isThereARow = YES;

    NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@ = :%@",
                                                 TDDatabaseBlobFilenamesTableName,
                                                 TDDatabaseBlobFilenamesColumnFilename,
                                                 TDDatabaseBlobFilenamesColumnFilename];

    NSDictionary *parameters = @{TDDatabaseBlobFilenamesColumnFilename : filename};

    FMResultSet *r = [db executeQuery:query withParameterDictionary:parameters];

    @try {
        if ([r next]) {
            int count = [r intForColumnIndex:0];

            isThereARow = (count != 0);
        }
    }
    @finally { [r close]; }

    return isThereARow;
}

+ (BOOL)deleteRowForKey:(TDBlobKey)key inBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *update = [NSString
        stringWithFormat:@"DELETE FROM %@ WHERE %@ = :%@", TDDatabaseBlobFilenamesTableName,
                         TDDatabaseBlobFilenamesColumnKey, TDDatabaseBlobFilenamesColumnKey];

    NSString *hexKey = TDHexFromBytes(key.bytes, sizeof(key.bytes));
    NSDictionary *parameters = @{TDDatabaseBlobFilenamesColumnKey : hexKey};

    BOOL success = [db executeUpdate:update withParameterDictionary:parameters];
    
    return success;
}

#pragma mark - Private class methods
+ (BOOL)insertFilename:(NSString *)filename
                          withHexKey:(NSString *)hexKey
    intoBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *update = [NSString
        stringWithFormat:@"INSERT INTO %@ (%@, %@) VALUES (:%@, :%@)",
                         TDDatabaseBlobFilenamesTableName, TDDatabaseBlobFilenamesColumnKey,
                         TDDatabaseBlobFilenamesColumnFilename, TDDatabaseBlobFilenamesColumnKey,
                         TDDatabaseBlobFilenamesColumnFilename];

    NSDictionary *parameters = @{
        TDDatabaseBlobFilenamesColumnKey : hexKey,
        TDDatabaseBlobFilenamesColumnFilename : filename
    };

    return [db executeUpdate:update withParameterDictionary:parameters];
}

+ (NSString *)generateAvailableBlobFilenameInBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *filename = nil;

    for (NSInteger i = 0;
         !filename && (i < TDDATABASE_MAX_NUMBER_OF_TRIES_TO_GENERATE_AVAILABLE_FILENAME); i++) {
        filename = [TD_Database generateRandomBlobFilename];

        if ([TD_Database isThereARowWithFilename:filename inBlobFilenamesTableInDatabase:db]) {
            CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Filename %@ already in use", filename);
            
            filename = nil;
        }
    }

    return filename;
}

+ (NSString *)generateRandomBlobFilename
{
    uint8_t randBytes[SHA_DIGEST_LENGTH];
    arc4random_buf(randBytes, SHA_DIGEST_LENGTH);
    
    NSString *randStr = TDHexFromBytes(randBytes, sizeof(randBytes));
    
    NSString *filename = [TD_Database appendExtensionToName:randStr];
    
    return filename;
}

+ (NSString *)appendExtensionToName:(NSString *)name
{
    NSString *str = [name stringByAppendingPathExtension:TDDatabaseBlobFilenamesFileExtension];

    return str;
}

@end

@interface TD_DatabaseBlobFilenameRow ()

@end

@implementation TD_DatabaseBlobFilenameRow

#pragma mark - Init object
- (instancetype)init
{
    TDBlobKey key;

    return [self initWithKey:key blobFilename:nil];
}

- (instancetype)initWithKey:(TDBlobKey)key blobFilename:(NSString *)blobFilename
{
    self = [super init];
    if (self) {
        if (blobFilename && (blobFilename.length > 0)) {
            _key = key;
            _blobFilename = blobFilename;
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Filename is mandatory");
            
            self = nil;
        }
    }
    
    return self;
}

#pragma mark - Public class methods
+ (instancetype)rowWithKey:(TDBlobKey)key blobFilename:(NSString *)blobFilename
{
    return [[[self class] alloc] initWithKey:key blobFilename:blobFilename];
}

@end