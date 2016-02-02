//
//  AttachmentCRUD.m
//  Tests
//
//  Created by Rhys Short on 07/08/2014.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>

#import <CDTDatastore/CloudantSync.h>
#import <MRDatabaseContentChecker/MRDatabaseContentChecker.h>

#import "CloudantSyncTests.h"
#import "DBQueryUtils.h"
#import "AmazonMD5Util.h"

#import "TD_Database+BlobFilenames.h"

#import "CDTMisc.h"

@interface AttachmentCRUD : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) DBQueryUtils *dbutil;

@end

/** Attachment which returns nil for its input stream */
@interface CDTNullAttachment : CDTAttachment

@end

@implementation CDTNullAttachment

- (NSData*)dataFromAttachmentContent { return nil; }

@end


@implementation AttachmentCRUD

- (void)setUp
{
    [super setUp];

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    self.dbutil =[[DBQueryUtils alloc]
                  initWithDbPath:[self pathForDBName:self.datastore.name]];

    XCTAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.

    self.datastore = nil;
    self.dbutil = nil;

    [super tearDown];
}

#pragma mark Helpers

- (BOOL)attachmentExists:(NSString*)filename
{
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *attachmentsPath = [self.factoryPath
                                 stringByAppendingPathComponent:@"test attachments"];
    NSString *attachmentPath = [attachmentsPath stringByAppendingPathComponent:filename];

    BOOL isDirectory;
    BOOL attachmentExists = [fm fileExistsAtPath:attachmentPath isDirectory:&isDirectory];
    return attachmentExists && !isDirectory;
}

- (BOOL)attachmentsPathIsEmpty
{
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *attachmentsPath = [self.factoryPath
                                 stringByAppendingPathComponent:@"test attachments"];
    NSArray *files = [fm contentsOfDirectoryAtPath:attachmentsPath error:nil];
    return ((files != nil) && files.count == 0);
}

#pragma mark Tests

-(void)testDocumentRevisionFactoryWithAttachmentDataIncluded
{
    NSError * error;
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    
    NSDictionary * dict = @{@"_id":@"someIdHere",
                            @"_rev":@"3-750dac460a6cc41e6999f8943b8e603e",
                            @"aKey":@"aValue",
                            @"_attachments":@{@"bonsai-boston.jpg":@{@"stub":[NSNumber numberWithBool:NO],
                                                                     @"length":[NSNumber numberWithLong:[encoded length]],
                                                                     @"digest":@"thisisahashiswear1234",
                                                                     @"revpos":[NSNumber numberWithInt:1],
                                                                     @"content_type":@"image/jpeg",
                                                                     @"data":encoded
                                                                     }
                                              },
                            @"_conflicts":@[],
                            @"_deleted_conflicts":@[],
                            @"_local_seq":@1,
                            @"_revs_info":@{},
                            @"_revisions":@[],
                            @"hello":@"world"
                            };
    NSDictionary * body = @{@"aKey":@"aValue",@"hello":@"world"};
    
    
    XCTAssertNil(error, @"Error should have been nil");
    
    CDTDocumentRevision * rev = [CDTDocumentRevision createRevisionFromJson:dict
                                                                forDocument:[NSURL
                                                                             URLWithString:@"http://localhost:5984/temp/doc"]
                                                                      error:&error];
    
    XCTAssertNil(error, @"Error occured creating document with valid data");
    XCTAssertNotNil(rev, @"Revision was nil");
    XCTAssertEqualObjects(@"someIdHere",
                         rev.docId,
                         @"docId was different, expected someIdHere actual %@",
                         rev.docId);
    XCTAssertEqualObjects(@"3-750dac460a6cc41e6999f8943b8e603e",
                         rev.revId,
                         @"Revision was different expected 3-750dac460a6cc41e6999f8943b8e603e actual %@",
                         rev.revId);
    
    XCTAssertEqualObjects(body, rev.body, @"Body was different");
    XCTAssertFalse(rev.deleted, @"Document is not marked as deleted");
    XCTAssertEqual([rev.attachments count], (NSUInteger) 1, @"Attachment count is wrong, expected 1 actual %d", [rev.attachments count]);
    
}

