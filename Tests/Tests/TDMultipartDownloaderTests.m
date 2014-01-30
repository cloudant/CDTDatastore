//
//  TDMultipartDownloaderTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TDMultipartDownloader.h"
#import "TDInternal.h"

@interface TDMultipartDownloaderTests : SenTestCase


@end

@implementation TDMultipartDownloaderTests

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


- (void)testMultipartDownloader
{
    //These URLs only work for me!
    if (!$equal(NSUserName(), @"snej"))
        return;
    
    //RequireTestCase(TDBlobStore);  -- funny: this test doesn't exist in the code?
    //RequireTestCase(TDMultipartReader_Simple);
    //RequireTestCase(TDMultipartReader_Types);
    
    TD_Database* db = [TD_Database createEmptyDBAtPath: [NSTemporaryDirectory() stringByAppendingPathComponent: @"TDMultipartDownloader"]];
    //NSString* urlStr = @"http://127.0.0.1:5984/demo-shopping-attachments/2F9078DF-3C72-44C2-8332-B07B3A29FFE4"
    NSString* urlStr = @"http://127.0.0.1:5984/attach-test/oneBigAttachment";
    urlStr = [urlStr stringByAppendingString: @"?revs=true&attachments=true"];
    NSURL* url = [NSURL URLWithString: urlStr];
    __block BOOL done = NO;
    [[[TDMultipartDownloader alloc] initWithURL: url
                                       database: db
                                 requestHeaders: nil
                                   onCompletion: ^(id result, NSError * error)
      {
          STAssertNil(error, @"NSError is not nil after alloc init of TDMultipartDownloader in %s", __PRETTY_FUNCTION__);
          TDMultipartDownloader* request = result;
          NSLog(@"Got document: %@", request.document);
          NSDictionary* attachments = (request.document)[@"_attachments"];
          STAssertTrue(attachments.count >= 1, @"attachments.count >= 1 fails in %s", __PRETTY_FUNCTION__);
          STAssertEquals(db.attachmentStore.count, 0u, @"db.attachmentStore.count is not 0u in %s", __PRETTY_FUNCTION__);
          for (NSDictionary* attachment in attachments.allValues) {
              TDBlobStoreWriter* writer = [db attachmentWriterForAttachment: attachment];
              STAssertNotNil(writer, @"TDBlobStoreWriter is nil in %s", __PRETTY_FUNCTION__);
              STAssertTrue([writer install], @"TDBlobStoreWriter install returned NO in %s", __PRETTY_FUNCTION__);
              NSData* blob = [db.attachmentStore blobForKey: writer.blobKey];
              NSLog(@"Found %u bytes of data for attachment %@", (unsigned)blob.length, attachment);
              NSNumber* lengthObj = attachment[@"encoded_length"] ?: attachment[@"length"];
              STAssertEquals(blob.length, [lengthObj unsignedLongLongValue], @"blob length and object length are not equal in %s", __PRETTY_FUNCTION__);
              STAssertEquals(writer.length, blob.length, @"writer length and blog length are not equal in %s", __PRETTY_FUNCTION__);
          }
          STAssertEquals(db.attachmentStore.count, attachments.count, @"db.attachmentStore.count and attachments.count are not equal in %s", __PRETTY_FUNCTION__);
          done = YES;
      }] start];
    
    while (!done)
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
}


@end
