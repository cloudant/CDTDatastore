//
//  TDCanonicalJSONTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TDCanonicalJSON.h"


@interface TDCanonicalJSONTests : SenTestCase


@end

@implementation TDCanonicalJSONTests

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

- (void)roundtrip:(id) obj
{
    NSData* json = [TDCanonicalJSON canonicalData: obj];
    NSLog(@"%@ --> `%@`", [obj description], [json my_UTF8ToString]);
    NSError* error;
    id reconstituted = [NSJSONSerialization JSONObjectWithData: json options:NSJSONReadingAllowFragments error: &error];
    STAssertNotNil(reconstituted, @"Canonical JSON `%@` was unparseable: %@",
            [json my_UTF8ToString], error);
    STAssertEqualObjects(reconstituted, obj, @"Canonical JSON object and reconstructed objec were not equal in %s", __PRETTY_FUNCTION__);
}

- (void)roundtripFloat:(double) n
{
    NSData* json = [TDCanonicalJSON canonicalData: @(n)];
    NSError* error;
    id reconstituted = [NSJSONSerialization JSONObjectWithData: json options:NSJSONReadingAllowFragments error: &error];
    STAssertNotNil(reconstituted, @"`%@` was unparseable: %@",
            [json my_UTF8ToString], error);
    double delta = [reconstituted doubleValue] / n - 1.0;
    NSLog(@"%g --> `%@` (error = %g)", n, [json my_UTF8ToString], delta);
    STAssertTrue(fabs(delta) < 1.0e-15, @"`%@` had floating point roundoff error of %g (%g vs %g)",
            [json my_UTF8ToString], delta, [reconstituted doubleValue], n);
}

- (void)testEncoding
{
    STAssertEqualObjects([TDCanonicalJSON canonicalString: $true], @"true", @"Canonical JSON $true is not \"true\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects([TDCanonicalJSON canonicalString: $false], @"false", @"Canonical JSON $false is not \"false\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects([TDCanonicalJSON canonicalString: $null], @"null", @"Canonical JSON $null is not \"null\" in %s", __PRETTY_FUNCTION__);
}

- (void)testReconstruction
{
    [self roundtrip:$true];
    [self roundtrip:$false];
    [self roundtrip:$null];
    
    [self roundtrip:@0];
    [self roundtrip:@INT_MAX];
    [self roundtrip:@INT_MIN];
    [self roundtrip:@UINT_MAX];
    [self roundtrip:@INT64_MAX];
    [self roundtrip:@UINT64_MAX];
    
    [self roundtripFloat:111111.111111];
    [self roundtripFloat:M_PI];
    [self roundtripFloat:6.02e23];
    [self roundtripFloat:1.23456e-18];
    [self roundtripFloat:1.0e-37];
    [self roundtripFloat:UINT_MAX];
    [self roundtripFloat:UINT64_MAX];
    [self roundtripFloat:UINT_MAX + 0.01];
    [self roundtripFloat:1.0e38];
    
    [self roundtrip:@""];
    [self roundtrip:@"ordinary string"];
    [self roundtrip:@"\\"];
    [self roundtrip:@"xx\\"];
    [self roundtrip:@"\\xx"];
    [self roundtrip:@"\"\\"];
    [self roundtrip:@"\\.\""];
    [self roundtrip:@"...\\.\"..."];
    [self roundtrip:@"...\\..\"..."];
    [self roundtrip:@"\r\nHELO\r \tTHER"];
    [self roundtrip:@"\037wow\037"];
    [self roundtrip:@"\001"];
    [self roundtrip:@"\u1234"];
    
    [self roundtrip:@[]];
    [self roundtrip:@[@[]]];
    [self roundtrip:@[@"foo", @"bar", $null]];
    
    [self roundtrip:@{}];
    [self roundtrip:@{@"key": @"value"}];
    [self roundtrip:@{@"\"key\"": $false}];
    [self roundtrip:@{@"\"key\"": $false, @"": @{}}];
}

@end