-(void)testDocumentRevisionFactoryWithAttachmentDataExcluded
{
    NSError * error;
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    NSURL * attachmentDir = [bundle resourceURL];
    
    NSDictionary * dict = @{@"_id":@"someIdHere",
                            @"_rev":@"3-750dac460a6cc41e6999f8943b8e603e",
                            @"aKey":@"aValue",
                            @"_attachments":@{@"bonsai-boston.jpg":@{@"stub":[NSNumber numberWithBool:YES],
                                                                     @"length":[NSNumber numberWithLong:[encoded length]],
                                                                     @"digest":@"thisisahashiswear1234",
                                                                     @"revpos":[NSNumber numberWithInt:1],
                                                                     @"content_type":@"image/jpeg",
                                                                     }
                                              },
                            @"_conflicts":@[],
                            @"_deleted_conflicts":@[],
                            @"_local_seq":@1,
                            @"_revs_info":@{},
                            @"_revisions":@[],
                            @"hello":@"world"
                            };
    NSDictionary * body = @{@"aKey":@"aValue",@"hello":@"world"};
    
    
    XCTAssertNil(error, @"Error should have been nil");
    
    CDTDocumentRevision * rev = [CDTDocumentRevision createRevisionFromJson:dict
                                                                forDocument:attachmentDir
                                                                      error:&error];
    
    XCTAssertNil(error, @"Error occured creating document with valid data");
    XCTAssertNotNil(rev, @"Revision was nil");
    XCTAssertEqualObjects(@"someIdHere",
                         rev.docId,
                         @"docId was different, expected someIdHere actual %@",
                         rev.docId);
    XCTAssertEqualObjects(@"3-750dac460a6cc41e6999f8943b8e603e",
                         rev.revId,
                         @"Revision was different expected 3-750dac460a6cc41e6999f8943b8e603e actual %@",
                         rev.revId);
    
    XCTAssertEqualObjects(body, rev.body, @"Body was different");
    XCTAssertFalse(rev.deleted, @"Document is not marked as deleted");
    XCTAssertEqual([rev.attachments count], (NSUInteger) 1, @"Attachment count is wrong, expected 1 actual %d", [rev.attachments count]);
    XCTAssertEqualObjects(data, [[rev.attachments objectForKey:@"bonsai-boston.jpg"]dataFromAttachmentContent],@"data was not the same");
    
}

- (void)testCreate
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:document
                                                                    error:&error];
    document = [rev copy];
    document.attachments = @{};

    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision: document
                                                                     error:&error];

    XCTAssertNotNil(rev2, @"Updating with an empty attachments array gave nil response");

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];

    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

    document = [rev2 copy];
    document.attachments = @{attachment.name:attachment};
    
    CDTDocumentRevision *rev3 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    XCTAssertNotNil(rev3, @"Updating with a non-empty attachments array gave nil response");

    NSDictionary *attachments = rev3.attachments;
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    CDTSavedAttachment *savedAttachment = [attachments objectForKey:attachmentName];
    XCTAssertEqualObjects(savedAttachment.name, attachmentName, @"Attachment wasn't in document");

    // Check db and fs
    __block NSString *filename = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filename = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filename], @"Attachment file doesn't exist");

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@3, attachmentName, @"image/jpg", @(data.length), @3, @0, @(data.length)],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                                @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

