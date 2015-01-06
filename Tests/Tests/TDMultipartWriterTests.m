//
//  TDMultipartWriterTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import "CollectionUtils.h"  
#import "TDMultipartWriter.h"
#import "CloudantTests.h"


@interface TDMultipartWriterTests : CloudantTests

@end

@implementation TDMultipartWriterTests


- (void)testSimpleMultiPartReadWithDelegate
{
    NSString* expectedOutput = @"\r\n--BOUNDARY\r\nContent-Length: 16\r\n\r\n<part the first>\r\n--BOUNDARY\r\nContent-Length: 10\r\nContent-Type: something\r\n\r\n<2nd part>\r\n--BOUNDARY--";
    //RequireTestCase(TDMultiStreamWriter);  //can this be done in SenTestingKit?
    for (unsigned bufSize = 1; bufSize < expectedOutput.length+1; ++bufSize) {
        TDMultipartWriter* mp = [[TDMultipartWriter alloc] initWithContentType: @"foo/bar"
                                                                      boundary: @"BOUNDARY"];
        
        XCTAssertEqualObjects(mp.contentType, @"foo/bar; boundary=\"BOUNDARY\"", @"ContentType not equal in %s", __PRETTY_FUNCTION__);
        XCTAssertEqualObjects(mp.boundary, @"BOUNDARY", @"Boundary not equal in %s", __PRETTY_FUNCTION__);
        
        [mp addData: [@"<part the first>" dataUsingEncoding: NSUTF8StringEncoding]];
        [mp setNextPartsHeaders: $dict({@"Content-Type", @"something"})];
        [mp addData: [@"<2nd part>" dataUsingEncoding: NSUTF8StringEncoding]];

        XCTAssertEqual((NSUInteger)mp.length, expectedOutput.length, @"Unexpected Writer output length in %s", __PRETTY_FUNCTION__);
        
        XCTAssertEqualObjects([[mp allOutput] my_UTF8ToString], expectedOutput, @"Unexpected Writer output content in %s", __PRETTY_FUNCTION__);
        [mp close];
    }

}


@end

