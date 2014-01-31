//
//  TD_DatabaseManagerTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TD_DatabaseManager.h"
#import "TD_Database.h"

@interface TD_DatabaseManagerTests : SenTestCase


@end

@implementation TD_DatabaseManagerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testManager
{
    //RequireTestCase(TD_Database); how can I do this in XCode?
    
    TD_DatabaseManager* dbm = [TD_DatabaseManager createEmptyAtTemporaryPath: @"TD_DatabaseManagerTest"];
    TD_Database* db = [dbm databaseNamed: @"foo"];
    
    STAssertNotNil(db, @"TD_Database is nil in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(db.name, @"foo", @"TD_Database.name is not \"foo\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(db.path.stringByDeletingLastPathComponent, dbm.directory, @"TD_Database path is not equal to path supplied by TD_DatabaseManager in %s", __PRETTY_FUNCTION__);
    
    STAssertTrue(!db.exists, @"TD_Database already exists in %s", __PRETTY_FUNCTION__);
    
    STAssertEquals([dbm databaseNamed: @"foo"], db, @"TD_DatabaseManager is not aware of a database named \"foo\" in %s", __PRETTY_FUNCTION__);
    
    STAssertEqualObjects(dbm.allDatabaseNames, @[], @"TD_DatabaseManager reports some database already exists in %s", __PRETTY_FUNCTION__);    // because foo doesn't exist yet
    
    STAssertTrue([db open], @"TD_Database.open returned NO in %s", __PRETTY_FUNCTION__);
    STAssertTrue(db.exists, @"TD_Database does not exist in %s", __PRETTY_FUNCTION__);
    
    STAssertEqualObjects(dbm.allDatabaseNames, @[@"foo"], @"TD_DatabaseManager reports some database other than \"foo\" in %s", __PRETTY_FUNCTION__);  // because foo should now exist and be the only database here
}




@end