- (void)testCreateWithMutableBodyAndAttachments
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = [dict mutableCopy];
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:document
                                                                    error:&error];
    document = [rev copy];
    document.attachments = @{};
    
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision: document
                                                                     error:&error];
    
    XCTAssertNotNil(rev2, @"Updating with an empty attachments array gave nil response");
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

    document = [rev2 copy];
    document.attachments = [@{attachment.name:attachment} mutableCopy];
    
    CDTDocumentRevision *rev3 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];
    
    XCTAssertNotNil(rev3, @"Updating with a non-empty attachments array gave nil response");
    
    NSDictionary *attachments = rev3.attachments;
    CDTSavedAttachment *savedAttachment = [attachments objectForKey:attachmentName];
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    XCTAssertEqualObjects(savedAttachment.name, attachmentName,
                         @"Attachment wasn't in document");
    
    // Check db and fs
    __block NSString *filename = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filename = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filename], @"Attachment file doesn't exist");
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
                                  @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
                                  @[@3, attachmentName, @"image/jpg", @(data.length), @3, @0, @(data.length)],
                                  ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}


- (void) testUpdatingDocumentRetainsAttachments
{
    NSError *error = nil;

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:document error:&error];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:imageData
                                            name:@"bonsai-boston"
                                            type:@"image/jpg"];
    document = [rev copy];
    document.attachments = @{imgAttachment.name:imgAttachment};
    rev = [self.datastore updateDocumentFromRevision:document error:&error];


    NSDictionary *attachments = rev.attachments;
    CDTSavedAttachment *savedAttachment = [attachments objectForKey:@"bonsai-boston"];
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    XCTAssertEqualObjects(savedAttachment.name, @"bonsai-boston",
                         @"Attachment wasn't in document");

    // Check db and fs
    __block NSString *filename = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filename = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filename], @"Attachment file doesn't exist");

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

- (void) testMultipleAttachments
{
    NSError *error = nil;

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:document error:&error];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];

    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    NSData *txtData = [NSData dataWithContentsOfFile:txtPath];

    // Add the first attachments

    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:imageData
                                            name:@"bonsai-boston"
                                            type:@"image/jpg"];
    CDTAttachment *txtAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:txtData
                                            name:@"lorem"
                                            type:@"text/plain"];

    document = [rev copy];
    document.attachments = @{imgAttachment.name:imgAttachment,txtAttachment.name:txtAttachment};
    rev = [self.datastore updateDocumentFromRevision:document error:&error];
    

    XCTAssertEqual((NSUInteger)2,
                   [[rev attachments ] count],
                   @"Wrong number of attachments");

    // Add a third attachment

    CDTAttachment *txtAttachment2 = [[CDTUnsavedDataAttachment alloc]
                                     initWithData:txtData name:@"lorem2" type:@"text/plain"];
    document = [rev copy];
    NSMutableDictionary *mutableCopy = [document.attachments mutableCopy];
    [mutableCopy setObject:txtAttachment2 forKey:txtAttachment2.name];
    document.attachments = mutableCopy;
    
    rev = [self.datastore updateDocumentFromRevision:document error:&error];

    NSDictionary *attachments = rev.attachments;
    XCTAssertEqual((NSUInteger)3, [attachments count], @"Wrong number of attachments");

    // Confirm each attachment has the correct data

    NSArray *expected = @[@[@"bonsai-boston", imageData],
                          @[@"lorem", txtData],
                          @[@"lorem2", txtData]
                          ];
    for (NSArray *item in expected) {
        NSString *name = item[0];
        NSData *data = item[1];

        NSData *inputMD5 = [self MD5:data];

        CDTAttachment *retrievedAttachment = [rev.attachments objectForKey:name];
        NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
        NSData *retrievedMD5 = [self MD5:attachmentData];

        XCTAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    }

    // Check db and fs
    __block NSString *filenameImage = nil;
    __block NSString *filenameText = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filenameImage = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
        
        data = dataFromHexadecimalString(@"3FF2989BCCF52150BBA806BAE1DB2E0B06AD6F88");
        
        [data getBytes:key.bytes];
        
        filenameText = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filenameImage], @"Attachment file doesn't exist"); // image
    XCTAssertTrue([self attachmentExists:filenameText], @"Attachment file doesn't exist");  // text

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@2, @"lorem", @"text/plain", @(txtData.length), @2, @0, @(txtData.length)],
        @[@3, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@3, @"lorem", @"text/plain", @(txtData.length), @2, @0, @(txtData.length)],
        @[@3, @"lorem2", @"text/plain", @(txtData.length), @3, @0, @(txtData.length)],


        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        NSArray * orderBy = @[@"sequence", @"filename"];
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                               orderBy:orderBy
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

