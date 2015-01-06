//
//  TDCanonicalJSONTests.m
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
#import "TDCanonicalJSON.h"
#import "CloudantTests.h"

@interface TDCanonicalJSONTests : CloudantTests


@end

@implementation TDCanonicalJSONTests

- (void)roundtrip:(id) obj
{
    NSData* json = [TDCanonicalJSON canonicalData: obj];
//    NSLog(@"%@ --> `%@`", [obj description], [json my_UTF8ToString]);
    NSError* error;
    id reconstituted = [NSJSONSerialization JSONObjectWithData: json options:NSJSONReadingAllowFragments error: &error];
    XCTAssertNotNil(reconstituted, @"Canonical JSON `%@` was unparseable: %@",
            [json my_UTF8ToString], error);
    XCTAssertEqualObjects(reconstituted, obj, @"Canonical JSON object and reconstructed objec were not equal in %s", __PRETTY_FUNCTION__);
}

- (void)roundtripFloat:(double) n
{
    NSData* json = [TDCanonicalJSON canonicalData: @(n)];
    NSError* error;
    id reconstituted = [NSJSONSerialization JSONObjectWithData: json options:NSJSONReadingAllowFragments error: &error];
    XCTAssertNotNil(reconstituted, @"`%@` was unparseable: %@",
            [json my_UTF8ToString], error);
    double delta = [reconstituted doubleValue] / n - 1.0;
//    NSLog(@"%g --> `%@` (error = %g)", n, [json my_UTF8ToString], delta);
    XCTAssertTrue(fabs(delta) < 1.0e-15, @"`%@` had floating point roundoff error of %g (%g vs %g)",
            [json my_UTF8ToString], delta, [reconstituted doubleValue], n);
}

- (void)testEncoding
{
    XCTAssertEqualObjects([TDCanonicalJSON canonicalString: $true], @"true", @"Canonical JSON $true is not \"true\" in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects([TDCanonicalJSON canonicalString: $false], @"false", @"Canonical JSON $false is not \"false\" in %s", __PRETTY_FUNCTION__);
    XCTAssertEqualObjects([TDCanonicalJSON canonicalString: $null], @"null", @"Canonical JSON $null is not \"null\" in %s", __PRETTY_FUNCTION__);
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
