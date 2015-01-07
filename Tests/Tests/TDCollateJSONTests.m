//
//  TDCollateJSONTests.m
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
#import "TDCollateJSON.h"
#import "TDJSON.h"  //I don't understand how the tests in TDCollateJSON compile without this import
#import "CloudantTests.h"

extern char convertEscape(const char**);


@interface TDCollateJSONTests : CloudantTests


@end

@implementation TDCollateJSONTests

- (const char*)encode:(id) obj
{
    // encodes an object to a C string in JSON format. JSON fragments are allowed.
    NSString* str = [TDJSON stringWithJSONObject: obj
                                         options: TDJSONWritingAllowFragments error: NULL];
    XCTAssertNotNil(str, @"string object is nil in %s", __PRETTY_FUNCTION__);
    return [str UTF8String];
}



- (void)escapeTest:(const char*) source decodeChar:(char)decoded
{
    const char* pos = source;
    XCTAssertEqual(convertEscape(&pos), decoded,
                   @"Decoder characters aren't equal (%c, %c) in %s", convertEscape(&pos), decoded, __PRETTY_FUNCTION__);
    XCTAssertEqual((size_t)pos, (size_t)(source + strlen(source) - 1),
                   @"Decoder character positions aren't equal in %s", __PRETTY_FUNCTION__);
}

- (void)testEscapes
{
    [self escapeTest:"\\\\" decodeChar:'\\'];
    [self escapeTest:"\\t" decodeChar:'\t'];
    [self escapeTest:"\\u0045" decodeChar:'E'];
    [self escapeTest:"\\u0001" decodeChar:1];
    [self escapeTest:"\\u0000" decodeChar:0];
}

- (int)collateLimited:(void *)mode str1:(const void *)str1 str2:(const void *)str2 arrayLimit:(unsigned)arrayLimit
{
    // Be evil and put numeric garbage past the ends of str1 and str2 (see bug #138):
    size_t len1 = strlen(str1), len2 = strlen(str2);
    char buf1[len1 + 3], buf2[len2 + 3];
    strlcpy(buf1, str1, sizeof(buf1));
    strlcat(buf1, "99", sizeof(buf1));
    strlcpy(buf2, str2, sizeof(buf1));
    strlcat(buf2, "88", sizeof(buf1));
    return TDCollateJSONLimited(mode, (int)len1, buf1, (int)len2, buf2, arrayLimit);
}

- (void)scalarTest:(void *)mode str1:(const char *)str1 str2:(const char *)str2 retVal:(int)val
{
    [self scalarTest:mode str1:str1 str2:str2 retVal:val arrayLimit:UINT_MAX];
}

- (void)scalarTest:(void *)mode str1:(const char *)str1 str2:(const char *)str2 retVal:(int)val arrayLimit:(unsigned)arrayLimit
{
    XCTAssertEqual([self collateLimited:mode str1:(const void*)str1 str2:(const void*)str2 arrayLimit:arrayLimit],
                   val,
                   @"with mode:%d and arrayLimit:%d, %s and %s do not collate to %d in %s", *(unsigned*)mode, arrayLimit, str1, str2, val, __PRETTY_FUNCTION__);
    
        //(void*)mode used in these tests are defined in TDCollateJSON.h and may be cast as unsigned integers.
}

- (void)testScalars
{
    //RequireTestCase(TDCollateConvertEscape);
    void* mode = kTDCollateJSON_Unicode;
    [self scalarTest:mode str1:"true" str2:"false" retVal:1];
    [self scalarTest:mode str1:"false" str2: "true" retVal:-1];
    [self scalarTest:mode str1:"null" str2:"17" retVal:-1];
    [self scalarTest:mode str1:"1" str2:"1" retVal:0];
    [self scalarTest:mode str1:"123" str2:"1" retVal:1];
    [self scalarTest:mode str1:"123" str2:"0123.0" retVal:0];
    [self scalarTest:mode str1:"123" str2:"\"123\"" retVal:-1];
    [self scalarTest:mode str1:"\"1234\"" str2:"\"123\"" retVal:1];
    [self scalarTest:mode str1:"\"1234\"" str2:"\"1235\"" retVal:-1];
    [self scalarTest:mode str1:"\"1234\"" str2:"\"1234\"" retVal:0];
    [self scalarTest:mode str1:"\"12\\/34\"" str2:"\"12/34\"" retVal:0];
    [self scalarTest:mode str1:"\"\\/1234\"" str2:"\"/1234\"" retVal:0];
    [self scalarTest:mode str1:"\"1234\\/\"" str2:"\"1234/\"" retVal:0];
#ifndef GNUSTEP     // FIXME: GNUstep doesn't support Unicode collation yet
    [self scalarTest:mode str1:"\"a\"" str2:"\"A\"" retVal:-1];
    [self scalarTest:mode str1:"\"A\"" str2:"\"aa\"" retVal:-1];
    [self scalarTest:mode str1:"\"B\"" str2:"\"aa\"" retVal:1];
#endif
}

