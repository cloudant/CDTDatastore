//
//  TDMultipartWriterTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"  
#import "TDMultipartWriter.h"


@interface TDMultipartWriterTests : SenTestCase

@end

@implementation TDMultipartWriterTests


- (void)testSimpleMultiPartReadWithDelegate
{
    NSString* expectedOutput = @"\r\n--BOUNDARY\r\nContent-Length: 16\r\n\r\n<part the first>\r\n--BOUNDARY\r\nContent-Length: 10\r\nContent-Type: something\r\n\r\n<2nd part>\r\n--BOUNDARY--";
    //RequireTestCase(TDMultiStreamWriter);  //can this be done in SenTestingKit?
    for (unsigned bufSize = 1; bufSize < expectedOutput.length+1; ++bufSize) {
        TDMultipartWriter* mp = [[TDMultipartWriter alloc] initWithContentType: @"foo/bar"
                                                                      boundary: @"BOUNDARY"];
        
        STAssertEqualObjects(mp.contentType, @"foo/bar; boundary=\"BOUNDARY\"", @"ContentType not equal in %s", __PRETTY_FUNCTION__);
        STAssertEqualObjects(mp.boundary, @"BOUNDARY", @"Boundary not equal in %s", __PRETTY_FUNCTION__);
        
        [mp addData: [@"<part the first>" dataUsingEncoding: NSUTF8StringEncoding]];
        [mp setNextPartsHeaders: $dict({@"Content-Type", @"something"})];
        [mp addData: [@"<2nd part>" dataUsingEncoding: NSUTF8StringEncoding]];

        STAssertEquals((NSUInteger)mp.length, expectedOutput.length, @"Unexpected Writer output length in %s", __PRETTY_FUNCTION__);
        
        STAssertEqualObjects([[mp allOutput] my_UTF8ToString], expectedOutput, @"Unexpected Writer output content in %s", __PRETTY_FUNCTION__);
        [mp close];
    }

}


@end

