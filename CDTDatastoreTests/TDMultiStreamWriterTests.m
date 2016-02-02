//
//  TDMultiStreamWriterTests.m
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
#import "CollectionUtils.h"  //needed for the class extenstion to NSData found in the CollectionUtils. although that class extension to NSData is easy to reproduce
#import "TDMultiStreamWriter.h"
#import "CloudantTests.h"

@interface MyMultiStreamWriterTester : NSObject <NSStreamDelegate>
{
@public
    NSInputStream* _stream;
    NSMutableData* _output;
    BOOL _finished;
}
@end

@implementation MyMultiStreamWriterTester

- (id)initWithStream: (NSInputStream*)stream {
    self = [super init];
    if (self) {
        _stream = stream;
        _output = [[NSMutableData alloc] init];
        stream.delegate = self;
    }
    return self;
}


- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    NSAssert(stream == _stream, @"stream passed to stream is not _stream");
    switch (event) {
        case NSStreamEventOpenCompleted:
//            NSLog(@"NSStreamEventOpenCompleted");
            break;
        case NSStreamEventHasBytesAvailable: {
//            NSLog(@"NSStreamEventHasBytesAvailable");
            uint8_t buffer[10];
            NSInteger length = [_stream read: buffer maxLength: sizeof(buffer)];
//            NSLog(@"    read %d bytes", (int)length);
            //Assert(length > 0);
            [_output appendBytes: buffer length: length];
            break;
        }
        case NSStreamEventEndEncountered:
//            NSLog(@"NSStreamEventEndEncountered");
            _finished = YES;
            break;
        default:
            NSAssert(NO, @"Unexpected stream event %d", (int)event);
    }
}

@end


@interface TDMultiStreamWriterTests : CloudantTests

@property NSString *expectedOutputString;
@property NSString *expectedOutputStringFirstPart;
@property NSString *expectedOutputStringSecondPart;

@end

@implementation TDMultiStreamWriterTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.expectedOutputStringFirstPart = @"<part the first, let us make it a bit longer for greater interest>";
    self.expectedOutputStringSecondPart = @"<2nd part, again unnecessarily prolonged for testing purposes beyond any reasonable length...>";
    self.expectedOutputString = [self.expectedOutputStringFirstPart stringByAppendingString:self.expectedOutputStringSecondPart];

}

- (TDMultiStreamWriter*) createWriter:(unsigned int)bufSize
{
    TDMultiStreamWriter* stream = [[TDMultiStreamWriter alloc] initWithBufferSize: bufSize];
    [stream addData: [self.expectedOutputStringFirstPart dataUsingEncoding: NSUTF8StringEncoding]];
    [stream addData: [self.expectedOutputStringSecondPart dataUsingEncoding: NSUTF8StringEncoding]];
    return stream;
}

- (void)testCreateWriter
{
    TDMultiStreamWriter* stream = [self createWriter:128];
    XCTAssertEqual(stream.length, (SInt64)self.expectedOutputString.length, @"unexpected string length in %s", __PRETTY_FUNCTION__);
}

- (void)testSynchronousWriter
{
    for (unsigned bufSize = 1; bufSize < 128; ++bufSize) {
//        NSLog(@"Buffer size = %u", bufSize);
        TDMultiStreamWriter* mp = [self createWriter:bufSize];
        XCTAssertNotNil(mp, @"multistream writer is nil in %s", __PRETTY_FUNCTION__);
        NSData* outputBytes = [mp allOutput];
        XCTAssertEqualObjects(outputBytes.my_UTF8ToString, self.expectedOutputString, @"unexpected string in %s", __PRETTY_FUNCTION__);
        // Run it a second time to make sure re-opening works:
        outputBytes = [mp allOutput];
        XCTAssertEqualObjects(outputBytes.my_UTF8ToString, self.expectedOutputString, @"unexpected string (2) in %s", __PRETTY_FUNCTION__);
    }
}

- (void)testASynchronousWriter
{
    TDMultiStreamWriter* writer = [self createWriter:16];
    //NSLog(@"writer output %@", [[writer allOutput] my_UTF8ToString] );
    NSInputStream* input = [writer openForInputStream];
    XCTAssertNotNil(input, @"NSInputStream is NIL in %s", __PRETTY_FUNCTION__);
    MyMultiStreamWriterTester *tester = [[MyMultiStreamWriterTester alloc] initWithStream: input];
    NSRunLoop* rl = [NSRunLoop currentRunLoop];
    [input scheduleInRunLoop: rl forMode: NSDefaultRunLoopMode];
//    NSLog(@"Opening stream");
    [input open];
    
    while (!tester->_finished) {
//        NSLog(@"...waiting for stream...");
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
    }
    
    [input removeFromRunLoop: rl forMode: NSDefaultRunLoopMode];
//    NSLog(@"Closing stream");
    [input close];
    [writer close];
    XCTAssertEqualObjects(tester->_output.my_UTF8ToString, self.expectedOutputString, @"unexpected string in %s", __PRETTY_FUNCTION__);
}



@end
