//
//  CDTEncryptionKeychainDataTests.m
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

#import "CDTEncryptionKeychainData.h"

@interface CDTEncryptionKeychainDataTests : XCTestCase

@property (strong, nonatomic) NSData *defaultEncryptedDPK;
@property (strong, nonatomic) NSData *defaultSalt;
@property (strong, nonatomic) NSData *defaultIv;
@property (assign, nonatomic) NSInteger defaultIterations;
@property (strong, nonatomic) NSString *defaultVersion;

@end

@implementation CDTEncryptionKeychainDataTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.defaultEncryptedDPK = [@"encryptedDPK" dataUsingEncoding:NSUnicodeStringEncoding];
    self.defaultSalt = [@"salt" dataUsingEncoding:NSUnicodeStringEncoding];
    self.defaultIv = [@"iv" dataUsingEncoding:NSUnicodeStringEncoding];
    self.defaultIterations = 0;
    self.defaultVersion = @"x.x";
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.defaultEncryptedDPK = nil;
    self.defaultSalt = nil;
    self.defaultIv = nil;
    self.defaultVersion = nil;

    [super tearDown];
}

- (void)testSimpleInitFails
{
    XCTAssertNil([[CDTEncryptionKeychainData alloc] init], @"All properties are mandatory");
}

- (void)testInitFailsIfEncryptedDPKIsNil
{
    XCTAssertNil([[CDTEncryptionKeychainData alloc] initWithEncryptedDPK:nil
                                                                    salt:self.defaultSalt
                                                                      iv:self.defaultIv
                                                              iterations:self.defaultIterations
                                                                 version:self.defaultVersion],
                 @"Encrypted DPK is mandatory");
}

- (void)testInitFailsIfSaltIsNil
{
    XCTAssertNil([[CDTEncryptionKeychainData alloc] initWithEncryptedDPK:self.defaultEncryptedDPK
                                                                    salt:nil
                                                                      iv:self.defaultIv
                                                              iterations:self.defaultIterations
                                                                 version:self.defaultVersion],
                 @"Salt is mandatory");
}

- (void)testInitFailsIfIVIsNil
{
    XCTAssertNil([[CDTEncryptionKeychainData alloc] initWithEncryptedDPK:self.defaultEncryptedDPK
                                                                    salt:self.defaultSalt
                                                                      iv:nil
                                                              iterations:self.defaultIterations
                                                                 version:self.defaultVersion],
                 @"IV is mandatory");
}

- (void)testInitFailsIfVersionIsNil
{
    XCTAssertNil([[CDTEncryptionKeychainData alloc] initWithEncryptedDPK:self.defaultEncryptedDPK
                                                                    salt:self.defaultSalt
                                                                      iv:self.defaultIv
                                                              iterations:self.defaultIterations
                                                                 version:nil],
                 @"IV is mandatory");
}

- (void)testInitFailsIfIterationsValueIsNegative
{
    XCTAssertNil([[CDTEncryptionKeychainData alloc] initWithEncryptedDPK:self.defaultEncryptedDPK
                                                                    salt:self.defaultSalt
                                                                      iv:self.defaultIv
                                                              iterations:-1
                                                                 version:self.defaultVersion],
                 @"Iterations value has to be a positive number");
}

- (void)testArchiveUnarchiveData
{
    CDTEncryptionKeychainData *keychainData =
        [[CDTEncryptionKeychainData alloc] initWithEncryptedDPK:self.defaultEncryptedDPK
                                                           salt:self.defaultSalt
                                                             iv:self.defaultIv
                                                     iterations:self.defaultIterations
                                                        version:self.defaultVersion];

    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:keychainData];
    CDTEncryptionKeychainData *keychainUnarchivedData =
        [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    
    XCTAssertTrue([keychainData.encryptedDPK isEqualToData:keychainUnarchivedData.encryptedDPK] &&
                  [keychainData.salt isEqualToData:keychainUnarchivedData.salt] &&
                  [keychainData.iv isEqualToData:keychainUnarchivedData.iv] &&
                  (keychainData.iterations == keychainUnarchivedData.iterations) &&
                  [keychainData.version isEqualToString:keychainUnarchivedData.version],
                  @"An unarchived data must be equal to the original");
}

@end
