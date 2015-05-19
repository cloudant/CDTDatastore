//
//  CDTBlobDataReaderTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 14/05/2015.
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

#import "CDTBlobDataReader.h"

@interface CDTBlobDataReaderTests : XCTestCase

@property (strong, nonatomic) CDTBlobDataReader *readerForNonExistingFile;

@end

@implementation CDTBlobDataReaderTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    NSString *pathToNonExistingFile =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"nonExistingFile.txt"];
    self.readerForNonExistingFile = [CDTBlobDataReader readerWithPath:pathToNonExistingFile];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    self.readerForNonExistingFile = nil;

    [super tearDown];
}

- (void)testInitWithPathEqualToNilFails
{
    XCTAssertNil([[CDTBlobDataReader alloc] initWithPath:nil], @"A path is mandatory");
}

- (void)testInitWithEmptyPathFails
{
    XCTAssertNil([[CDTBlobDataReader alloc] initWithPath:@""], @"A path is mandatory");
}

- (void)testInitWithNotValidPathSucceeds
{
    XCTAssertNotNil([[CDTBlobDataReader alloc] initWithPath:@"This is not a path"],
                    @"Any string is valid as long as it is not empty");
}

- (void)testDataWithErrorFailsIfFileDoesNotExist
{
    NSError *error = nil;
    NSData *data = [self.readerForNonExistingFile dataWithError:&error];

    XCTAssertNil(data, @"No data to read if file does not exist");
    XCTAssertNotNil(error, @"An error must be informed");
}

- (void)testInputStreamWithOutputLengthFailsIfFileDoesNotExist
{
    UInt64 length = 0;
    XCTAssertNil([self.readerForNonExistingFile inputStreamWithOutputLength:&length],
                 @"File must exist in order to create an input stream");
}

- (void)testInputStreamWithOutputLengthFailsIfFileDoesNotExistEvenIfIDoNotGetTheLength
{
    XCTAssertNil([self.readerForNonExistingFile inputStreamWithOutputLength:nil],
                 @"File must exist in order to create an input stream");
}

@end
