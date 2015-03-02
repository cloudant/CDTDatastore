//
//  TD_DatabaseEncryptionTests.m
//  EncryptionTests
//
//  Created by Enrique de la Torre Fernandez on 23/02/2015.
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

#import "CloudantTests.h"
#import "CDTMockEncryptionKeyRetriever.h"

#import "TD_Database.h"

@interface TD_DatabaseEncryptionTests : CloudantTests

@end

@implementation TD_DatabaseEncryptionTests

- (void)testCopyEncryptionKeyDoesNotReturnTheSameKeyUsedToCreateTheDatabase
{
    CDTMockEncryptionKeyRetriever *mock = [[CDTMockEncryptionKeyRetriever alloc] init];
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests_copyEncryptionKey"];

    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyRetriever:mock];

    XCTAssertNotEqualObjects([db copyEncryptionKeyRetriever], mock,
                             @"Once a database is created with a key, this key must not change. "
                             @"Return a copy instead of the original");
}

- (void)testCreateWithoutEncryptionKeyThrowsException
{
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests"];

    XCTAssertThrows([TD_Database createEmptyDBAtPath:path withEncryptionKeyRetriever:nil],
                    @"The key is mandatory. Provide a dummy object to not cipher the database");
}

- (void)testOpenDoesNotFailIfEncryptionKeyReturnsAValue
{
    CDTMockEncryptionKeyRetriever *mock = [[CDTMockEncryptionKeyRetriever alloc] init];
    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"TD_DatabaseEncryptionTests"];

    TD_Database *db = [TD_Database createEmptyDBAtPath:path withEncryptionKeyRetriever:mock];

    XCTAssertTrue([db open], @"DB can be opened with a key with the encryption library available");
}

@end
