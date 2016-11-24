//
//  CDTEncryptionKeychainManagerTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 15/04/2015.
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

#import <CommonCrypto/CommonCryptor.h>
#import "CDTEncryptionKeychainConstants.h"
#import "CDTEncryptionKeychainManager+Internal.h"
#import "CDTEncryptionKeychainUtils.h"

// NOTE: There is no need for a stronger password given that the following tests check the
// behaviour of CDTEncryptionKeychainManager, not its encryption capabilities (which is tested in
// 'CDTEncryptionKeychainUtilsAESTests.m' and 'CDTEncryptionKeychainUtilsPBKDF2Tests.m')
#define CDTENCRYPTIONKEYCHAINMANAGERTESTS_PASSWORD_DEFAULT @"password"

@interface CDTEncryptionKeychainManagerTests : XCTestCase

@property (strong, nonatomic) CDTEncryptionKeychainManager *manager;

@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) CDTEncryptionKeychainData *keychainData;
@property (strong, nonatomic) id mockStorage;

@end

@implementation CDTEncryptionKeychainManagerTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    id oneStorage = OCMClassMock([CDTEncryptionKeychainStorage class]);
    CDTEncryptionKeychainManager *oneManager = [[CDTEncryptionKeychainManager alloc]
        initWithStorage:(CDTEncryptionKeychainStorage *)oneStorage];
    NSData *oneDpk = [oneManager generateDpk];

    self.password = CDTENCRYPTIONKEYCHAINMANAGERTESTS_PASSWORD_DEFAULT;
    self.keychainData =
        [oneManager keychainDataToStoreDpk:oneDpk encryptedWithPassword:self.password];

    // Create mockStorage as a strict mock. A strick mock will raise an exception if one of its
    // methods is called and it was not set as expected with 'OCMExpect'. Therefore, for each test
    // we have to specify which methods we expect to be executed (we call this our expectations)
    self.mockStorage = OCMStrictClassMock([CDTEncryptionKeychainStorage class]);
    // Also, tests will pass only if the calls are made in the expected order
    [self.mockStorage setExpectationOrderMatters:YES];

    self.manager = [[CDTEncryptionKeychainManager alloc]
        initWithStorage:(CDTEncryptionKeychainStorage *)self.mockStorage];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.password = nil;
    self.keychainData = nil;
    self.mockStorage = nil;
    self.manager = nil;

    [super tearDown];
}

- (void)testInitWithStorageNilFails
{
    XCTAssertNil([[CDTEncryptionKeychainManager alloc] initWithStorage:nil],
                 @"A storage is mandatory");
}

