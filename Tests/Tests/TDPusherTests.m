//
//  TDPusherTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TDPusher.h"
#import "TDInternal.h"

extern int findCommonAncestor(TD_Revision* rev, NSArray* possibleRevIDs);

@interface TDPusherTests : SenTestCase


@end

@implementation TDPusherTests


- (void)testFindCommonAncestor
{
    NSDictionary* revDict = $dict({@"ids", @[@"second", @"first"]}, {@"start", @2});
    TD_Revision* rev = [TD_Revision revisionWithProperties: $dict({@"_revisions", revDict})];
    STAssertEquals(findCommonAncestor(rev, @[]), 0, @"Did not find zero common ancestors in empty rev dictionary in %s", __PRETTY_FUNCTION__);
    STAssertEquals(findCommonAncestor(rev, @[@"3-noway", @"1-nope"]), 0, @"Did not find zero common ancestors in incorrect rev dictionary in %s", __PRETTY_FUNCTION__);
    STAssertEquals(findCommonAncestor(rev, @[@"3-noway", @"1-first"]), 1, @"Did not find common ancestor 1-first in rev dictionary in %s", __PRETTY_FUNCTION__);
    STAssertEquals(findCommonAncestor(rev, @[@"3-noway", @"2-second", @"1-first"]), 2, @"Did not find common ancestor 2-second in rev dictionary in %s", __PRETTY_FUNCTION__);
}


@end
