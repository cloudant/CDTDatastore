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

#import <OCMock/OCMock.h>

#import <XCTest/XCTest.h>

#import "CDTEncryptionKeychainManager+Internal.h"

#import "CDTEncryptionKeychainUtils.h"
#import "CDTEncryptionKeychainConstants.h"

// NOTE: There is no need for a stronger password given that the following tests check the
// behaviour of CDTEncryptionKeychainManager, not its encryption capabilities (which is tested in
// 'CDTEncryptionKeychainUtilsAESTests.m' and 'CDTEncryptionKeychainUtilsPBKDF2Tests.m')
#define CDTENCRYPTIONKEYCHAINMANAGERTESTS_PASSWORD_DEFAULT @"password"

// Constant for 'CDTEncryptionKeychainManager:validateEncryptionKeyData:'
NSString *const kCDTEncryptionKeychainManagerTestsValidateEncryptionKeyData =
    @"kCDTEncryptionKeychainManagerTestsValidateEncryptionKeyData";
// Constant for 'CDTEncryptionKeychainManager:keyExists'
NSString *const kCDTEncryptionKeychainManagerTestsKeyExists =
    @"kCDTEncryptionKeychainManagerTestsKeyExists";
// Constant for 'CDTEncryptionKeychainManager:generateDpk'
NSString *const kCDTEncryptionKeychainManagerTestsGenerateDpk =
    @"kCDTEncryptionKeychainManagerTestsGenerateDpk";
// Constant for 'CDTEncryptionKeychainManager:keychainDataToStoreDpk:encryptedWithPassword:'
NSString *const kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk =
    @"kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk";
// Constant for 'CDTEncryptionKeychainManager:generatePBKDF2Salt'
NSString *const kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt =
    @"kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt";
// Constant for 'CDTEncryptionKeychainManager:pbkdf2DerivedKeyForPassword:salt:iterations:length:'
NSString *const kCDTEncryptionKeychainManagerTestsPBKDF2DerivedKey =
    @"kCDTEncryptionKeychainManagerTestsPBKDF2DerivedKey";
// Constant for 'CDTEncryptionKeychainManager:generateAESIv'
NSString *const kCDTEncryptionKeychainManagerTestsGenerateAESIv =
    @"kCDTEncryptionKeychainManagerTestsGenerateAESIv";
// Constant for 'CDTEncryptionKeychainManager:encryptDpk:usingAESWithKey:iv:'
NSString *const kCDTEncryptionKeychainManagerTestsEncryptDpk =
    @"kCDTEncryptionKeychainManagerTestsEncryptDpk";
// Constant for 'CDTEncryptionKeychainManager:decryptDpk:usingAESWithKey:iv:'
NSString *const kCDTEncryptionKeychainManagerTestsDecryptDpk =
    @"kCDTEncryptionKeychainManagerTestsDecryptDpk";

/**
 CDTEncryptionCustomKeychainManager is a mock class for CDTEncryptionKeychainManager.
 
 It does not add or modify the functionality of its parent class, instead it overrides the methods
 declared in CDTEncryptionKeychainManager+Internal this way:
 - Add to 'lastSteps' the constant related to the current method (check above).
 - Use 'super' to execute the implementation of the method in the parent class.
 
 This allows us to track the behaviour of the parent class when we execute its methods under
 different circunstances.
 */
@interface CDTEncryptionCustomKeychainManager : CDTEncryptionKeychainManager

@property (strong, nonatomic) NSMutableArray *lastSteps;

@end

@interface CDTEncryptionKeychainManagerTests : XCTestCase

@property (strong, nonatomic) CDTEncryptionCustomKeychainManager *manager;

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

    self.mockStorage = OCMClassMock([CDTEncryptionKeychainStorage class]);

    self.manager = [[CDTEncryptionCustomKeychainManager alloc]
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
    [self.manager clearKey];

    OCMVerify([self.mockStorage clearEncryptionKeyData]);
}

- (void)testKeyExistsDelegatesToStorage
{
    [self.manager keyExists];

    OCMVerify([self.mockStorage encryptionKeyDataExists]);
}

- (void)testLoadKeyUsingPasswordFailsIfThereIsNotData
{
    OCMStub([self.mockStorage encryptionKeyData]).andReturn(nil);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(NO);

    XCTAssertNil([self.manager loadKeyUsingPassword:self.password],
                 @"No key to return if there is no data in the keychain");
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

    OCMStub([self.mockStorage encryptionKeyData]).andReturn(otherData);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(YES);

    XCTAssertNotNil([self.manager loadKeyUsingPassword:self.password],
                    @"Iterations does not have to be equal to %li",
                    (long)CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS);
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

    OCMStub([self.mockStorage encryptionKeyData]).andReturn(otherData);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(YES);

    XCTAssertNil([self.manager loadKeyUsingPassword:self.password], @"IV size must be equalt to %i",
                 kCCBlockSizeAES128);
}

- (void)testLoadKeyUsingPasswordRaisesExceptionIfNoPassIsProvided
{
    OCMStub([self.mockStorage encryptionKeyData]).andReturn(self.keychainData);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(YES);

    XCTAssertThrows([self.manager loadKeyUsingPassword:nil],
                    @"A password is neccesary to decipher the key");
}

- (void)testLoadKeyUsingPasswordPerformsTheExpectedSteps
{
    OCMStub([self.mockStorage encryptionKeyData]).andReturn(self.keychainData);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(YES);

    [self.manager loadKeyUsingPassword:self.password];

    NSArray *expectedSteps = @[
        kCDTEncryptionKeychainManagerTestsValidateEncryptionKeyData,
        kCDTEncryptionKeychainManagerTestsPBKDF2DerivedKey,
        kCDTEncryptionKeychainManagerTestsDecryptDpk
    ];

    XCTAssertEqualObjects(expectedSteps, self.manager.lastSteps,
                          @"Method did not behave as expected");
}

