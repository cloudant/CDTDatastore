//
//  TDMultipartReaderTests.m
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
#import "TDMultipartReader.h"
#import "CloudantTests.h"

@interface MyMultipartReaderDelegate : NSObject <TDMultipartReaderDelegate>
{
    NSMutableData* _currentPartData;
    NSMutableArray* _partList, *_headersList;
}
@property (readonly) NSArray* partList, *headerList;
@end


@implementation MyMultipartReaderDelegate

@synthesize partList=_partList, headerList=_headersList;

- (void) startedPart: (NSDictionary*)headers {
    NSAssert(!_currentPartData, @"MyMultipartReaderDelegate:startedPart currentPartData not NIL.");
    _currentPartData = [[NSMutableData alloc] init];
    if (!_partList)
        _partList = [[NSMutableArray alloc] init];
    [_partList addObject: _currentPartData];
    if (!_headersList)
        _headersList = [[NSMutableArray alloc] init];
    [_headersList addObject: headers];
}

- (void) appendToPart: (NSData*)data {
    NSAssert(_currentPartData, @"MyMultipartReaderDelegate:appendToPart currentPartData is NIL.");
    [_currentPartData appendData: data];
}

- (void) finishedPart {
    NSAssert(_currentPartData, @"MyMultipartReaderDelegate:appendToPart currentPartData is NIL.");
    _currentPartData = nil;
    
}


@end



@interface TDMultipartReaderTests : CloudantTests

@end

@implementation TDMultipartReaderTests

- (void)testBoundaryObject
{
    //NSLog(@"TDMultpartReader_Types");
    TDMultipartReader* reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=\"BOUNDARY\"" delegate: nil];
    XCTAssertEqualObjects(reader.boundary, [@"\r\n--BOUNDARY" dataUsingEncoding: NSUTF8StringEncoding], @"Quotation escaped Boundary objects not equal in %s", __PRETTY_FUNCTION__);
    
    reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=BOUNDARY" delegate: nil];
    XCTAssertEqualObjects(reader.boundary, [@"\r\n--BOUNDARY" dataUsingEncoding: NSUTF8StringEncoding], @"No quotation Boundary objects not equal in %s", __PRETTY_FUNCTION__);
    
    reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=\"BOUNDARY" delegate: nil];
    XCTAssertNil(reader, @"TDMultipartReader not nil with improper initialization in %s", __PRETTY_FUNCTION__);
    
    reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related;boundary=X" delegate: nil];
    XCTAssertEqualObjects(reader.boundary, [@"\r\n--X" dataUsingEncoding: NSUTF8StringEncoding], @"No quotation Arbitrary objects not equal in %s", __PRETTY_FUNCTION__);
    
}

- (void)testSimpleMultiPartReadWithDelegate
{
    NSData* mime = [@"--BOUNDARY\r\nFoo: Bar\r\n Header : Val ue \r\n\r\npart the first\r\n--BOUNDARY  \r\n\r\n2nd part\r\n--BOUNDARY--"
                    dataUsingEncoding: NSUTF8StringEncoding];
    
    NSArray* expectedParts = @[[@"part the first" dataUsingEncoding: NSUTF8StringEncoding],
                               [@"2nd part" dataUsingEncoding: NSUTF8StringEncoding]];
    NSArray* expectedHeaders = @[$dict({@"Foo", @"Bar"},
                                       {@"Header", @"Val ue"}),
                                  $dict()];
    
    for (NSUInteger chunkSize = 1; chunkSize <= mime.length; ++chunkSize) {
//        NSLog(@"--- chunkSize = %u", (unsigned)chunkSize);
        MyMultipartReaderDelegate* delegate = [[MyMultipartReaderDelegate alloc] init];
        TDMultipartReader* reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=\"BOUNDARY\"" delegate: delegate];
        XCTAssertFalse(reader.finished, @"Premature finished reading data in %s", __PRETTY_FUNCTION__);
        
        NSRange r = {0, 0};
        do {
            XCTAssertTrue(r.location < mime.length, @"Parser didn't stop at end in %s", __PRETTY_FUNCTION__ );
            r.length = MIN(chunkSize, mime.length - r.location);
            [reader appendData: [mime subdataWithRange: r]];
            XCTAssertTrue(!reader.error, @"Reader got a parse error: %@ in %s", reader.error, __PRETTY_FUNCTION__ );
            r.location += chunkSize;
        } while (!reader.finished);
        XCTAssertEqualObjects(delegate.partList, expectedParts, @"Unexpected part in Delegate in %s",  __PRETTY_FUNCTION__ );
        XCTAssertEqualObjects(delegate.headerList, expectedHeaders, @"Unexpected Headers in Delegate in %s", __PRETTY_FUNCTION__ );
    }

}


@end

