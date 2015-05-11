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

#import "CDTEncryptionKeychainProvider+Internal.h"

#import "CDTMockEncryptionKeychainManager.h"

@interface CDTEncryptionKeychainProviderTests : XCTestCase

@property (strong, nonatomic) CDTEncryptionKeychainProvider *provider;

@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSData *encryptionKeyData;
@property (strong, nonatomic) CDTMockEncryptionKeychainManager *mockManager;

@end

@implementation CDTEncryptionKeychainProviderTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.password = @"password";
    self.encryptionKeyData = [@"encryptionKeyData" dataUsingEncoding:NSUnicodeStringEncoding];
    self.mockManager = [[CDTMockEncryptionKeychainManager alloc] init];

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
    self.mockManager.keyExistsResult = NO;

    [self.provider encryptionKey];

    XCTAssertTrue(self.mockManager.keyExistsExecuted &&
                      self.mockManager.generateAndSaveKeyProtectedByPasswordExecuted,
                  @"Generate the key if it was not created before");
}

- (void)testEncryptionKeyReturnNilIfGenerateEncryptionKeyDataReturnsNil
{
    self.mockManager.keyExistsResult = NO;
    self.mockManager.generateAndSaveKeyProtectedByPasswordResult = nil;

    XCTAssertNil([self.provider encryptionKey],
                 @"If no data is generated, there is not key to return");
}

- (void)testEncryptionKeyReturnHexStringIfGenerateEncryptionKeyDataReturnsData
{
    self.mockManager.keyExistsResult = NO;
    self.mockManager.generateAndSaveKeyProtectedByPasswordResult = self.encryptionKeyData;

    NSString *key = [self.provider encryptionKey];

    XCTAssertTrue([CDTEncryptionKeychainProviderTests isHexadecimalString:key],
                  @"The key has to be a hexadecimal string");
}

- (void)testEncryptionKeyRetrieveEncryptionKeyDataIfDataWasGeneratedBefore
{
    self.mockManager.keyExistsResult = YES;

    [self.provider encryptionKey];

    XCTAssertTrue(self.mockManager.keyExistsExecuted && self.mockManager.loadKeyUsingPasswordExecuted,
                  @"Get the key from keychain if it was generated before");
}

- (void)testEncryptionKeyReturnsNilIfRetrieveEncryptionKeyDataReturnsNil
{
    self.mockManager.keyExistsResult = YES;
    self.mockManager.loadKeyUsingPasswordResult = nil;

    XCTAssertNil([self.provider encryptionKey],
                 @"If no data is retrieved, there is not key to return");
}

- (void)testEncryptionKeyReturnHexStringIfRetrieveEncryptionKeyDataReturnsData
{
    self.mockManager.keyExistsResult = YES;
    self.mockManager.loadKeyUsingPasswordResult = self.encryptionKeyData;

    NSString *key = [self.provider encryptionKey];

    XCTAssertTrue([CDTEncryptionKeychainProviderTests isHexadecimalString:key],
                  @"The key has to be a hexadecimal string");
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
