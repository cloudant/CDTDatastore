//
//  TDReachabilityTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TDReachability.h"


@interface TDReachabilityTests : SenTestCase


@end

@implementation TDReachabilityTests

- (void) runReachability:(NSString*) hostname
{
    NSLog(@"Test reachability of %@ ...", hostname);
    TDReachability* r = [[TDReachability alloc] initWithHostName: hostname];
    STAssertNotNil(r, @"TDReachbility instance is nil in %s:@%", __PRETTY_FUNCTION__, hostname);
    NSLog(@"TDReachability = %@", r);
    STAssertEqualObjects(r.hostName, hostname, @"TDReachbility instance hostname (@%) is not %@ in %s:@%", r.hostName, hostname, __PRETTY_FUNCTION__, hostname);
    __block BOOL resolved = NO;
    
    __weak TDReachability *weakR = r;
    r.onChange = ^{
        TDReachability *strongR = weakR;
        NSLog(@"onChange: known=%d, flags=%x --> reachable=%d",
            strongR.reachabilityKnown, strongR.reachabilityFlags, strongR.reachable);
        NSLog(@"TDReachability = %@", strongR);
        if (strongR.reachabilityKnown)
            resolved = YES;
    };
    STAssertTrue([r start], @"TDReachability failed to start in %s:@%", __PRETTY_FUNCTION__, hostname);
    
    BOOL known = r.reachabilityKnown;
    NSLog(@"Initially: known=%d, flags=%x --> reachable=%d", known, r.reachabilityFlags, r.reachable);
    if (!known) {
        while (!resolved) {
            NSLog(@"waiting...");
            [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
        }
    }
    [r stop];
    NSLog(@"...done!");
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
