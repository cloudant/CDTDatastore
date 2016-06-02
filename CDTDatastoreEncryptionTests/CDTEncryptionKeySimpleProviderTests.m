//
//  CDTEncryptionKeySimpleProviderTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 26/05/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>

#import "CDTEncryptionKeySimpleProvider.h"

@interface CDTEncryptionKeySimpleProviderTests : XCTestCase

@end

@implementation CDTEncryptionKeySimpleProviderTests

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

- (void)testInitWithNilFails
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([[CDTEncryptionKeySimpleProvider alloc] initWithKey:nil], @"Data is mandatory");
#pragma clang diagnostic pop
}

- (void)testInitWithWrongDataLength
{
    char buffer[2 * CDTENCRYPTIONKEY_KEYSIZE];
    memset(buffer, '*', sizeof(buffer));

    NSData *data = [NSData dataWithBytes:buffer length:sizeof(buffer)];

    XCTAssertNil([[CDTEncryptionKeySimpleProvider alloc] initWithKey:data],
                 @"Data length has to be %i", CDTENCRYPTIONKEY_KEYSIZE);
}

- (void)testEncryptionKeyReturnsExpectedData
{
    char buffer[CDTENCRYPTIONKEY_KEYSIZE];
    memset(buffer, '*', sizeof(buffer));

    NSData *data = [NSData dataWithBytes:buffer length:sizeof(buffer)];

    CDTEncryptionKeySimpleProvider *provider =
        [[CDTEncryptionKeySimpleProvider alloc] initWithKey:data];

    XCTAssertEqualObjects(data, [[provider encryptionKey] data], @"Unexpected result");
}

@end