- (void) testAddAttachments
{
    NSError *error = nil;

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = dict;


    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:imageData
                                            name:@"bonsai-boston"
                                            type:@"image/jpg"];
    
    rev.attachments = @{imgAttachment.name:imgAttachment};
    
    CDTDocumentRevision * savedRev = [self.datastore createDocumentFromRevision:rev
                                                                          error:&error];
    
    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    NSData *txtData = [NSData dataWithContentsOfFile:txtPath];
    CDTAttachment *txtAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:txtData name:@"lorem" type:@"text/plain"];
    rev = [savedRev copy];
    NSMutableDictionary *attachments = [rev.attachments mutableCopy];
    [attachments setObject:txtAttachment forKey:txtAttachment.name];
    rev.attachments = attachments;
    [self.datastore updateDocumentFromRevision:rev error:&error];
    
    CDTDocumentRevision *revision = [self.datastore getDocumentWithId:rev.docId
                                                                error:&error];
    XCTAssertEqual((NSUInteger)2, [revision.attachments count],
                   @"Wrong number of attachments");

    for (NSArray *item in @[ @[@"bonsai-boston", imageData], @[@"lorem", txtData] ]) {
        NSString *name = item[0];
        NSData *data = item[1];

        NSData *inputMD5 = [self MD5:data];

        CDTAttachment *retrievedAttachment = [rev.attachments objectForKey:name];

        NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
        NSData *retrievedMD5 = [self MD5:attachmentData];

        XCTAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    }

    // Check db and fs
    __block NSString *filenameImage = nil;
    __block NSString *filenameText = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filenameImage = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
        
        data = dataFromHexadecimalString(@"3FF2989BCCF52150BBA806BAE1DB2E0B06AD6F88");
        
        [data getBytes:key.bytes];
        
        filenameText = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filenameImage], @"Attachment file doesn't exist"); // image
    XCTAssertTrue([self attachmentExists:filenameText], @"Attachment file doesn't exist");  // text

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@1, @"bonsai-boston", @"image/jpg", @(imageData.length), @1, @0, @(imageData.length)],
        @[@2, @"lorem", @"text/plain", @(txtData.length), @2, @0, @(txtData.length)],
        @[@2, @"bonsai-boston", @"image/jpg", @(imageData.length), @1, @0, @(imageData.length)],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                  error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

- (void)testRead
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    

    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:document
                                                                     error:&error];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];

    NSData *inputMD5 = [self MD5:data];

    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:data name:attachmentName type:@"image/jpg"];

    document = [rev1 copy];
    document.attachments = @{imgAttachment.name:imgAttachment};
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    NSDictionary *attachments = rev2.attachments;
    CDTSavedAttachment * savedAttachment = [attachments objectForKey:attachmentName];
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    XCTAssertEqualObjects([savedAttachment name], attachmentName, @"Attachment wasn't in document");

    CDTAttachment *retrievedAttachment = [attachments objectForKey:attachmentName];
    XCTAssertNotNil(retrievedAttachment, @"retrievedAttachment was nil");

    NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
    NSData *retrievedMD5 = [self MD5:attachmentData];

    XCTAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
}