- (void)testClearKeyDelegatesToStorage
{
    // Set expectation
    OCMExpect([self.mockStorage clearEncryptionKeyData]);

    [self.manager clearKey];

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testKeyExistsDelegatesToStorage
{
    // Set expectation
    OCMExpect([self.mockStorage encryptionKeyDataExists]);

    [self.manager keyExists];

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testLoadKeyUsingPasswordFailsIfThereIsNotData
{
    // Set expectation. Also set the return value to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyData]).andReturn(nil);

    XCTAssertNil([self.manager loadKeyUsingPassword:self.password],
                 @"No key to return if there is no data in the keychain");

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testLoadKeyUsingPasswordDoesNotFailIfNumberOfIterationsIsNotAsExpected
{
    id otherStorage = OCMClassMock([CDTEncryptionKeychainStorage class]);

    CDTEncryptionKeychainManager *otherManager = [[CDTEncryptionKeychainManager alloc]
        initWithStorage:(CDTEncryptionKeychainStorage *)otherStorage];
    NSData *otherDpk = [otherManager generateDpk];
    NSData *otherKey =
        [otherManager pbkdf2DerivedKeyForPassword:self.password
                                             salt:self.keychainData.salt
                                       iterations:1
                                           length:CDTENCRYPTION_KEYCHAIN_AES_KEY_SIZE];

    NSData *otherEncryptedDpk =
        [otherManager encryptDpk:otherDpk usingAESWithKey:otherKey iv:self.keychainData.iv];

    CDTEncryptionKeychainData *otherData =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:otherEncryptedDpk
                                                   salt:self.keychainData.salt
                                                     iv:self.keychainData.iv
                                             iterations:1
                                                version:self.keychainData.version];

    // Set expectation. Also set the return value to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyData]).andReturn(otherData);

    XCTAssertNotNil([self.manager loadKeyUsingPassword:self.password],
                    @"Iterations does not have to be equal to %li",
                    (long)CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS);

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testLoadKeyUsingPasswordFailsIfIVDoesNotHaveTheRightSize
{
    CDTEncryptionKeychainData *otherData = [CDTEncryptionKeychainData
        dataWithEncryptedDPK:self.keychainData.encryptedDPK
                        salt:self.keychainData.salt
                          iv:[CDTEncryptionKeychainUtils
                                 generateSecureRandomBytesWithLength:(kCCBlockSizeAES128 + 1)]
                  iterations:self.keychainData.iterations
                     version:self.keychainData.version];

    // Set expectation. Also set the return value to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyData]).andReturn(otherData);

    XCTAssertNil([self.manager loadKeyUsingPassword:self.password], @"IV size must be equalt to %i",
                 kCCBlockSizeAES128);

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testLoadKeyUsingPasswordRaisesExceptionIfNoPassIsProvided
{
    // Set expectation. Also set the return value to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyData]).andReturn(self.keychainData);

    XCTAssertThrows([self.manager loadKeyUsingPassword:nil],
                    @"A password is neccesary to decipher the key");

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testLoadKeyUsingPasswordPerformsTheExpectedSteps
{
    // Create a partial mock based on self.manager. A partial mock is build with an instance,
    // instead of being build with a class definition; this allows me to set expectations on the
    // partial mock (the methods I expect will be executed) and then forward the message to the
    // original instance
    id partialMockManager = OCMPartialMock(self.manager);
    // Also, test will pass only if the calls are made in the expected order
    [partialMockManager setExpectationOrderMatters:YES];

    // Set the expectations in the right order.
    // Notice that the call will be forwarded to the real object, we want to track the workflow
    // of this class, not to interrupt it.
    OCMExpect([partialMockManager validateEncryptionKeyData:OCMOCK_ANY]).andForwardToRealObject();
    OCMExpect([[partialMockManager ignoringNonObjectArgs] pbkdf2DerivedKeyForPassword:OCMOCK_ANY
                                                                                 salt:OCMOCK_ANY
                                                                           iterations:0
                                                                               length:0])
        .andForwardToRealObject();
    OCMExpect([partialMockManager decryptDpk:OCMOCK_ANY usingAESWithKey:OCMOCK_ANY iv:OCMOCK_ANY])
        .andForwardToRealObject();

    OCMExpect([self.mockStorage encryptionKeyData]).andReturn(self.keychainData);

    [partialMockManager loadKeyUsingPassword:self.password];

    // Verify that the expected methods are executed in the right order for both objects
    OCMVerifyAll(self.mockStorage);
    OCMVerifyAll(partialMockManager);
}

- (void)testGenerateAndSaveKeyProtectedByPasswordRaisesExceptionIfNoPassIsProvided
{
    // Set expectation. Also set the return value to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyDataExists]).andReturn(NO);

    XCTAssertThrows([self.manager generateAndSaveKeyProtectedByPassword:nil],
                    @"A password is neccesary to cipher the key");

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testGenerateAndSaveKeyProtectedByPasswordFailsIfEncryptionDataWasAlreadyGenerated
{
    // Set expectation. Also set the return value to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyDataExists]).andReturn(YES);

    XCTAssertNil([self.manager generateAndSaveKeyProtectedByPassword:self.password],
                 @"No key should be generated if there is one already");

    // Verify that the expected method was executed, also it was the only method executed
    OCMVerifyAll(self.mockStorage);
}

- (void)testGenerateAndSaveKeyProtectedByPasswordFailsIfKeyIsNotSaved
{
    // Set expectations. Also set the return values to test the next Assert
    OCMExpect([self.mockStorage encryptionKeyDataExists]).andReturn(NO);
    OCMExpect([self.mockStorage saveEncryptionKeyData:OCMOCK_ANY]).andReturn(NO);

    XCTAssertNil([self.manager generateAndSaveKeyProtectedByPassword:self.password],
                 @"No key must be returned if it is not saved to the keychain");

    // Verify that only the expected methods were executed and they were run in the right order
    OCMVerifyAll(self.mockStorage);
}

- (void)testGenerateAndSaveKeyProtectedByPasswordPerformsExpectedHighlevelSteps
{
    // Create a partial mock based on self.manager. A partial mock is build with an instance,
    // instead of being build with a class definition; this allows me to set expectations on the
    // partial mock (the methods I expect will be executed) and then forward the message to the
    // original instance
    id partialMockManager = OCMPartialMock(self.manager);
    // Also, test will pass only if the calls are made in the expected order
    [partialMockManager setExpectationOrderMatters:YES];

    // Set the expectations in the right order.
    // Notice that the call will be forwarded to the real object, we want to track the workflow
    // of this class, not to interrupt it.
    OCMExpect([partialMockManager keyExists]).andForwardToRealObject();
    OCMExpect([partialMockManager generateDpk]).andForwardToRealObject();
    OCMExpect(
        [partialMockManager keychainDataToStoreDpk:OCMOCK_ANY encryptedWithPassword:OCMOCK_ANY])
        .andForwardToRealObject();

    OCMExpect([self.mockStorage encryptionKeyDataExists]).andReturn(NO);
    OCMExpect([self.mockStorage saveEncryptionKeyData:OCMOCK_ANY]).andReturn(YES);

    [partialMockManager generateAndSaveKeyProtectedByPassword:self.password];

    // Verify that the expected methods are executed in the right order for both objects
    OCMVerifyAll(self.mockStorage);
    OCMVerifyAll(partialMockManager);
}

- (void)testKeychainDataToStoreDpkPerformsExpectedHighlevelSteps
{
    // Create a partial mock based on self.manager. A partial mock is build with an instance,
    // instead of being build with a class definition; this allows me to set expectations on the
    // partial mock (the methods I expect will be executed) and then forward the message to the
    // original instance
    // In this case, we do not enforce a order: it is perfectly fine to generate the IV before
    // all the rest, etc.
    id partialMockManager = OCMPartialMock(self.manager);

    // Set the expectations in the right order.
    // Notice that the call will be forwarded to the real object, we want to track the workflow
    // of this class, not to interrupt it.
    OCMExpect([partialMockManager generatePBKDF2Salt]).andForwardToRealObject();
    OCMExpect([[partialMockManager ignoringNonObjectArgs] pbkdf2DerivedKeyForPassword:OCMOCK_ANY
                                                                                 salt:OCMOCK_ANY
                                                                           iterations:0
                                                                               length:0])
        .andForwardToRealObject();
    OCMExpect([partialMockManager generateAESIv]).andForwardToRealObject();
    OCMExpect([partialMockManager encryptDpk:OCMOCK_ANY usingAESWithKey:OCMOCK_ANY iv:OCMOCK_ANY])
        .andForwardToRealObject();

    NSData *dpk =
        [CDTEncryptionKeychainUtils generateSecureRandomBytesWithLength:CDTENCRYPTIONKEY_KEYSIZE];
    [partialMockManager keychainDataToStoreDpk:dpk encryptedWithPassword:self.password];

    // Verify that the expected methods are executed in the right order
    OCMVerifyAll(partialMockManager);
}

@end
