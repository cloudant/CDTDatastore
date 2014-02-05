//
//  TDSequenceMapTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TDSequenceMap.h"


@interface TDSequenceMapTests : SenTestCase


@end

@implementation TDSequenceMapTests

- (void)testSequenceMap
{
    TDSequenceMap *map = [[TDSequenceMap alloc] init];

    STAssertEquals(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence (%d), is not 0 in %s", map.checkpointedSequence, __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil in %s", __PRETTY_FUNCTION__);
    STAssertTrue(map.isEmpty, @"TDSequenceMap.isEmpty is not true in %s", __PRETTY_FUNCTION__);
    
    STAssertEquals([map addValue: @"one"], (SequenceNumber)1, @"TDSequenceMap.addValue did not return 1 in %s", __PRETTY_FUNCTION__);
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after addValue:@\"one\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after addValue \"one\"  in %s", __PRETTY_FUNCTION__);
    STAssertTrue(!map.isEmpty, @"TDSequenceMap.isEmpty is true in %s", __PRETTY_FUNCTION__);
    
    STAssertEquals([map addValue: @"two"], (SequenceNumber)2, @"TDSequenceMap.addValue did not return 2 in %s", __PRETTY_FUNCTION__);
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after addValue:@\"two\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after addValue \"two\" in %s", __PRETTY_FUNCTION__);
    
    STAssertEquals([map addValue: @"three"], (SequenceNumber)3, @"TTDSequenceMap.addValue did not return 3 in %s", __PRETTY_FUNCTION__);
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after addValue:@\"three\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after addValue \"two\" in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 2];
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after removeSequnce:2 in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after removeSequnce:2 in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 1];
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)2, @"TDSequenceMap.checkpointedSequence is not 2 after removeSequnce:1 in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, @"two", @"TDSequenceMap.checkpointedValue is not @\"two\" after removeSequnce:1 in %s", __PRETTY_FUNCTION__);
    
    STAssertEquals([map addValue: @"four"], (SequenceNumber)4, @"TTTDSequenceMap.addValue did not return 4 in %s", __PRETTY_FUNCTION__);
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)2, @"TDSequenceMap.checkpointedSequence is not 2 after addValue:@\"four\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, @"two", @"TDSequenceMap.checkpointedValue is not @\"two\" after addValue:@\"four\" in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 3];
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)3, @"TDSequenceMap.checkpointedSequence is not 3 after removeSequnce:3 in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, @"three", @"TDSequenceMap.checkpointedValue is not @\"three\" after removeSequnce:3 in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 4];
    STAssertEquals(map.checkpointedSequence, (SequenceNumber)4, @"TDSequenceMap.checkpointedSequence is not 4 after removeSequnce:4 in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(map.checkpointedValue, @"four", @"TDSequenceMap.checkpointedValue is not @\"four\" after removeSequnce:4 in %s", __PRETTY_FUNCTION__);
    STAssertTrue(map.isEmpty, @"TDSequenceMap.isEmpty is not true in %s", __PRETTY_FUNCTION__);

}


@end
