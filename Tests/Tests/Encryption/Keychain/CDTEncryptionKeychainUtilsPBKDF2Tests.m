//
//  CDTEncryptionKeychainUtilsPBKDF2Tests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 14/04/2015.
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

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>


#import "CDTEncryptionKeychainUtils+PBKDF2.h"

@interface CDTEncryptionKeychainUtilsPBKDF2Tests : XCTestCase

@end

@implementation CDTEncryptionKeychainUtilsPBKDF2Tests

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

- (void)testDerivePassword
{
    NSData *salt = [@"82bccddd8c04801730d9b5e64669084528a41b258307ef8af7e888da068f5d81"
        dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger iterations = 10000;
    NSUInteger length = 32;

    NSString *password = @"1234567890";
    NSString *expectedKey = @"8a31ebb7f764568bc232affb234b59cd474570c7c9ac66e2181d030039b5f2b4";
    NSData *keyData = [CDTEncryptionKeychainUtils derivePassword:password
                                                        withSalt:salt
                                                      iterations:iterations
                                                          length:length];
    NSString *keyStr =
        [CDTEncryptionKeychainUtilsPBKDF2Tests hexadecimalRepresentationForData:keyData];
    XCTAssertEqualObjects(expectedKey, keyStr, @"Unexpected result");

    password = @"a1s2d3f4g5";
    expectedKey = @"729286b865fefc64b5c17ab4028a5cb9fbc523cdbd439b5392346f4da68de74d";
    keyData = [CDTEncryptionKeychainUtils derivePassword:password
                                                withSalt:salt
                                              iterations:iterations
                                                  length:length];
    keyStr = [CDTEncryptionKeychainUtilsPBKDF2Tests hexadecimalRepresentationForData:keyData];
    XCTAssertEqualObjects(expectedKey, keyStr, @"Unexpected result");

    password = @"摇噺摃䈰婘栰";
    expectedKey = @"f4214e594b13c12f4e3798cc381ed90881e14a850980bec542741ebde0b71da0";
    keyData = [CDTEncryptionKeychainUtils derivePassword:password
                                                withSalt:salt
                                              iterations:iterations
                                                  length:length];
    keyStr = [CDTEncryptionKeychainUtilsPBKDF2Tests hexadecimalRepresentationForData:keyData];
    XCTAssertEqualObjects(expectedKey, keyStr, @"Unexpected result");

    password = @"摇;摃:§婘栰";
    expectedKey = @"b4a682fa7726620a7ca406fda3e88a32670415feb3952f7ee6168ce8fe533106";
    keyData = [CDTEncryptionKeychainUtils derivePassword:password
                                                withSalt:salt
                                              iterations:iterations
                                                  length:length];
    keyStr = [CDTEncryptionKeychainUtilsPBKDF2Tests hexadecimalRepresentationForData:keyData];
    XCTAssertEqualObjects(expectedKey, keyStr, @"Unexpected result");

    password = @"摇;摃:xx👹⌚️👽";
    expectedKey = @"a9794574f968fc006cc81c9918bbc8c560d73bef0c9fc409f608b279146ec0c2";
    keyData = [CDTEncryptionKeychainUtils derivePassword:password
                                                withSalt:salt
                                              iterations:iterations
                                                  length:length];
    keyStr = [CDTEncryptionKeychainUtilsPBKDF2Tests hexadecimalRepresentationForData:keyData];
    XCTAssertEqualObjects(expectedKey, keyStr, @"Unexpected result");
}

#pragma mark - Private class methods
+ (NSString *)hexadecimalRepresentationForData:(NSData *)data
{
    NSUInteger dataLength = data.length;
    const unsigned char *dataBytes = data.bytes;

    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (NSUInteger idx = 0; idx < dataLength; idx++) {
        [hexString appendFormat:@"%02x", dataBytes[idx]];
    }

    return [NSString stringWithString:hexString];
}

@end
