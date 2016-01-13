//
//  TDPusherTests.m
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
#import "TDPusher.h"
#import "TDInternal.h"
#import "CloudantTests.h"

extern int findCommonAncestor(TD_Revision* rev, NSArray* possibleRevIDs);

@interface TDPusherTests : CloudantTests


@end

@implementation TDPusherTests


- (void)testFindCommonAncestor
{
    NSDictionary* revDict = $dict({@"ids", @[@"second", @"first"]}, {@"start", @2});
    TD_Revision* rev = [TD_Revision revisionWithProperties: $dict({@"_revisions", revDict})];
    XCTAssertEqual(findCommonAncestor(rev, @[]), 0, @"Did not find zero common ancestors in empty rev dictionary in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(findCommonAncestor(rev, @[@"3-noway", @"1-nope"]), 0, @"Did not find zero common ancestors in incorrect rev dictionary in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(findCommonAncestor(rev, @[@"3-noway", @"1-first"]), 1, @"Did not find common ancestor 1-first in rev dictionary in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(findCommonAncestor(rev, @[@"3-noway", @"2-second", @"1-first"]), 2, @"Did not find common ancestor 2-second in rev dictionary in %s", __PRETTY_FUNCTION__);

//    STFail(@"test failing");
}


@end
