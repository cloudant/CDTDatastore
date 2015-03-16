//
//  TDMultipartDownloaderTests.m
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
#import "TDMultipartDownloader.h"
#import "TDInternal.h"
#import "CDTEncryptionKeyNilProvider.h"
#import "CloudantTests.h"

@interface TDMultipartDownloaderTests : CloudantTests


@end

@implementation TDMultipartDownloaderTests

- (void)testMultipartDownloader
{
    //These URLs only work for me!
    if (!$equal(NSUserName(), @"snej"))
        return;
    
    //RequireTestCase(TDBlobStore);  -- funny: this test doesn't exist in the code?
    //RequireTestCase(TDMultipartReader_Simple);
    //RequireTestCase(TDMultipartReader_Types);
    
    CDTEncryptionKeyNilProvider* provider = [CDTEncryptionKeyNilProvider provider];
    TD_Database* db =
        [TD_Database createEmptyDBAtPath:[NSTemporaryDirectory()
                                          stringByAppendingPathComponent:@"TDMultipartDownloader"]
               withEncryptionKeyProvider:provider];
    
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
          XCTAssertNil(error, @"NSError is not nil after alloc init of TDMultipartDownloader in %s", __PRETTY_FUNCTION__);
          TDMultipartDownloader* request = result;
//          NSLog(@"Got document: %@", request.document);
          NSDictionary* attachments = (request.document)[@"_attachments"];
          XCTAssertTrue(attachments.count >= 1, @"attachments.count >= 1 fails in %s", __PRETTY_FUNCTION__);
          XCTAssertEqual(db.attachmentStore.count, 0u, @"db.attachmentStore.count is not 0u in %s", __PRETTY_FUNCTION__);
          for (NSDictionary* attachment in attachments.allValues) {
              TDBlobStoreWriter* writer = [db attachmentWriterForAttachment: attachment];
              XCTAssertNotNil(writer, @"TDBlobStoreWriter is nil in %s", __PRETTY_FUNCTION__);
              XCTAssertTrue([writer install], @"TDBlobStoreWriter install returned NO in %s", __PRETTY_FUNCTION__);
              NSData* blob = [db.attachmentStore blobForKey: writer.blobKey];
//              NSLog(@"Found %u bytes of data for attachment %@", (unsigned)blob.length, attachment);
              NSNumber* lengthObj = attachment[@"encoded_length"] ?: attachment[@"length"];
              XCTAssertEqual(blob.length, [lengthObj unsignedLongLongValue], @"blob length and object length are not equal in %s", __PRETTY_FUNCTION__);
              XCTAssertEqual(writer.length, blob.length, @"writer length and blog length are not equal in %s", __PRETTY_FUNCTION__);
          }
          XCTAssertEqual(db.attachmentStore.count, attachments.count, @"db.attachmentStore.count and attachments.count are not equal in %s", __PRETTY_FUNCTION__);
          done = YES;
      }] start];
    
    while (!done)
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
}


@end