- (void)testUpdate
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    
    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:document
                                                                     error:&error];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];

    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc]
                                    initWithData:imageData
                                            name:attachmentName
                                            type:@"image/jpg"];

    document = [rev1 copy];
    document.attachments = @{imgAttachment.name:imgAttachment};
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    //
    // Replace image with text file
    //
    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    NSData *txtData = [NSData dataWithContentsOfFile:txtPath];
    CDTAttachment *attachment2 = [[CDTUnsavedDataAttachment alloc]
                                  initWithData:txtData
                                            name:attachmentName
                                            type:@"text/plain"];

    NSData *inputMD5 = [self MD5:txtData];

    document = [rev2 copy];
    document.attachments = @{attachment2.name:attachment2};
    CDTDocumentRevision *rev3 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    CDTAttachment *retrievedAttachment = [rev3.attachments objectForKey:attachmentName];
    NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
    NSData *retrievedMD5 = [self MD5:attachmentData];

    XCTAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");

    // Check db and fs

    // Both files will remain until a -compact, even though the
    // image was "overwritten"
    __block NSString *filenameImage = nil;
    __block NSString *filenameText = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filenameImage = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
        
        data = dataFromHexadecimalString(@"3FF2989BCCF52150BBA806BAE1DB2E0B06AD6F88");
        
        [data getBytes:key.bytes];
        
        filenameText = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filenameImage], @"Attachment file doesn't exist"); // image
    XCTAssertTrue([self attachmentExists:filenameText], @"Attachment file doesn't exist");  // text

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, attachmentName, @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@3, attachmentName, @"text/plain", @(txtData.length), @3, @0, @(txtData.length)],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

- (void)testDelete
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    NSData *data;
    NSDictionary *attachments;

    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:document
                                                                     error:&error];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    data = [NSData dataWithContentsOfFile:imagePath];

    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

    document = [rev1 copy];
    document.attachments = @{attachment.name:attachment};
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    attachments = rev2.attachments;
    CDTSavedAttachment *savedAttachment = [attachments objectForKey:attachmentName];
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    XCTAssertEqualObjects(savedAttachment.name, attachmentName, @"Attachment wasn't in document");

    //
    // Delete the attachment we added
    //
    document = [rev2 copy];
    document.attachments = nil;
    CDTDocumentRevision *rev3 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    // rev2 should still have an attachment
    attachments = [self.datastore getDocumentWithId:rev2.docId rev:rev2.revId error:&error]
                    .attachments;
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");

    // whereas rev3 should not
    attachments = rev3.attachments;
    XCTAssertEqual((NSUInteger)0, [attachments count], @"Wrong number of attachments");

    // Check db and fs

    // The file will remain until a -compact, even though the
    // attachment was deleted
    __block NSString *filename = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filename = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filename], @"Attachment file doesn't exist");  // image

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, attachmentName, @"image/jpg", @(data.length), @2, @0, @(data.length)],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

#pragma mark Test CDTUnsavedFileAttachment

- (void) testCDTUnsavedFileAttachment
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = dict;
    
    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:document
                                                                     error:&error];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];

    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    NSData *inputMD5 = [self MD5:data];

    CDTAttachment *imgAttachment = [[CDTUnsavedFileAttachment alloc]
                                    initWithPath:imagePath
                                            name:attachmentName
                                            type:@"image/jpg"];

    document = [rev1 copy];
    document.attachments = @{imgAttachment.name:imgAttachment};
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];

    NSDictionary *attachments = rev2.attachments;
    CDTSavedAttachment * savedAttachment = [attachments objectForKey:attachmentName];
    XCTAssertEqual((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    XCTAssertEqualObjects(savedAttachment.name, attachmentName, @"Attachment wasn't in document");

    CDTAttachment *retrievedAttachment = [attachments objectForKey:attachmentName];

    XCTAssertNotNil(retrievedAttachment, @"retrievedAttachment was nil");

    NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
    NSData *retrievedMD5 = [self MD5:attachmentData];

    XCTAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");

    // Check file exists, but we've checked DB several times so assume okay
    __block NSString *filename = nil;
    [self.dbutil.queue inDatabase:^(FMDatabase *db) {
        NSData *data = dataFromHexadecimalString(@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0");
        
        TDBlobKey key;
        [data getBytes:key.bytes];
        
        filename = [TD_Database filenameForKey:key inBlobFilenamesTableInDatabase:db];
    }];
    
    XCTAssertTrue([self attachmentExists:filename], @"Attachment file doesn't exist");  // image
}

#pragma mark Test some failure modes

- (void) testNilDataPreventsInitAttachment
{
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc]
                                 initWithData:nil
                                         name:@"test_attachment"
                                         type:@"image/jpg"];
    XCTAssertNil(attachment, @"Shouldn't be able to create attachment with nil data");
}

