//
//  TD_DatabaseDeletionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 04/03/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

#import "CloudantTests.h"
#import "CDTEncryptionKeyNilProvider.h"

#import "TD_Database.h"

static BOOL databaseDeletionTestWasDatabaseAtPathDeleted = NO;

@interface TD_MockDatabase : TD_Database

@property (assign, nonatomic) BOOL isCloseExecuted;
@property (assign, nonatomic) BOOL forceCloseFailure;

@end

@implementation TD_MockDatabase

#pragma mark - Init object
- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self) {
        _isCloseExecuted = NO;
        _forceCloseFailure = NO;
    }

    return self;
}

#pragma mark - TD_Database methods
- (BOOL)close
{
    self.isCloseExecuted = YES;

    return (self.forceCloseFailure ? NO : [super close]);
}

+ (BOOL)deleteClosedDatabaseAtPath:(NSString *)path error:(NSError **)outError
{
    databaseDeletionTestWasDatabaseAtPathDeleted = YES;

    return [super deleteClosedDatabaseAtPath:path error:outError];
}

@end

@interface TD_DatabaseDeletionTests : CloudantTests

@property (assign, nonatomic) BOOL willBeDeletedNotificationReceived;

@end

@implementation TD_DatabaseDeletionTests

- (void)setUp
{
    [super setUp];

    databaseDeletionTestWasDatabaseAtPathDeleted = NO;

    self.willBeDeletedNotificationReceived = NO;
}

- (void)tearDown { [super tearDown]; }

- (void)testDeleteDatabasePostNotification
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"TD_DatabaseDeletionTests_postNotification"];

    TD_MockDatabase *db =
        [TD_MockDatabase createEmptyDBAtPath:path withEncryptionKeyProvider:provider];

    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self
                      selector:@selector(didReceivedWillBeDeletedNotification:)
                          name:TD_DatabaseWillBeDeletedNotification
                        object:db];

    [db deleteDatabase:nil];

    [defaultCenter removeObserver:self name:TD_DatabaseWillBeDeletedNotification object:db];

    XCTAssertTrue(self.willBeDeletedNotificationReceived,
                  @"Send the corresponding notification when a db is deleted");
}

- (void)testDeleteDatabaseCloseDBIfItIsOpen
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"TD_DatabaseDeletionTests_closeIfOpen"];

    TD_MockDatabase *db =
        [TD_MockDatabase createEmptyDBAtPath:path withEncryptionKeyProvider:provider];

    [db deleteDatabase:nil];

    XCTAssertTrue(db.isCloseExecuted, @"Close the database before deleting it");
}

- (void)testDeleteDatabaseDoesNotCloseDBIfItIsNotOpen
{
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"TD_DatabaseDeletionTests_notCloseIfNotOpen"];

    TD_MockDatabase *db = [[TD_MockDatabase alloc] initWithPath:path];

    [db deleteDatabase:nil];

    XCTAssertFalse(db.isCloseExecuted,
                   @"If the db was not open, do not close it before deleting it");
}

- (void)testDeleteDatabaseCallsDeleteAtPath
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"TD_DatabaseDeletionTests_deleteAtPath"];

    TD_MockDatabase *db =
        [TD_MockDatabase createEmptyDBAtPath:path withEncryptionKeyProvider:provider];

    [db deleteDatabase:nil];
    
    XCTAssertTrue(databaseDeletionTestWasDatabaseAtPathDeleted,
                  @"Call the primery method to delete the database");
}

- (void)testDeleteDatabaseDoesNotCallDeleteAtPathIfCloseFails
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    NSString *path = [NSTemporaryDirectory()
                      stringByAppendingPathComponent:@"TD_DatabaseDeletionTests_NotDeleteAtPath"];
    
    TD_MockDatabase *db =
        [TD_MockDatabase createEmptyDBAtPath:path withEncryptionKeyProvider:provider];
    
    db.forceCloseFailure = YES;
    [db deleteDatabase:nil];
    
    XCTAssertFalse(databaseDeletionTestWasDatabaseAtPathDeleted,
                   @"Do not delete the db if it can not be closed");
}

- (void)testDeleteDatabaseRemoveFiles
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    NSString *path = [NSTemporaryDirectory()
                      stringByAppendingPathComponent:@"TD_DatabaseDeletionTests_removeFiles"];
    
    TD_MockDatabase *db =
        [TD_MockDatabase createEmptyDBAtPath:path withEncryptionKeyProvider:provider];
    
    [db deleteDatabase:nil];
    
    XCTAssertFalse(db.exists, @"When a db is delete, all files are removed from disk");
}

- (void)didReceivedWillBeDeletedNotification:(NSNotification *)notification
{
    self.willBeDeletedNotificationReceived = YES;
}

@end
