//
//  TD_DatabaseTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import "CollectionUtils.h"
#import "TD_Database.h"
#import "TD_Revision.h"
#import "CloudantTests.h"

extern NSDictionary* makeRevisionHistoryDict(NSArray* history);

@interface TD_DatabaseTests : CloudantTests


@end

@implementation TD_DatabaseTests

- (TD_Revision*)mkrev:(NSString*)revID
{
    return [[TD_Revision alloc] initWithDocID: @"docid" revID: revID deleted: NO];
}

- (void) testRevisionDictionary
{
    NSArray* revs = @[[self mkrev:@"4-jkl"], [self mkrev:@"3-ghi"], [self mkrev:@"2-def"]];
    XCTAssertEqualObjects(makeRevisionHistoryDict(revs), $dict({@"ids", @[@"jkl", @"ghi", @"def"]},
                                                      {@"start", @4}), @"4-3-2 revs failed in %s", __PRETTY_FUNCTION__);
    
    revs = @[[self mkrev:@"4-jkl"], [self mkrev:@"2-def"]];
    XCTAssertEqualObjects(makeRevisionHistoryDict(revs), $dict({@"ids", @[@"4-jkl", @"2-def"]}), @"4-2 revs failed in %s", __PRETTY_FUNCTION__);
    
    revs = @[[self mkrev:@"12345"], [self mkrev:@"6789"]];
    XCTAssertEqualObjects(makeRevisionHistoryDict(revs), $dict({@"ids", @[@"12345", @"6789"]}), @"12345-6789 revs failed in %s", __PRETTY_FUNCTION__);
}




@end