- (void) testBadFilePathPreventsInitAttachment
{
    CDTAttachment *attachment = [[CDTUnsavedFileAttachment alloc]
                                 initWithPath:@"/non_existant"
                                         name:@"test_attachment"
                                         type:@"text/plain"];
    XCTAssertNil(attachment, @"Shouldn't be able to create attachment with bad file path");
}

- (void) testFileDeletedAfterAttachmentCreatedGivesNilStream
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *tempPath = [self tempFileName];

    XCTAssertTrue([fm copyItemAtPath:[bundle pathForResource:@"bonsai-boston" ofType:@"jpg"]
                             toPath:tempPath
                              error:nil],
                 @"File couldn't be copied");

    CDTAttachment *attachment = [[CDTUnsavedFileAttachment alloc]
                                 initWithPath:tempPath
                                         name:@"test_attachment"
                                         type:@"text/plain"];
    
    XCTAssertNotNil(attachment, @"File path should exist");

    XCTAssertTrue([fm removeItemAtPath:tempPath
                                error:nil],
                 @"File couldn't be deleted");

    NSData *attachmentData = [attachment dataFromAttachmentContent];
    XCTAssertNil(attachmentData, @"File deleted, input stream should be nil");

    // Check fs and db -- file shouldn't exist, database should be empty

    XCTAssertTrue([self attachmentsPathIsEmpty], @"Attachments directory wasn't empty");

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (void) testNilAttachmentStream
{
    NSError *error;

    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *mutableRev = [CDTDocumentRevision revision];
    mutableRev.body = dict;
    
    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:mutableRev error:&error];
    
    CDTNullAttachment *attachment = [[CDTNullAttachment alloc] initWithName:@"name"
                                                                       type:@"type"
                                                                       size:100];

    mutableRev = [rev1 copy];
    mutableRev.attachments = @{attachment.name:attachment};
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:mutableRev error:&error];

    // Should fail, we shouldn't get a revision and should get a decent error
    XCTAssertNil(rev2, @"rev2 should be nil");
    XCTAssertNotNil(error, @"error shouldn't have been nil");
    XCTAssertEqual((NSInteger)kTDStatusAttachmentStreamError,
                   error.code,
                   @"Error should be kTDStatusAttachmentStreamError");

    // Database should be empty

    XCTAssertTrue([self attachmentsPathIsEmpty], @"Attachments directory wasn't empty");

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        ];

        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
    }];

}

// Add a good and a bad attachments and check:
// - Document isn't updated
// - Reasonable error
// - Attachments database is not updated with the working attachment.
- (void)testNilAttachmentStreamWithGoodAttachmentStream
{
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentRevision *mutableRev = [CDTDocumentRevision revision];
    mutableRev.body = dict;

    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mutableRev error:nil];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];
    CDTAttachment *nullAttachment = [[CDTNullAttachment alloc] init];
    
    NSError *error = nil;
    mutableRev = [rev copy];
    mutableRev.attachments = @{attachmentName:attachment,@"nullAttachment":nullAttachment};
    
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision:mutableRev error:&error];
    

    
    XCTAssertNil(rev2, @"Updating with broken attachment didn't give null response");
    XCTAssertNotNil(error, @"error shouldn't have been nil");
    XCTAssertEqual((NSInteger)kTDStatusAttachmentStreamError,
                   error.code,
                   @"Error should be kTDStatusAttachmentStreamError");

    [self.dbutil.queue inDatabase:^(FMDatabase *db ) { 
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        
        // Check there's only the first document rev
        NSArray *expectedRows = @[
                                  @[@"sequence"],
                                  @[@1]
                                  ];
        
        NSError *validationError;
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"revs"
                               hasRows:expectedRows
                                 error:&validationError],
                      @"%@",
                      [dc formattedErrors:validationError]);
        
        // Check the attachments table is empty
        expectedRows = @[
                         @[@"sequence"],
                         ];
        XCTAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                       @"%@",
                       [dc formattedErrors:validationError]);
    }];
}

