//
//  TDMultipartReaderTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"  
#import "TDMultipartReader.h"


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



@interface TDMultipartReaderTests : SenTestCase

@end

@implementation TDMultipartReaderTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBoundaryObject
{
    //NSLog(@"TDMultpartReader_Types");
    TDMultipartReader* reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=\"BOUNDARY\"" delegate: nil];
    STAssertEqualObjects(reader.boundary, [@"\r\n--BOUNDARY" dataUsingEncoding: NSUTF8StringEncoding], @"Quotation escaped Boundary objects not equal in %s", __PRETTY_FUNCTION__);
    
    reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=BOUNDARY" delegate: nil];
    STAssertEqualObjects(reader.boundary, [@"\r\n--BOUNDARY" dataUsingEncoding: NSUTF8StringEncoding], @"No quotation Boundary objects not equal in %s", __PRETTY_FUNCTION__);
    
    reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=\"BOUNDARY" delegate: nil];
    STAssertNil(reader, @"TDMultipartReader not nil with improper initialization in %s", __PRETTY_FUNCTION__);
    
    reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related;boundary=X" delegate: nil];
    STAssertEqualObjects(reader.boundary, [@"\r\n--X" dataUsingEncoding: NSUTF8StringEncoding], @"No quotation Arbitrary objects not equal in %s", __PRETTY_FUNCTION__);
    
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
        NSLog(@"--- chunkSize = %u", (unsigned)chunkSize);
        MyMultipartReaderDelegate* delegate = [[MyMultipartReaderDelegate alloc] init];
        TDMultipartReader* reader = [[TDMultipartReader alloc] initWithContentType: @"multipart/related; boundary=\"BOUNDARY\"" delegate: delegate];
        STAssertFalse(reader.finished, @"Premature finished reading data in %s", __PRETTY_FUNCTION__);
        
        NSRange r = {0, 0};
        do {
            STAssertTrue(r.location < mime.length, @"Parser didn't stop at end in %s", __PRETTY_FUNCTION__ );
            r.length = MIN(chunkSize, mime.length - r.location);
            [reader appendData: [mime subdataWithRange: r]];
            STAssertTrue(!reader.error, @"Reader got a parse error: %@ in %s", reader.error, __PRETTY_FUNCTION__ );
            r.location += chunkSize;
        } while (!reader.finished);
        STAssertEqualObjects(delegate.partList, expectedParts, @"Unexpected part in Delegate in %s",  __PRETTY_FUNCTION__ );
        STAssertEqualObjects(delegate.headerList, expectedHeaders, @"Unexpected Headers in Delegate in %s", __PRETTY_FUNCTION__ );
    }

}


@end

