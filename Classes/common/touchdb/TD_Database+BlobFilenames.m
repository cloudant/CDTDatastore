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

#import "CDTLogging.h"

NSString *const TDDatabaseBlobFilenamesTableName = @"attachments_key_filename";

NSString *const TDDatabaseBlobFilenamesColumnKey = @"key";
NSString *const TDDatabaseBlobFilenamesColumnFilename = @"filename";

NSString *const TDDatabaseBlobFilenamesFileExtension = @"blob";

@implementation TD_Database (BlobFilenames)

#pragma mark - Public class methods
+ (NSString *)sqlCommandToCreateBlobFilenamesTable
{
    NSString *cmd = [NSString stringWithFormat:@"CREATE TABLE %@ (%@ TEXT PRIMARY KEY, %@ TEXT)",
                                               TDDatabaseBlobFilenamesTableName,
                                               TDDatabaseBlobFilenamesColumnKey,
                                               TDDatabaseBlobFilenamesColumnFilename];

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
        NSData *keyData = nil;
        NSString *blobFilename = nil;
        TD_DatabaseBlobFilenameRow *oneRow = nil;

        while ([r next]) {
            keyData = [r dataNoCopyForColumn:TDDatabaseBlobFilenamesColumnKey];
            blobFilename = [r stringForColumn:TDDatabaseBlobFilenamesColumnFilename];

            oneRow = [TD_DatabaseBlobFilenameRow rowWithKey:*(TDBlobKey *)keyData.bytes
                                               blobFilename:blobFilename];
            
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

+ (BOOL)deleteRowForKey:(TDBlobKey)key inBlobFilenamesTableInDatabase:(FMDatabase *)db
{
    NSString *update = [NSString
        stringWithFormat:@"DELETE FROM %@ WHERE %@ = :%@", TDDatabaseBlobFilenamesTableName,
                         TDDatabaseBlobFilenamesColumnKey, TDDatabaseBlobFilenamesColumnKey];

    NSString *hexKey = TDHexFromBytes(key.bytes, sizeof(key.bytes));
    NSDictionary *parameters = @{TDDatabaseBlobFilenamesColumnKey : hexKey};

    return [db executeUpdate:update withParameterDictionary:parameters];
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

+ (NSString *)appendExtensionToName:(NSString *)name
{
    NSString *str =
        [NSString stringWithFormat:@"%@.%@", name, TDDatabaseBlobFilenamesFileExtension];

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