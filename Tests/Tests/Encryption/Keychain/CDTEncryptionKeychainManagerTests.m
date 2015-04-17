//
//  CDTEncryptionKeychainManagerTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 15/04/2015.
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

#import "CDTEncryptionKeychainManager+Internal.h"

#import "CDTEncryptionKeychainUtils.h"
#import "CDTEncryptionKeychainConstants.h"

#import "CDTMockEncryptionKeychainStorage.h"

#define CDTENCRYPTIONKEYCHAINMANAGERTESTS_PASSWORD_DEFAULT @"password"

NSString *const kCDTEncryptionKeychainManagerTestsValidatedEncryptionKeyData =
    @"kCDTEncryptionKeychainManagerTestsValidatedEncryptionKeyData";
NSString *const kCDTEncryptionKeychainManagerTestsEncryptionKeyDataAlreadyGenerated =
    @"kCDTEncryptionKeychainManagerTestsEncryptionKeyDataAlreadyGenerated";
NSString *const kCDTEncryptionKeychainManagerTestsGenerateDpk =
    @"kCDTEncryptionKeychainManagerTestsGenerateDpk";
NSString *const kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk =
    @"kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk";
NSString *const kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt =
    @"kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt";
NSString *const kCDTEncryptionKeychainManagerTestsGenerateAESKey =
    @"kCDTEncryptionKeychainManagerTestsGenerateAESKey";
NSString *const kCDTEncryptionKeychainManagerTestsGenerateAESIv =
    @"kCDTEncryptionKeychainManagerTestsGenerateAESIv";
NSString *const kCDTEncryptionKeychainManagerTestsEncryptDpk =
    @"kCDTEncryptionKeychainManagerTestsEncryptDpk";
NSString *const kCDTEncryptionKeychainManagerTestsDecryptCipheredDpk =
    @"kCDTEncryptionKeychainManagerTestsDecryptCipheredDpk";

@interface CDTEncryptionCustomKeychainManager : CDTEncryptionKeychainManager

@property (strong, nonatomic) NSMutableArray *lastSteps;

@end

@interface CDTEncryptionKeychainManagerTests : XCTestCase

@property (strong, nonatomic) CDTEncryptionCustomKeychainManager *manager;

@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) CDTEncryptionKeychainData *keychainData;
@property (strong, nonatomic) CDTMockEncryptionKeychainStorage *mockStorage;

@end

@implementation CDTEncryptionKeychainManagerTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    CDTMockEncryptionKeychainStorage *oneStorage = [[CDTMockEncryptionKeychainStorage alloc] init];
    CDTEncryptionKeychainManager *oneManager = [[CDTEncryptionKeychainManager alloc]
        initWithStorage:(CDTEncryptionKeychainStorage *)oneStorage];
    NSData *oneDpk = [oneManager generateDpk];

    self.password = CDTENCRYPTIONKEYCHAINMANAGERTESTS_PASSWORD_DEFAULT;
    self.keychainData =
        [oneManager keychainDataToStoreDpk:oneDpk encryptedWithPassword:self.password];

    self.mockStorage = [[CDTMockEncryptionKeychainStorage alloc] init];
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

- (void)testSimpleInitFails
{
    XCTAssertNil([[CDTEncryptionKeychainManager alloc] init], @"A storage is mandatory");
}

- (void)testInitWithStorageNilFails
{
    XCTAssertNil([[CDTEncryptionKeychainManager alloc] initWithStorage:nil],
                 @"A storage is mandatory");
}

- (void)testClearEncryptionKeyDataDelegatesToStorage
{
    [self.manager clearEncryptionKeyData];

    XCTAssertTrue(self.mockStorage.clearEncryptionKeyDataExecuted,
                  @"Data is read or written with the storage instance, therefore it is its "
                  @"responsability clearing the info");
}

- (void)testEncryptionKeyDataAlreadyGeneratedDelegatesToStorage
{
    [self.manager encryptionKeyDataAlreadyGenerated];

    XCTAssertTrue(self.mockStorage.areThereEncryptionKeyDataExecuted,
                  @"Data is read or written with the storage instance, therefore it is its "
                  @"responsability veritying if there is a key");
}

- (void)testRetrieveEncryptionKeyDataUsingPasswordFailsIfThereIsNotData
{
    XCTAssertNil([self.manager retrieveEncryptionKeyDataUsingPassword:self.password],
                 @"No key to return if there is no data in the keychain");
}

- (void)testRetrieveEncryptionKeyDataUsingPasswordFailsIfNumberOfIterationsIsWrong
{
    CDTEncryptionKeychainData *otherData =
        [CDTEncryptionKeychainData dataWithEncryptedDPK:self.keychainData.encryptedDPK
                                                   salt:self.keychainData.salt
                                                     iv:self.keychainData.iv
                                             iterations:1
                                                version:self.keychainData.version];

    self.mockStorage.encryptionKeyDataResult = otherData;
    self.mockStorage.areThereEncryptionKeyDataResult = YES;

    XCTAssertNil([self.manager retrieveEncryptionKeyDataUsingPassword:self.password],
                 @"Iterations mut be equal to %li", (long)CDTENCRYPTION_KEYCHAIN_PBKDF2_ITERATIONS);
}

