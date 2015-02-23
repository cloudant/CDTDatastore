//
//  TDReachabilityTests.m
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
#import "TDReachability.h"
#import "CloudantTests.h"


@interface TDReachabilityTests : CloudantTests


@end

@implementation TDReachabilityTests

- (void) runReachability:(NSString*) hostname
{
//    NSLog(@"Test reachability of %@ ...", hostname);
    TDReachability* r = [[TDReachability alloc] initWithHostName: hostname];
    XCTAssertNotNil(r, @"TDReachbility instance is nil in %s:%@", __PRETTY_FUNCTION__, hostname);
//    NSLog(@"TDReachability = %@", r);
    XCTAssertEqualObjects(r.hostName, hostname, @"TDReachbility instance hostname (%@) is not %@ in %s:%@", r.hostName, hostname, __PRETTY_FUNCTION__, hostname);
    __block BOOL resolved = NO;
    
    __weak TDReachability *weakR = r;
    r.onChange = ^{
        TDReachability *strongR = weakR;
//        NSLog(@"onChange: known=%d, flags=%x --> reachable=%d",
//            strongR.reachabilityKnown, strongR.reachabilityFlags, strongR.reachable);
//        NSLog(@"TDReachability = %@", strongR);
        if (strongR.reachabilityKnown)
            resolved = YES;
    };
    XCTAssertTrue([r start], @"TDReachability failed to start in %s:%@", __PRETTY_FUNCTION__, hostname);
    
    BOOL known = r.reachabilityKnown;
//    NSLog(@"Initially: known=%d, flags=%x --> reachable=%d", known, r.reachabilityFlags, r.reachable);
    if (!known) {
        while (!resolved) {
//            NSLog(@"waiting...");
            [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
        }
    }
    [r stop];
//    NSLog(@"...done!");
}

- (void)testReachability
{
    [self runReachability:@"cloudant.com"];
    [self runReachability:@"localhost"];
    [self runReachability:@"127.0.0.1"];
    [self runReachability:@"couchbase.com"];  // couchbase.com
    [self runReachability:@"fsdfsaf.fsdfdaf.fsfddf"];
}


@end
