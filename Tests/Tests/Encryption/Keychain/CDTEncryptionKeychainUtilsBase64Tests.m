//
//  CDTEncryptionKeychainUtilsBase64Tests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 10/04/2015.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "CDTEncryptionKeychainUtils+Base64.h"

@interface CDTEncryptionKeychainUtilsBase64Tests : XCTestCase

@end

@implementation CDTEncryptionKeychainUtilsBase64Tests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.

    [super tearDown];
}

- (void)testBase64StringFromData
{
    NSString *txt = @"1234567890";
    NSString *expectedResult = @"MTIzNDU2Nzg5MA==";
    NSString *result = [CDTEncryptionKeychainUtils
        base64StringFromData:[txt dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"a1s2d3f4g5";
    expectedResult = @"YTFzMmQzZjRnNQ==";
    result = [CDTEncryptionKeychainUtils
        base64StringFromData:[txt dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"摇噺摃䈰婘栰";
    expectedResult = @"5pGH5Zm65pGD5Iiw5amY5qCw";
    result = [CDTEncryptionKeychainUtils
        base64StringFromData:[txt dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"摇;摃:§婘栰";
    expectedResult = @"5pGHO+aRgzrCp+WpmOagsA==";
    result = [CDTEncryptionKeychainUtils
        base64StringFromData:[txt dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"摇;摃:xx👹⌚️👽";
    expectedResult = @"5pGHO+aRgzp4ePCfkbnijJrvuI/wn5G9";
    result = [CDTEncryptionKeychainUtils
        base64StringFromData:[txt dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");
}

- (void)testBase64DataFromString
{
    NSString *txt = @"MTIzNDU2Nzg5MA==";
    NSData *expectedResult = [@"1234567890" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *result = [CDTEncryptionKeychainUtils base64DataFromString:txt];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"YTFzMmQzZjRnNQ==";
    expectedResult = [@"a1s2d3f4g5" dataUsingEncoding:NSUTF8StringEncoding];
    result = [CDTEncryptionKeychainUtils base64DataFromString:txt];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"5pGH5Zm65pGD5Iiw5amY5qCw";
    expectedResult = [@"摇噺摃䈰婘栰" dataUsingEncoding:NSUTF8StringEncoding];
    result = [CDTEncryptionKeychainUtils base64DataFromString:txt];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"5pGHO+aRgzrCp+WpmOagsA==";
    expectedResult = [@"摇;摃:§婘栰" dataUsingEncoding:NSUTF8StringEncoding];
    result = [CDTEncryptionKeychainUtils base64DataFromString:txt];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");

    txt = @"5pGHO+aRgzp4ePCfkbnijJrvuI/wn5G9";
    expectedResult = [@"摇;摃:xx👹⌚️👽" dataUsingEncoding:NSUTF8StringEncoding];
    result = [CDTEncryptionKeychainUtils base64DataFromString:txt];
    XCTAssertEqualObjects(expectedResult, result, @"Unexpected result");
}

- (void)testIsBase64Encoded
{
    XCTAssertTrue([CDTEncryptionKeychainUtils isBase64Encoded:@"MTIzNDU2Nzg5MA=="], @"It's valid");
    XCTAssertTrue([CDTEncryptionKeychainUtils isBase64Encoded:@"YTFzMmQzZjRnNQ=="], @"It's valid");
    XCTAssertTrue([CDTEncryptionKeychainUtils isBase64Encoded:@"5pGH5Zm65pGD5Iiw5amY5qCw"],
                  @"It's valid");
    XCTAssertTrue([CDTEncryptionKeychainUtils isBase64Encoded:@"5pGHO+aRgzrCp+WpmOagsA=="],
                  @"It's valid");
    XCTAssertTrue([CDTEncryptionKeychainUtils isBase64Encoded:@"5pGHO+aRgzp4ePCfkbnijJrvuI/wn5G9"],
                  @"It's valid");

    XCTAssertFalse([CDTEncryptionKeychainUtils isBase64Encoded:@"MTIzNDU2Nzg5MA== "],
                   @"It's not valid");
    XCTAssertFalse([CDTEncryptionKeychainUtils isBase64Encoded:@"YTFzMmQzZjRnNQ==婘"],
                   @"It's not valid");
    XCTAssertFalse([CDTEncryptionKeychainUtils isBase64Encoded:@"5pGH5Zm65pGD5Iiw5amY5qCw👽"],
                   @"It's not valid");
    XCTAssertFalse([CDTEncryptionKeychainUtils isBase64Encoded:@"5pGHO+aRgzrCp+WpmOagsA=={}"],
                   @"It's not valid");
    XCTAssertFalse(
        [CDTEncryptionKeychainUtils isBase64Encoded:@"5pGHO+aRgzp4ePCfkbnijJrvuI/wn5G9£"],
        @"It's not valid");
}

@end
