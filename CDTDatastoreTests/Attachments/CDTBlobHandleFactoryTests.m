//
//  CDTBlobHandleFactoryTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 22/05/2015.
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

#import "CDTBlobHandleFactory.h"

#import "CDTBlobData.h"
#import "CDTBlobEncryptedData.h"

#import "CDTEncryptionKeyNilProvider.h"
#import "CDTHelperFixedKeyProvider.h"

@interface CDTBlobHandleFactoryTests : XCTestCase

@end

@implementation CDTBlobHandleFactoryTests

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

- (void)testInitRaiseExceptionIfProviderIsNil
{
    XCTAssertThrows([[CDTBlobHandleFactory alloc] initWithEncryptionKeyProvider:nil],
                    @"A key provider is always mandatory");
}

- (void)testFactoryWithNilProviderCreatesBlobHandlesForNonEncryptedAttachments
{
    CDTBlobHandleFactory *factory = [[CDTBlobHandleFactory alloc]
        initWithEncryptionKeyProvider:[CDTEncryptionKeyNilProvider provider]];

    id<CDTBlobReader> reader = [factory readerWithPath:@"///This is not a path"];
    id<CDTBlobWriter> writer = [factory writerWithPath:@"///This is not a path"];

    XCTAssertTrue([reader isKindOfClass:[CDTBlobData class]], @"Unexpected type");
    XCTAssertTrue([writer isKindOfClass:[CDTBlobData class]], @"Unexpected type");
}

- (void)testFactoryWithFixedProviderCreatesBlobHandlesForEncryptedAttachments
{
    CDTBlobHandleFactory *factory = [[CDTBlobHandleFactory alloc]
        initWithEncryptionKeyProvider:[CDTHelperFixedKeyProvider provider]];

    id<CDTBlobReader> reader = [factory readerWithPath:@"///This is not a path"];
    id<CDTBlobWriter> writer = [factory writerWithPath:@"///This is not a path"];

    XCTAssertTrue([reader isKindOfClass:[CDTBlobEncryptedData class]], @"Unexpected type");
    XCTAssertTrue([writer isKindOfClass:[CDTBlobEncryptedData class]], @"Unexpected type");
}

@end
