//
//  TDMiscTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TDMisc.h"


@interface TDMiscTests : SenTestCase


@end

@implementation TDMiscTests

- (void)quoteStringTest:(NSString *)str1 str2:(NSString *)str2
{
    STAssertEqualObjects(TDQuoteString(str1), str2, @"TDQuoteString test failed for str1:%@ and str2:%@ in %s", str1, str2, __PRETTY_FUNCTION__);
}

- (void)unquoteStringTest:(NSString *)str1 str2:(NSString *)str2
{
    STAssertEqualObjects(TDUnquoteString(str1), str2, @"TDUnquoteString test failed for str1:%@ and str2:%@ in %s", str1, str2,__PRETTY_FUNCTION__);
}

- (void)escapeIDTest:(NSString *)str1 str2:(NSString *)str2
{
    STAssertEqualObjects(TDEscapeID(str1), str2, @"TDEscapeID test failed for str1:%@ and str2:%@ in %s", str1, str2, __PRETTY_FUNCTION__);
}


- (void)testTDQuoteString
{
    [self quoteStringTest:@"" str2:@"\"\""];
    [self quoteStringTest:@"foo" str2:@"\"foo\""];
    [self quoteStringTest:@"f\"o\"o" str2:@"\"f\\\"o\\\"o\""];
    [self quoteStringTest:@"\\foo" str2:@"\"\\\\foo\""];
    [self quoteStringTest:@"\"" str2:@"\"\\\"\""];
    [self quoteStringTest:@"" str2:@"\"\""];
}
     
- (void)testTDUnquoteString
{
    [self unquoteStringTest:@"" str2:@""];
    [self unquoteStringTest:@"\"" str2:nil];
    [self unquoteStringTest:@"\"\"" str2:@""];
    [self unquoteStringTest:@"\"foo" str2:nil];
    [self unquoteStringTest:@"foo\"" str2:@"foo\""];
    [self unquoteStringTest:@"foo" str2:@"foo"];
    [self unquoteStringTest:@"\"foo\"" str2:@"foo"];
    [self unquoteStringTest:@"\"f\\\"o\\\"o\"" str2:@"f\"o\"o"];
    [self unquoteStringTest:@"\"\\foo\"" str2:@"foo"];
    [self unquoteStringTest:@"\"\\\\foo\"" str2:@"\\foo"];
    [self unquoteStringTest:@"\"foo\\\"" str2:nil];
}

- (void)testEscapeID
{
    [self escapeIDTest:@"foobar" str2:@"foobar"];
    [self escapeIDTest:@"<script>alert('ARE YOU MY DADDY?')</script>"
                  str2:@"%3Cscript%3Ealert('ARE%20YOU%20MY%20DADDY%3F')%3C%2Fscript%3E"];
    [self escapeIDTest:@"foo/bar" str2:@"foo%2Fbar"];
    [self escapeIDTest:@"foo&bar" str2:@"foo%26bar"];
}


@end
