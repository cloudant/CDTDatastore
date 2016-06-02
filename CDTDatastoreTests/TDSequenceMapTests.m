//
//  TDSequenceMapTests.m
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
#import "TDSequenceMap.h"
#import "CloudantTests.h"


@interface TDSequenceMapTests : CloudantTests


@end

@implementation TDSequenceMapTests

- (void)testSequenceMap
{
    TDSequenceMap *map = [[TDSequenceMap alloc] init];

    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)0,
                   @"TDSequenceMap.checkpointedSequence (%lld), is not 0 in %s",
                   map.checkpointedSequence, __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil in %s", __PRETTY_FUNCTION__);
    XCTAssertTrue(map.isEmpty, @"TDSequenceMap.isEmpty is not true in %s", __PRETTY_FUNCTION__);
    
    XCTAssertEqual([map addValue: @"one"], (SequenceNumber)1, @"TDSequenceMap.addValue did not return 1 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after addValue:@\"one\" in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after addValue \"one\"  in %s", __PRETTY_FUNCTION__);
    XCTAssertTrue(!map.isEmpty, @"TDSequenceMap.isEmpty is true in %s", __PRETTY_FUNCTION__);
    
    XCTAssertEqual([map addValue: @"two"], (SequenceNumber)2, @"TDSequenceMap.addValue did not return 2 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after addValue:@\"two\" in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after addValue \"two\" in %s", __PRETTY_FUNCTION__);
    
    XCTAssertEqual([map addValue: @"three"], (SequenceNumber)3, @"TTDSequenceMap.addValue did not return 3 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after addValue:@\"three\" in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after addValue \"two\" in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 2];
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)0, @"TDSequenceMap.checkpointedSequence is not 0 after removeSequnce:2 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, nil, @"TDSequenceMap.checkpointedValue is not nil after removeSequnce:2 in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 1];
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)2, @"TDSequenceMap.checkpointedSequence is not 2 after removeSequnce:1 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, @"two", @"TDSequenceMap.checkpointedValue is not @\"two\" after removeSequnce:1 in %s", __PRETTY_FUNCTION__);
    
    XCTAssertEqual([map addValue: @"four"], (SequenceNumber)4, @"TTTDSequenceMap.addValue did not return 4 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)2, @"TDSequenceMap.checkpointedSequence is not 2 after addValue:@\"four\" in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, @"two", @"TDSequenceMap.checkpointedValue is not @\"two\" after addValue:@\"four\" in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 3];
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)3, @"TDSequenceMap.checkpointedSequence is not 3 after removeSequnce:3 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, @"three", @"TDSequenceMap.checkpointedValue is not @\"three\" after removeSequnce:3 in %s", __PRETTY_FUNCTION__);
    
    [map removeSequence: 4];
    XCTAssertEqual(map.checkpointedSequence, (SequenceNumber)4, @"TDSequenceMap.checkpointedSequence is not 4 after removeSequnce:4 in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects(map.checkpointedValue, @"four", @"TDSequenceMap.checkpointedValue is not @\"four\" after removeSequnce:4 in %s", __PRETTY_FUNCTION__);
    XCTAssertTrue(map.isEmpty, @"TDSequenceMap.isEmpty is not true in %s", __PRETTY_FUNCTION__);

}


@end
