//
//  CDTEncryptionKeychainProviderTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 21/04/2015.
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

#import <OCMock/OCMock.h>

#import "CDTEncryptionKeychainProvider+Internal.h"

@interface CDTEncryptionKeychainProviderTests : XCTestCase

@property (strong, nonatomic) CDTEncryptionKeychainProvider *provider;

@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSData *encryptionKeyData;
@property (strong, nonatomic) id mockManager;

@end

@implementation CDTEncryptionKeychainProviderTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.password = @"password";

    self.encryptionKeyData = [@"encryptionKeyData" dataUsingEncoding:NSUnicodeStringEncoding];

    // Create mockManager as a strict mock. A strick mock will raise an exception if one of its
    // methods is called and it was not set as expected with 'OCMExpect'. Therefore, for each test
    // we have to specify which methods we expect to be executed (we call this our expectations)
    self.mockManager = OCMStrictClassMock([CDTEncryptionKeychainManager class]);
    // Also, tests will pass only if the calls are made in the expected order
    [self.mockManager setExpectationOrderMatters:YES];

    self.provider = [[CDTEncryptionKeychainProvider alloc]
        initWithPassword:self.password
              forManager:(CDTEncryptionKeychainManager *)self.mockManager];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.mockManager = nil;
    self.encryptionKeyData = nil;
    self.password = nil;

    [super tearDown];
}

- (void)testInitWithoutPasswordFails
{
    XCTAssertNil([[CDTEncryptionKeychainProvider alloc]
                     initWithPassword:nil
                           forManager:(CDTEncryptionKeychainManager *)self.mockManager],
                 @"All parameters in the designated initialiser are mandatory");
}

- (void)testInitWithoutManagerFails
{
    XCTAssertNil(
        [[CDTEncryptionKeychainProvider alloc] initWithPassword:self.password forManager:nil],
        @"All parameters in the designated initialiser are mandatory");
}

- (void)testEncryptionKeyGenerateEncryptionKeyDataIfDataWasNotGeneratedBefore
{
    // Set expectations. Also set the return values to continue the execution
    OCMExpect([self.mockManager keyExists]).andReturn(NO);
    OCMExpect([self.mockManager generateAndSaveKeyProtectedByPassword:OCMOCK_ANY]);

    [self.provider encryptionKey];

    // Verify that only the expected methods were executed and in the right order
    OCMVerifyAll(self.mockManager);
}

- (void)testEncryptionKeyReturnNilIfGenerateEncryptionKeyDataReturnsNil
{
    // Set expectations. Also set the return values to continue the execution and
    // test the next Assert
    OCMExpect([self.mockManager keyExists]).andReturn(NO);
    OCMExpect([self.mockManager generateAndSaveKeyProtectedByPassword:OCMOCK_ANY]).andReturn(nil);

    XCTAssertNil([self.provider encryptionKey],
                 @"If no data is generated, there is not key to return");

    // Verify that only the expected methods were executed and in the right order
    OCMVerifyAll(self.mockManager);
}

- (void)testEncryptionKeyRetrieveEncryptionKeyDataIfDataWasGeneratedBefore
{
    // Set expectations. Also set the return values to continue the execution
    OCMExpect([self.mockManager keyExists]).andReturn(YES);
    OCMExpect([self.mockManager loadKeyUsingPassword:OCMOCK_ANY]);

    [self.provider encryptionKey];

    // Verify that only the expected methods were executed and in the right order
    OCMVerifyAll(self.mockManager);
}

- (void)testEncryptionKeyReturnsNilIfRetrieveEncryptionKeyDataReturnsNil
{
    // Set expectations. Also set the return values to continue the execution and
    // test the next Assert
    OCMExpect([self.mockManager keyExists]).andReturn(YES);
    OCMExpect([self.mockManager loadKeyUsingPassword:OCMOCK_ANY]).andReturn(nil);

    XCTAssertNil([self.provider encryptionKey],
                 @"If no data is retrieved, there is not key to return");

    // Verify that only the expected methods were executed and in the right order
    OCMVerifyAll(self.mockManager);
}

#pragma mark - Private class methods
+ (BOOL)isHexadecimalString:(NSString *)str
{
    if (!str) {
        return NO;
    }

    NSCharacterSet *noHexCharSet =
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
    NSRange noHexRange = [str rangeOfCharacterFromSet:noHexCharSet];
    BOOL isHex = (noHexRange.location == NSNotFound);

    return isHex;
}

@end