-(void) testCreateDocumentWithaSharedAttachment {
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};

    NSError *error;
    
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

    CDTDocumentRevision *mutableRev = [CDTDocumentRevision revision];
    mutableRev.body = dict;
    mutableRev.attachments=@{attachment.name : attachment};
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:mutableRev  error:&error];
    
    
    XCTAssertNil(error,@"An error occured saving the document");
    XCTAssertNotNil(rev, @"First document was not created");

    mutableRev = [CDTDocumentRevision revision];
    mutableRev.body = dict;
    mutableRev.attachments=rev.attachments;
    
    CDTDocumentRevision *doc2 = [self.datastore createDocumentFromRevision:mutableRev error:&error];
    
    XCTAssertNil(error, @"An error occured saving the document");
    XCTAssertNotNil(doc2, @"New document was nil");
    

}

- (void)testRetriveAttachmentsViaAllDocuments
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = [dict mutableCopy];
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:document
                                                                    error:&error];
    document = [rev copy];
    document.attachments = @{};
    
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision: document
                                                                     error:&error];
    
    XCTAssertNotNil(rev2, @"Updating with an empty attachments array gave nil response");
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

    document = [rev2 copy];
    document.attachments = [@{attachment.name:attachment} mutableCopy];
    
    CDTDocumentRevision *rev3 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];
    
    //attachments have been completed inerted, now attempt to get them via all docs
    
    NSArray * allDocuuments = [self.datastore getAllDocuments];
    
    for(CDTDocumentRevision * revision in allDocuuments){
        XCTAssertTrue([revision.attachments count] == 1, @"Attachment count is %d not 1", [revision.attachments count]);
    }
}

- (void)testRetriveAttachmentsViaAllDocumentsById
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};

    CDTDocumentRevision *document = [CDTDocumentRevision revision];
    document.body = [dict mutableCopy];
    
    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:document
                                                                    error:&error];
    document = [rev copy];
    document.attachments = @{};
    
    CDTDocumentRevision *rev2 = [self.datastore updateDocumentFromRevision: document
                                                                     error:&error];
    
    XCTAssertNotNil(rev2, @"Updating with an empty attachments array gave nil response");
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

    document = [rev2 copy];
    document.attachments = [@{attachment.name:attachment} mutableCopy];
    
    CDTDocumentRevision *rev3 = [self.datastore updateDocumentFromRevision:document
                                                                     error:&error];
    
    //attachments have been completed inerted, now attempt to get them via all docs
    
    NSArray * allDocuuments = [self.datastore getDocumentsWithIds:@[rev.docId]];
    
    XCTAssertTrue([allDocuuments count] == 1,
                 @"Unexpected number of documents 1 expected got %d",
                 [allDocuuments count]);
    
    for(CDTDocumentRevision * revision in allDocuuments){
        XCTAssertTrue([revision.attachments count] == 1, @"Attachment count is %d not 1", [revision.attachments count]);
    }
}


#pragma mark - Utilities

- (NSString*)tempFileName
{
    // Move to a temp file
    NSString *fileName = [NSString stringWithFormat:@"%@_%@",
                          [[NSProcessInfo processInfo] globallyUniqueString],
                          @"file.txt"];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
}

/**
 Create an MD5 string for an NSData instance
 */
- (NSData*)MD5:(NSData*)data
{
    if (nil == data) {
        return nil;
    }

    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];

    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(data.bytes, (CC_LONG)data.length, md5Buffer);

    NSData *md5 = [[NSData alloc] initWithBytes:md5Buffer length:CC_MD5_DIGEST_LENGTH];
    return md5;
}

@end
