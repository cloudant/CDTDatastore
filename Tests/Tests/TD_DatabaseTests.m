//
//  TD_DatabaseTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TD_Database.h"
#import "TD_Revision.h"

extern NSDictionary* makeRevisionHistoryDict(NSArray* history);

@interface TD_DatabaseTests : SenTestCase


@end

@implementation TD_DatabaseTests

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


- (TD_Revision*)mkrev:(NSString*)revID
{
    return [[TD_Revision alloc] initWithDocID: @"docid" revID: revID deleted: NO];
}

- (void) testRevisionDictionary
{
    NSArray* revs = @[[self mkrev:@"4-jkl"], [self mkrev:@"3-ghi"], [self mkrev:@"2-def"]];
    STAssertEqualObjects(makeRevisionHistoryDict(revs), $dict({@"ids", @[@"jkl", @"ghi", @"def"]},
                                                      {@"start", @4}), @"4-3-2 revs failed in %s", __PRETTY_FUNCTION__);
    
    revs = @[[self mkrev:@"4-jkl"], [self mkrev:@"2-def"]];
    STAssertEqualObjects(makeRevisionHistoryDict(revs), $dict({@"ids", @[@"4-jkl", @"2-def"]}), @"4-2 revs failed in %s", __PRETTY_FUNCTION__);
    
    revs = @[[self mkrev:@"12345"], [self mkrev:@"6789"]];
    STAssertEqualObjects(makeRevisionHistoryDict(revs), $dict({@"ids", @[@"12345", @"6789"]}), @"12345-6789 revs failed in %s", __PRETTY_FUNCTION__);
}




@end
