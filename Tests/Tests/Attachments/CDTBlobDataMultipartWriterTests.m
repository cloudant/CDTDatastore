//
//  CDTBlobDataMultipartWriterTests.m
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

#import "CDTBlobDataMultipartWriter.h"

#import "TDMisc.h"

@interface CDTBlobDataMultipartWriterTests : XCTestCase

@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *pathToNonExistingFile;
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) CDTBlobDataMultipartWriter *multipartWriter;

@end

@implementation CDTBlobDataMultipartWriterTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
    self.path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobDataMultipartWriterTests.txt"];
    [[NSFileManager defaultManager] createFileAtPath:self.path contents:nil attributes:nil];

    self.pathToNonExistingFile = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CDTBlobDataMultipartWriterTests_noExists.txt"];

    self.data = [@"Lorem ipsum" dataUsingEncoding:NSASCIIStringEncoding];

    self.multipartWriter = [CDTBlobDataMultipartWriter multipartWriter];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    if (self.multipartWriter) {
        [self.multipartWriter closeBlob];
        self.multipartWriter = nil;
    }

    self.data = nil;

    self.pathToNonExistingFile = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
    self.path = nil;

    [super tearDown];
}

- (void)testWriterIsNotOpenAfterCreation
{
    XCTAssertFalse([self.multipartWriter isBlobOpen], @"After init, blob is not open");
}

- (void)testOpenBlobFailsIfFileDoesNotExist
{
    XCTAssertFalse([self.multipartWriter openBlobAtPath:self.pathToNonExistingFile],
                   @"If the file does not exist yet, it can not be open");
}

- (void)testOpenBlobSucceedsIfFileExists
{
    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.path],
                  @"If the file exists, we should be able to open it");
}

- (void)testOpenBlobFailsIfAlreadyOpen
{
    [self.multipartWriter openBlobAtPath:self.path];

    XCTAssertFalse([self.multipartWriter openBlobAtPath:self.path],
                   @"Close the blob before opening it again");
}

- (void)testOpenBlobToAddDataSucceedsAfterClosingBlob
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter closeBlob];

    XCTAssertTrue([self.multipartWriter openBlobAtPath:self.path],
                  @"As long as the file still exists, we should be able to open it again");
}

- (void)testAddDataFailsIfBlobIsNotOpen
{
    XCTAssertFalse([self.multipartWriter addData:self.data], @"Open blob before adding data");
}

- (void)testAddDataFailsIfDataIsNil
{
    XCTAssertFalse([self.multipartWriter addData:nil], @"Param is mandatory");
}

- (void)testAddDataTwiceGenerateExpectedResult
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.path];

    NSMutableData *expectedData = [NSMutableData dataWithData:self.data];
    [expectedData appendData:self.data];

    XCTAssertEqualObjects(
        fileData, expectedData,
        @"Add same data twice should be equal to a buffer with that data copied twice");
}

- (void)testAddDataBeforeClosingBlobAndAfterOpeningBlobGenerateExpectedResult
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];
    [self.multipartWriter closeBlob];

    NSData *fileData = [NSData dataWithContentsOfFile:self.path];

    XCTAssertEqualObjects(fileData, self.data,
                          @"Data is added at the begining of the blob after opening it");
}

- (void)testCloseBlobFailIfBlobIsNotOpen
{
    XCTAssertFalse([self.multipartWriter closeBlob], @"Open blob in order to close it");
}

- (void)testSHA1DigestIsNilAfterInitialisation
{
    XCTAssertNil(self.multipartWriter.sha1Digest, @"No data after init so it has to be nil");
}

- (void)testSHA1DigestIsNilAfterOpeningABlob
{
    [self.multipartWriter openBlobAtPath:self.path];

    XCTAssertNil(self.multipartWriter.sha1Digest,
                 @"No data after opening the blob, so it has to be nil");
}

- (void)testSHA1DigestIsNilBeforeClosingTheBlob
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:self.data];

    XCTAssertNil(self.multipartWriter.sha1Digest,
                 @"No digest will be generated unti the blob is closed");
}

- (void)testSHA1DigestIsNilIfNoDataIsAdded
{
    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter closeBlob];

    XCTAssertNil(self.multipartWriter.sha1Digest, @"No data added so it has to be nil");
}

- (void)testSHA1DigestReturnsExpectedValues
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    NSString *thisPath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *thisData = [NSData dataWithContentsOfFile:thisPath];

    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:thisData];
    [self.multipartWriter closeBlob];

    NSString *hexSHA1Digest = TDHexFromBytes(self.multipartWriter.sha1Digest.bytes,
                                             self.multipartWriter.sha1Digest.length);

    XCTAssertEqualObjects(hexSHA1Digest, @"d55f9ac778baf2256fa4de87aac61f590ebe66e0",
                          @"Unexpected result");

    thisPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    thisData = [NSData dataWithContentsOfFile:thisPath];

    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:thisData];
    [self.multipartWriter closeBlob];

    hexSHA1Digest = TDHexFromBytes(self.multipartWriter.sha1Digest.bytes,
                                   self.multipartWriter.sha1Digest.length);

    XCTAssertEqualObjects(hexSHA1Digest, @"3ff2989bccf52150bba806bae1db2e0b06ad6f88",
                          @"Unexpected result");
}

- (void)testSHA1DigestReturnsExpectedValuesIfDataAddedByPieces
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    NSString *thisPath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *thisData = [NSData dataWithContentsOfFile:thisPath];
    NSData *subData01 = [thisData subdataWithRange:NSMakeRange(0, thisData.length / 2)];
    NSData *subData02 = [thisData
        subdataWithRange:NSMakeRange(subData01.length, thisData.length - subData01.length)];

    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:subData01];
    [self.multipartWriter addData:subData02];
    [self.multipartWriter closeBlob];

    NSString *hexSHA1Digest = TDHexFromBytes(self.multipartWriter.sha1Digest.bytes,
                                             self.multipartWriter.sha1Digest.length);

    XCTAssertEqualObjects(hexSHA1Digest, @"d55f9ac778baf2256fa4de87aac61f590ebe66e0",
                          @"Unexpected result");

    thisPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    thisData = [NSData dataWithContentsOfFile:thisPath];
    subData01 = [thisData subdataWithRange:NSMakeRange(0, thisData.length / 2)];
    subData02 = [thisData
        subdataWithRange:NSMakeRange(subData01.length, thisData.length - subData01.length)];

    [self.multipartWriter openBlobAtPath:self.path];
    [self.multipartWriter addData:subData01];
    [self.multipartWriter addData:subData02];
    [self.multipartWriter closeBlob];

    hexSHA1Digest = TDHexFromBytes(self.multipartWriter.sha1Digest.bytes,
                                   self.multipartWriter.sha1Digest.length);

    XCTAssertEqualObjects(hexSHA1Digest, @"3ff2989bccf52150bba806bae1db2e0b06ad6f88",
                          @"Unexpected result");
}

@end
