//
//  FMDatabase+SQLCipher.m
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

#import "FMDatabase+SQLCipher.h"

#import "CDTLogging.h"

NSString *const FMDatabaseStandardSQLiteHeader = @"SQLite format 3";

@implementation FMDatabase (SQLCipher)

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