- (void)testCollateASCII
{
    //RequireTestCase(TDCollateConvertEscape);
    void* mode = kTDCollateJSON_ASCII;
    [self scalarTest:mode str1:"true" str2:"false" retVal:1];
    [self scalarTest:mode str1:"false" str2:"true" retVal:-1];
    [self scalarTest:mode str1:"null" str2:"17" retVal:-1];
    [self scalarTest:mode str1:"123" str2:"1" retVal:1];
    [self scalarTest:mode str1:"123" str2:"0123.0" retVal:0];
    [self scalarTest:mode str1:"123" str2:"\"123\"" retVal:-1];
    [self scalarTest:mode str1:"\"1234\"" str2:"\"123\"" retVal:1];
    [self scalarTest:mode str1:"\"1234\"" str2:"\"1235\"" retVal:-1];
    [self scalarTest:mode str1:"\"1234\"" str2:"\"1234\"" retVal:0];
    [self scalarTest:mode str1:"\"12\\/34\"" str2:"\"12/34\"" retVal:0];
    [self scalarTest:mode str1:"\"\\/1234\"" str2:"\"/1234\"" retVal:0];
    [self scalarTest:mode str1:"\"1234\\/\"" str2:"\"1234/\"" retVal:0];
    [self scalarTest:mode str1:"\"A\"" str2:"\"a\"" retVal:-1];
    [self scalarTest:mode str1:"\"B\"" str2:"\"a\"" retVal:-1];
}

- (void)testCollateRaw
{
    void* mode = kTDCollateJSON_Raw;
    [self scalarTest:mode str1:"false" str2:"17" retVal:1];
    [self scalarTest:mode str1:"false" str2:"true" retVal:-1];
    [self scalarTest:mode str1:"null" str2:"true" retVal:-1];
    [self scalarTest:mode str1:"[\"A\"]" str2:"\"A\"" retVal:-1];
    [self scalarTest:mode str1:"\"A\"" str2:"\"a\"" retVal:-1];
    [self scalarTest:mode str1:"[\"b\"]" str2:"[\"b\",\"c\",\"a\"]" retVal:-1];
}

- (void)testCollateArrays
{
    void* mode = kTDCollateJSON_Unicode;
    [self scalarTest:mode str1:"[]" str2:"\"foo\"" retVal:1];
    [self scalarTest:mode str1:"[]" str2:"[]" retVal:0];
    [self scalarTest:mode str1:"[true]" str2:"[true]" retVal:0];
    [self scalarTest:mode str1:"[false]" str2:"[null]" retVal:1];
    [self scalarTest:mode str1:"[]" str2:"[null]" retVal:-1];
    [self scalarTest:mode str1:"[123]" str2:"[45]" retVal:1];
    [self scalarTest:mode str1:"[123]" str2:"[45,67]" retVal:1];
    [self scalarTest:mode str1:"[123.4,\"wow\"]" str2:"[123.40,789]" retVal:1];
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"[5,\"wow\"]" retVal:0];
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"1" retVal:1];
    [self scalarTest:mode str1:"1" str2:"[5,\"wow\"]" retVal:-1];
}

- (void)testCollateNestedArrays
{
    void* mode = kTDCollateJSON_Unicode;
    [self scalarTest:mode str1:"[[]]" str2:"[]" retVal:1];
    [self scalarTest:mode str1:"[1,[2,3],4]" str2:"[1,[2,3.1],4,5,6]" retVal:-1];
}

- (void)testCollateUnicodeStrings
{
    // Make sure that TDJSON never creates escape sequences we can't parse.
    // That includes "\unnnn" for non-ASCII chars, and "\t", "\b", etc.
    //RequireTestCase(TDCollateConvertEscape];
    void* mode = kTDCollateJSON_Unicode;
    [self scalarTest:mode str1:[self encode:@"fréd"] str2:[self encode:@"fréd"] retVal:0];
    [self scalarTest:mode str1:[self encode:@"ømø"] str2:[self encode:@"omo"] retVal:1];
    [self scalarTest:mode str1:[self encode:@"\t"] str2:[self encode:@" "] retVal:-1];
    [self scalarTest:mode str1:[self encode:@"\001"] str2:[self encode:@" "] retVal:-1];
}

- (void)testCollateLimited
{
    void* mode = kTDCollateJSON_Unicode;
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"[4,\"wow\"]" retVal:1 arrayLimit:1];
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"[5,\"wow\"]" retVal:0 arrayLimit:1];
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"[5,\"MOM\"]" retVal:0 arrayLimit:1];
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"[5]" retVal:0 arrayLimit:1];
    [self scalarTest:mode str1:"[5,\"wow\"]" str2:"[5,\"MOM\"]" retVal:1 arrayLimit:2];
}


@end
