//
//  TDMiscTests.m
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
#import "TDMisc.h"
#import "CloudantTests.h"

@interface TDMiscTests : CloudantTests


@end

@implementation TDMiscTests

- (void)quoteStringTest:(NSString *)str1 str2:(NSString *)str2
{
    XCTAssertEqualObjects(TDQuoteString(str1), str2, @"TDQuoteString test failed for str1:%@ and str2:%@ in %s", str1, str2, __PRETTY_FUNCTION__);
}

- (void)unquoteStringTest:(NSString *)str1 str2:(NSString *)str2
{
    XCTAssertEqualObjects(TDUnquoteString(str1), str2, @"TDUnquoteString test failed for str1:%@ and str2:%@ in %s", str1, str2,__PRETTY_FUNCTION__);
}

- (void)escapeIDTest:(NSString *)str1 str2:(NSString *)str2
{
    XCTAssertEqualObjects(TDEscapeID(str1), str2, @"TDEscapeID test failed for str1:%@ and str2:%@ in %s", str1, str2, __PRETTY_FUNCTION__);
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

-(void)testCleanURL
{
    NSString *cleanString;
    NSURL *testUrl;
    
    //these should create a cleaned URL.
    testUrl = [NSURL URLWithString: @"https://adam:adamspassword@myhost.com:1234/db?all_docs=true"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam:*****@myhost.com:1234/db?all_docs=true",
                          @"not cleaned: %@", cleanString);
    
    testUrl = [NSURL URLWithString:
               @"https://adam:adamspassword@myhost.com:1234/db/with/long/path.html?q=true"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam:*****@myhost.com:1234/db/with/long/path.html?q=true",
                          @"not cleaned: %@", cleanString);
    
    testUrl = [NSURL URLWithString:
               @"https://adam:adamspassword@myhost.com:1234/db/with/long/path.html?q=true&foo=bar&bam=baz"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString,
                          @"https://adam:*****@myhost.com:1234/db/with/long/path.html?q=true&foo=bar&bam=baz",
                          @"not cleaned: %@", cleanString);

    testUrl = [NSURL URLWithString:@"https://adam:adamspassword@myhost.com/db?all_docs=true"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam:*****@myhost.com/db?all_docs=true",
                          @"not cleaned: %@", cleanString);
    
    testUrl = [NSURL URLWithString:@"https://adam:adamspassword@myhost.com/db"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam:*****@myhost.com/db",
                          @"not cleaned: %@", cleanString);
    
    testUrl = [NSURL URLWithString:
               @"https://adam:adamspassword@myhost.com:1234/db?all_docs=true#some_fragment"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString,
                          @"https://adam:*****@myhost.com:1234/db?all_docs=true#some_fragment",
                          @"not cleaned: %@", cleanString);
    
    testUrl = [NSURL URLWithString:@"https://adam@/db"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam@/db", @"should not have changed: %@",
                          cleanString);
    
    testUrl = [NSURL URLWithString:@"https://adam@"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam@", @"should not have changed: %@",
                          cleanString);
    
    testUrl = [NSURL URLWithString:@"https://adam@myhost.com/db"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://adam@myhost.com/db", @"should not have changed: %@",
                          cleanString);
    
    testUrl = [NSURL URLWithString:@"https://nothing.to.clean/db"];
    cleanString = TDCleanURLtoString(testUrl);
    XCTAssertEqualObjects(cleanString, @"https://nothing.to.clean/db", @"should not have changed: %@",
                          cleanString);

    
}

@end