- (void)testGenerateAndSaveKeyProtectedByPasswordRaisesExceptionIfNoPassIsProvided
{
    OCMStub([self.mockStorage encryptionKeyData]).andReturn(nil);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(NO);
    OCMStub([self.mockStorage saveEncryptionKeyData:[OCMArg any]]).andReturn(YES);

    XCTAssertThrows([self.manager generateAndSaveKeyProtectedByPassword:nil],
                    @"A password is neccesary to cipher the key");
}

- (void)testGenerateAndSaveKeyProtectedByPasswordFailsIfEncryptionDataWasAlreadyGenerated
{
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(YES);

    XCTAssertNil([self.manager generateAndSaveKeyProtectedByPassword:self.password],
                 @"No key should be generated if there is one already");
}

- (void)testGenerateAndSaveKeyProtectedByPasswordFailsIfKeyIsNotSaved
{
    OCMStub([self.mockStorage encryptionKeyData]).andReturn(nil);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(NO);
    OCMStub([self.mockStorage saveEncryptionKeyData:[OCMArg any]]).andReturn(NO);

    XCTAssertNil([self.manager generateAndSaveKeyProtectedByPassword:self.password],
                 @"No key must be returned if it is not saved to the keychain");
}

- (void)testGenerateAndSaveKeyProtectedByPasswordPerformsExpectedHighlevelSteps
{
    OCMStub([self.mockStorage encryptionKeyData]).andReturn(nil);
    OCMStub([self.mockStorage encryptionKeyDataExists]).andReturn(NO);
    OCMStub([self.mockStorage saveEncryptionKeyData:[OCMArg any]]).andReturn(YES);

    [self.manager generateAndSaveKeyProtectedByPassword:self.password];

    NSArray *expectedSteps = @[
        kCDTEncryptionKeychainManagerTestsKeyExists,
        kCDTEncryptionKeychainManagerTestsGenerateDpk,
        kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk
    ];
    NSArray *highlevelSteps =
        [self.manager.lastSteps subarrayWithRange:NSMakeRange(0, [expectedSteps count])];
    BOOL asExpected = [expectedSteps isEqualToArray:highlevelSteps];

    OCMVerify([self.mockStorage saveEncryptionKeyData:[OCMArg any]]);
    XCTAssertTrue(asExpected, @"Method did not behave as expected. Expected: %@. Performed: %@",
                  expectedSteps, highlevelSteps);
}

- (void)testKeychainDataToStoreDpkPerformsExpectedHighlevelSteps
{
    NSData *dpk =
        [CDTEncryptionKeychainUtils generateSecureRandomBytesWithLength:CDTENCRYPTIONKEY_KEYSIZE];
    [self.manager keychainDataToStoreDpk:dpk encryptedWithPassword:self.password];

    NSSet *expectedSteps =
        [NSSet setWithObjects:kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk,
                              kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt,
                              kCDTEncryptionKeychainManagerTestsPBKDF2DerivedKey,
                              kCDTEncryptionKeychainManagerTestsGenerateAESIv,
                              kCDTEncryptionKeychainManagerTestsEncryptDpk, nil];
    NSSet *highlevelSteps = [NSSet setWithArray:self.manager.lastSteps];

    XCTAssertEqualObjects(expectedSteps, highlevelSteps, @"Method did not behave as expected");
}

@end

@implementation CDTEncryptionCustomKeychainManager

#pragma mark - Init object
- (instancetype)initWithStorage:(CDTEncryptionKeychainStorage *)storage
{
    self = [super initWithStorage:storage];
    if (self) {
        _lastSteps = [NSMutableArray array];
    }

    return self;
}

#pragma mark - CDTEncryptionKeychainManager methods
- (BOOL)keyExists
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsKeyExists];

    return [super keyExists];
}

#pragma mark - CDTEncryptionKeychainManager+Internal methods
- (BOOL)validateEncryptionKeyData:(CDTEncryptionKeychainData *)data
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsValidateEncryptionKeyData];

    return [super validateEncryptionKeyData:data];
}

- (NSData *)generateDpk
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsGenerateDpk];

    return [super generateDpk];
}

- (CDTEncryptionKeychainData *)keychainDataToStoreDpk:(NSData *)dpk
                                encryptedWithPassword:(NSString *)password
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk];

    return [super keychainDataToStoreDpk:dpk encryptedWithPassword:password];
}

- (NSData *)generatePBKDF2Salt
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt];

    return [super generatePBKDF2Salt];
}

- (NSData *)pbkdf2DerivedKeyForPassword:(NSString *)pass
                                   salt:(NSData *)salt
                             iterations:(NSInteger)iterations
                                 length:(NSUInteger)length
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsPBKDF2DerivedKey];

    return [super pbkdf2DerivedKeyForPassword:pass salt:salt iterations:iterations length:length];
}

- (NSData *)generateAESIv
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsGenerateAESIv];

    return [super generateAESIv];
}

- (NSData *)encryptDpk:(NSData *)dpk usingAESWithKey:(NSData *)key iv:(NSData *)iv
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsEncryptDpk];

    return [super encryptDpk:dpk usingAESWithKey:key iv:iv];
}

- (NSData *)decryptDpk:(NSData *)cipheredDpk usingAESWithKey:(NSData *)key iv:(NSData *)iv
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsDecryptDpk];

    return [super decryptDpk:cipheredDpk usingAESWithKey:key iv:iv];
}

@end
