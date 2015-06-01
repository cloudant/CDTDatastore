//
//  TD_DatabaseBlobFilenamesTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 29/05/2015.
//
//

#import <XCTest/XCTest.h>

#import <FMDB.h>

#import "TD_Database+BlobFilenames.h"

#import "CDTEncryptionKeyNilProvider.h"

@interface TD_DatabaseBlobFilenamesTests : XCTestCase

@end

@implementation TD_DatabaseBlobFilenamesTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    [super tearDown];
}

- (void)testAddTableToRelateKeysAndFilenamesToDatabaseSchema
{
    // Copy db with entries in attachment table
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *assetPath = [bundle pathForResource:@"schema100_1Bonsai_2Lorem" ofType:@"touchdb"];

    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"schema100_1Bonsai_2Lorem.touchdb"];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager copyItemAtPath:assetPath toPath:path error:nil];

    // Open db
    TD_Database *db = [[TD_Database alloc] initWithPath:path];

    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];
    [db openWithEncryptionKeyProvider:provider];

    // Check db
    __block int count = 0;

    [db.fmdbQueue inDatabase:^(FMDatabase *db) {
      NSString *sql = [NSString
          stringWithFormat:
              @"SELECT COUNT(*) AS counts FROM sqlite_master WHERE type='table' AND name='%@'",
              TDDatabaseBlobFilenamesTableName];

      FMResultSet *result = [db executeQuery:sql];
      [result next];
      count = [result intForColumn:@"counts"];
      [result close];
    }];

    // Remove copied db
    [db close];
    [TD_Database deleteClosedDatabaseAtPath:path error:nil];

    // Assert
    XCTAssertEqual(count, 1, @"Table %@ not found", TDDatabaseBlobFilenamesTableName);
}

- (void)testDBVersionIsUpdatedAfterMigration
{
    __block int dbVersion = 0;

    [self.db.fmdbQueue inDatabase:^(FMDatabase *db) {
      dbVersion = [db intForQuery:@"PRAGMA user_version"];
    }];

    XCTAssertEqual(dbVersion, 101, @"Database version should be 101");
}
@end
