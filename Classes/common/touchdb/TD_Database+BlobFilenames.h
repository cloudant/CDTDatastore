//
//  TD_Database+BlobFilenames.h
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

#import "TD_Database.h"

#import "TDBlobStore.h"

extern NSString *const TDDatabaseBlobFilenamesTableName;

extern NSString *const TDDatabaseBlobFilenamesColumnKey;
extern NSString *const TDDatabaseBlobFilenamesColumnFilename;

extern NSString *const TDDatabaseBlobFilenamesFileExtension;

@interface TD_Database (BlobFilenames)

+ (NSString *)sqlCommandToCreateBlobFilenamesTable;

+ (NSString *)generateAndInsertFilenameBasedOnKey:(TDBlobKey)key
                 intoBlobFilenamesTableInDatabase:(FMDatabase *)db;

+ (NSUInteger)countRowsInBlobFilenamesTableInDatabase:(FMDatabase *)db;
+ (NSArray *)rowsInBlobFilenamesTableInDatabase:(FMDatabase *)db;

+ (NSString *)filenameForKey:(TDBlobKey)key inBlobFilenamesTableInDatabase:(FMDatabase *)db;

+ (BOOL)deleteRowForKey:(TDBlobKey)key inBlobFilenamesTableInDatabase:(FMDatabase *)db;

@end

@interface TD_DatabaseBlobFilenameRow : NSObject

@property (assign, nonatomic, readonly) TDBlobKey key;
@property (strong, nonatomic, readonly) NSString *blobFilename;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

- (instancetype)initWithKey:(TDBlobKey)key
               blobFilename:(NSString *)blobFilename NS_DESIGNATED_INITIALIZER;

+ (instancetype)rowWithKey:(TDBlobKey)key blobFilename:(NSString *)blobFilename;

@end