- (void)testRetrieveEncryptionKeyDataUsingPasswordFailsIfIVDoesNotHaveTheRightSize
{
    CDTEncryptionKeychainData *otherData = [CDTEncryptionKeychainData
        dataWithEncryptedDPK:self.keychainData.encryptedDPK
                        salt:self.keychainData.salt
                          iv:[CDTEncryptionKeychainUtils
                                 generateRandomBytesInBufferWithLength:
                                     (CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE + 1)]
                  iterations:self.keychainData.iterations
                     version:self.keychainData.version];

    self.mockStorage.encryptionKeyDataResult = otherData;
    self.mockStorage.areThereEncryptionKeyDataResult = YES;

    XCTAssertNil([self.manager retrieveEncryptionKeyDataUsingPassword:self.password],
                 @"IV size must be equalt to %i", CDTENCRYPTION_KEYCHAIN_AES_IV_SIZE);
}

- (void)testRetrieveEncryptionKeyDataUsingPasswordRaisesExceptionIfNoPassIsProvided
{
    self.mockStorage.encryptionKeyDataResult = self.keychainData;
    self.mockStorage.areThereEncryptionKeyDataResult = YES;

    XCTAssertThrows([self.manager retrieveEncryptionKeyDataUsingPassword:nil],
                    @"A password is neccesary to decipher the key");
}

- (void)testRetrieveEncryptionKeyDataUsingPasswordPerformsTheExpectedSteps
{
    self.mockStorage.encryptionKeyDataResult = self.keychainData;
    self.mockStorage.areThereEncryptionKeyDataResult = YES;

    [self.manager retrieveEncryptionKeyDataUsingPassword:self.password];

    NSArray *expectedSteps = @[
        kCDTEncryptionKeychainManagerTestsValidatedEncryptionKeyData,
        kCDTEncryptionKeychainManagerTestsGenerateAESKey,
        kCDTEncryptionKeychainManagerTestsDecryptCipheredDpk
    ];

    XCTAssertEqualObjects(expectedSteps, self.manager.lastSteps,
                          @"Method did not behave as expected");
}

- (void)testGenerateEncryptionKeyDataUsingPasswordRaisesExceptionIfNoPassIsProvided
{
    XCTAssertThrows([self.manager generateEncryptionKeyDataUsingPassword:nil],
                    @"A password is neccesary to cipher the key");
}

- (void)testGenerateEncryptionKeyDataUsingPasswordFailsIfEncryptionDataWasAlreadyGenerated
{
    self.mockStorage.encryptionKeyDataResult = self.keychainData;
    self.mockStorage.areThereEncryptionKeyDataResult = YES;

    XCTAssertNil([self.manager generateEncryptionKeyDataUsingPassword:self.password],
                 @"No key should be generated if there is one already");
}

- (void)testGenerateEncryptionKeyDataUsingPasswordFailsIfKeyIsNotSaved
{
    self.mockStorage.saveEncryptionKeyDataResult = NO;

    XCTAssertNil([self.manager generateEncryptionKeyDataUsingPassword:self.password],
                 @"No key must be returned if it is not saved to the keychain");
}

- (void)testGenerateEncryptionKeyDataUsingPasswordPerformsExpectedHighlevelSteps
{
    [self.manager generateEncryptionKeyDataUsingPassword:self.password];

    NSArray *expectedSteps = @[
        kCDTEncryptionKeychainManagerTestsEncryptionKeyDataAlreadyGenerated,
        kCDTEncryptionKeychainManagerTestsGenerateDpk,
        kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk
    ];
    NSArray *highlevelSteps =
        [self.manager.lastSteps subarrayWithRange:NSMakeRange(0, [expectedSteps count])];
    BOOL asExpected = [expectedSteps isEqualToArray:highlevelSteps];

    XCTAssertTrue(asExpected && self.mockStorage.saveEncryptionKeyDataExecuted,
                  @"Method did not behave as expected. Expected: %@. Performed: %@ (didSave: %i)",
                  expectedSteps, highlevelSteps, self.mockStorage.saveEncryptionKeyDataExecuted);
}

- (void)testKeychainDataToStoreDpkPerformsExpectedHighlevelSteps
{
    NSData *dpk = [CDTEncryptionKeychainUtils
        generateRandomBytesInBufferWithLength:CDTENCRYPTION_KEYCHAIN_ENCRYPTIONKEY_SIZE];
    [self.manager keychainDataToStoreDpk:dpk encryptedWithPassword:self.password];

    NSSet *expectedSteps =
        [NSSet setWithObjects:kCDTEncryptionKeychainManagerTestsKeychainDataToStoreDpk,
                              kCDTEncryptionKeychainManagerTestsGeneratePBKDF2Salt,
                              kCDTEncryptionKeychainManagerTestsGenerateAESKey,
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
- (BOOL)encryptionKeyDataAlreadyGenerated
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsEncryptionKeyDataAlreadyGenerated];

    return [super encryptionKeyDataAlreadyGenerated];
}

#pragma mark - CDTEncryptionKeychainManager+Internal methods
- (BOOL)validatedEncryptionKeyData:(CDTEncryptionKeychainData *)data
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsValidatedEncryptionKeyData];

    return [super validatedEncryptionKeyData:data];
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

- (NSData *)generateAESKeyUsingPBKDF2ToDerivePassword:(NSString *)password
                                             withSalt:(NSData *)salt
                                           iterations:(NSInteger)iterations
                                               length:(NSUInteger)length
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsGenerateAESKey];

    return [super generateAESKeyUsingPBKDF2ToDerivePassword:password
                                                   withSalt:salt
                                                 iterations:iterations
                                                     length:length];
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

- (NSData *)decryptCipheredDpk:(NSData *)cipheredDpk usingAESWithKey:(NSData *)key iv:(NSData *)iv
{
    [self.lastSteps addObject:kCDTEncryptionKeychainManagerTestsDecryptCipheredDpk];

    return [super decryptCipheredDpk:cipheredDpk usingAESWithKey:key iv:iv];
}

@end
