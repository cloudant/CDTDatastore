//
//  CDTEncryptionKeychainUtilsAESTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 10/04/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <XCTest/XCTest.h>

#import "CDTEncryptionKeychainUtils+AES.h"

#import "CDTMisc.h"

#import "TDBase64.h"

@interface CDTEncryptionKeychainUtilsAESTests : XCTestCase

@property (strong, nonatomic) NSData *key;
@property (strong, nonatomic) NSData *iv;

@end

@implementation CDTEncryptionKeychainUtilsAESTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    NSString *keyStr = @"3271b0b2ae09cf10128893abba0871b64ea933253378d0c65bcbe05befe636c3";
    NSString *ivStr = @"10327cc29f13539f8ce5378318f46137";

    self.key = dataFromHexadecimalString(keyStr);
    self.iv = dataFromHexadecimalString(ivStr);
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.key = nil;
    self.iv = nil;

    [super tearDown];
}

- (void)testDoEncrypt
{
    NSString *plainText = @"1234567890";
    NSString *expectedCiphertext = @"ExUL75zXTBiQKHAqYeR3Glt+EXMR25qmNTdeToHdA40=";
    NSData *data =
        [CDTEncryptionKeychainUtils doEncrypt:[plainText dataUsingEncoding:NSUnicodeStringEncoding]
                                      withKey:self.key
                                           iv:self.iv];
    NSString *result = [TDBase64 encode:data];
    XCTAssertEqualObjects(expectedCiphertext, result, @"Unexpected result");

    plainText = @"a1s2d3f4g5";
    expectedCiphertext = @"jEcy1ZxPXMJ9aX2kzHVX5eaWtMAJZQhPrfgLadcAKus=";
    data =
        [CDTEncryptionKeychainUtils doEncrypt:[plainText dataUsingEncoding:NSUnicodeStringEncoding]
                                      withKey:self.key
                                           iv:self.iv];
    result = [TDBase64 encode:data];
    XCTAssertEqualObjects(expectedCiphertext, result, @"Unexpected result");

    plainText = @"摇噺摃䈰婘栰";
    expectedCiphertext = @"Wfip2t2sH9ojHHsEN7B6Uw==";
    data =
        [CDTEncryptionKeychainUtils doEncrypt:[plainText dataUsingEncoding:NSUnicodeStringEncoding]
                                      withKey:self.key
                                           iv:self.iv];
    result = [TDBase64 encode:data];
    XCTAssertEqualObjects(expectedCiphertext, result, @"Unexpected result");

    plainText = @"摇;摃:§婘栰";
    expectedCiphertext = @"+B/AXr0PQrxQSAdMnE8BKKUymEak2akCuGGHIY99lNU=";
    data =
        [CDTEncryptionKeychainUtils doEncrypt:[plainText dataUsingEncoding:NSUnicodeStringEncoding]
                                      withKey:self.key
                                           iv:self.iv];
    result = [TDBase64 encode:data];
    XCTAssertEqualObjects(expectedCiphertext, result, @"Unexpected result");

    plainText = @"摇;摃:xx👹⌚️👽";
    expectedCiphertext = @"H6nWVwfuGB8hDv/dFVUXbU2yb07NzE2vf3HttPF/qps=";
    data =
        [CDTEncryptionKeychainUtils doEncrypt:[plainText dataUsingEncoding:NSUnicodeStringEncoding]
                                      withKey:self.key
                                           iv:self.iv];
    result = [TDBase64 encode:data];
    XCTAssertEqualObjects(expectedCiphertext, result, @"Unexpected result");
}

- (void)testDoDecrypt
{
    NSString *cipherTxt = @"ExUL75zXTBiQKHAqYeR3Glt+EXMR25qmNTdeToHdA40=";
    NSString *expectedPlainText = @"1234567890";
    NSData *data = [CDTEncryptionKeychainUtils doDecrypt:[TDBase64 decode:cipherTxt]
                                                 withKey:self.key
                                                      iv:self.iv];
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
    XCTAssertEqualObjects(expectedPlainText, result, @"Unexpected result");

    cipherTxt = @"jEcy1ZxPXMJ9aX2kzHVX5eaWtMAJZQhPrfgLadcAKus=";
    expectedPlainText = @"a1s2d3f4g5";
    data = [CDTEncryptionKeychainUtils doDecrypt:[TDBase64 decode:cipherTxt]
                                         withKey:self.key
                                              iv:self.iv];
    result = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
    XCTAssertEqualObjects(expectedPlainText, result, @"Unexpected result");

    cipherTxt = @"Wfip2t2sH9ojHHsEN7B6Uw==";
    expectedPlainText = @"摇噺摃䈰婘栰";
    data = [CDTEncryptionKeychainUtils doDecrypt:[TDBase64 decode:cipherTxt]
                                         withKey:self.key
                                              iv:self.iv];
    result = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
    XCTAssertEqualObjects(expectedPlainText, result, @"Unexpected result");

    cipherTxt = @"+B/AXr0PQrxQSAdMnE8BKKUymEak2akCuGGHIY99lNU=";
    expectedPlainText = @"摇;摃:§婘栰";
    data = [CDTEncryptionKeychainUtils doDecrypt:[TDBase64 decode:cipherTxt]
                                         withKey:self.key
                                              iv:self.iv];
    result = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
    XCTAssertEqualObjects(expectedPlainText, result, @"Unexpected result");

    cipherTxt = @"H6nWVwfuGB8hDv/dFVUXbU2yb07NzE2vf3HttPF/qps=";
    expectedPlainText = @"摇;摃:xx👹⌚️👽";
    data = [CDTEncryptionKeychainUtils doDecrypt:[TDBase64 decode:cipherTxt]
                                         withKey:self.key
                                              iv:self.iv];
    result = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
    XCTAssertEqualObjects(expectedPlainText, result, @"Unexpected result");
}

@end
