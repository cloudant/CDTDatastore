//
//  CloudantSyncTests.m
//  CloudantSyncTests
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"

#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

@interface CloudantSyncTests ()

@property (nonatomic, readwrite) NSSet *sqlTables;


@end

@implementation CloudantSyncTests

- (NSString*)createTemporaryDirectoryAndReturnPath
{
    NSString *tempDirectoryTemplate =
    [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
    const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString =  (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
    
    char *result = mkdtemp(tempDirectoryNameCString);
    if (!result)
    {
        STFail(@"Couldn't create temporary directory");
    }
    
    NSString *path = [[NSFileManager defaultManager]
                        stringWithFileSystemRepresentation:tempDirectoryNameCString
                        length:strlen(result)];
    free(tempDirectoryNameCString);
    
    return path;
}

- (NSSet*)sqlTables
{
    if(_sqlTables)
        return _sqlTables;
    
    NSError *error;
    NSString *localFactoryPath = [self createTemporaryDirectoryAndReturnPath];
    CDTDatastoreManager *localFactory = [[CDTDatastoreManager alloc] initWithDirectory:localFactoryPath error:&error];
    STAssertNil(error, @"CDTDatastoreManager had error");
    STAssertNotNil(localFactory, @"Factory is nil");
    
    error = nil;
    NSString *dbName = @"temptogettables";
    CDTDatastore *datastore = [localFactory datastoreNamed:dbName error:&error];
    
    [datastore documentCount]; //internally, this calls ensureDatabaseOpen, which calls TD_Database open:, which
    //creates the tables in the sqlite db. otherwise, the database would be empty.
    
    NSString *dbPath = [localFactoryPath stringByAppendingPathComponent:[dbName stringByAppendingPathExtension:kDBExtension]];
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    STAssertNotNil(queue, @"FMDatabaseQueue was nil: %@", queue);
    __block NSMutableArray *tables = [[NSMutableArray alloc] init];
    
    [queue inDatabase:^(FMDatabase *db){
        NSString *sql = @"select name from sqlite_master where type='table' and name not in ('sqlite_sequence')";
        FMResultSet  *result = [db executeQuery:sql];
        while([result next]){
            [tables addObject:[result stringForColumn:@"name"]];
        }
        [result close];
    }];
    
    error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:localFactoryPath error:&error];
    STAssertNil(error, @"Error deleting temporary directory.");
    
    _sqlTables = [NSSet setWithArray:tables];
    return _sqlTables;
}

- (NSString *)pathForDBName:(NSString *)name
{
    return [self.factoryPath stringByAppendingPathComponent:[name stringByAppendingPathExtension:kDBExtension]];
}


- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    
    self.factoryPath = [self createTemporaryDirectoryAndReturnPath];
    
    NSError *error;
    self.factory = [[CDTDatastoreManager alloc] initWithDirectory:self.factoryPath error:&error];
    
    STAssertNil(error, @"CDTDatastoreManager had error");
    STAssertNotNil(self.factory, @"Factory is nil");
    
    _sqlTables = nil;
}

- (void)tearDown
{
    self.factory = nil;
    
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:self.factoryPath error:&error];
    STAssertNil(error, @"Error deleting temporary directory.");

    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

@end
