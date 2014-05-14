//
//  AttachmentCRUD.m
//  Tests
//
//  Created by Michael Rhodes on 25/03/2014.
//
//

#import <SenTestingKit/SenTestingKit.h>
#import <CommonCrypto/CommonDigest.h>

#import <CloudantSync.h>
#import <MRDatabaseContentChecker.h>

#import "CloudantSyncTests.h"
#import "DBQueryUtils.h"
#import "AmazonMD5Util.h"

#import "CDTAttachment.h"

@interface AttachmentCRUD : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) DBQueryUtils *dbutil;

@end

/** Attachment which returns nil for its input stream */
@interface CDTNullAttachment : CDTAttachment

@end

@implementation CDTNullAttachment

-(NSInputStream *)getInputStream { return nil; }

@end


@implementation AttachmentCRUD

- (void)setUp
{
    [super setUp];
    
    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    self.dbutil =[[DBQueryUtils alloc] initWithDbPath:[self pathForDBName:self.datastore.name]];
    
    STAssertNotNil(self.datastore, @"datastore is nil");
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
    
    NSString *attachmentsPath = [self.factoryPath stringByAppendingPathComponent:@"test attachments"];
    NSString *attachmentPath = [attachmentsPath stringByAppendingPathComponent:filename];
    
    BOOL isDirectory;
    BOOL attachmentExists = [fm fileExistsAtPath:attachmentPath isDirectory:&isDirectory];
    return attachmentExists && !isDirectory;
}

- (BOOL)attachmentsPathIsEmpty
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *attachmentsPath = [self.factoryPath stringByAppendingPathComponent:@"test attachments"];
    NSArray *files = [fm contentsOfDirectoryAtPath:attachmentsPath error:nil];
    return ((files != nil) && files.count == 0);
}

#pragma mark Tests

- (void)testCreate
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:body
                                                                error:&error];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[]
                                                           forRev:rev
                                                            error:nil];
    
    STAssertNotNil(rev2, @"Updating with an empty attachments array gave nil response");
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName 
                                                                          type:@"image/jpg"];
    
    CDTDocumentRevision *rev3 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev2
                                                            error:nil];
    
    STAssertNotNil(rev3, @"Updating with a non-empty attachments array gave nil response");
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev3
                                                       error:nil];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");
    
    // Check db and fs
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, attachmentName, @"image/jpg", @(data.length), @2, @0, @(data.length)],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
    
    
}

-(void) testUpdatingDocumentRetainsAttachments
{
    NSError *error = nil;
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:body
                                                                error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:imageData
                                                                             name:@"bonsai-boston" 
                                                                             type:@"image/jpg"];
    rev = [self.datastore updateAttachments:@[imgAttachment]
                                     forRev:rev
                                      error:nil];
    
    rev = [self.datastore updateDocumentWithId:rev.docId
                                       prevRev:rev.revId
                                          body:body
                                         error:&error];
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev
                                                       error:nil];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], @"bonsai-boston", @"Attachment wasn't in document"); 
    
    // Check db and fs
    
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@3, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

-(void) testMultipleAttachments
{
    NSError *error = nil;
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:body
                                                                error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    
    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    NSData *txtData = [NSData dataWithContentsOfFile:txtPath];
    
    // Add the first attachments
    
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:imageData
                                                                             name:@"bonsai-boston" 
                                                                             type:@"image/jpg"];
    CDTAttachment *txtAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:txtData
                                                                             name:@"lorem"  
                                                                             type:@"text/plain"];
    
    rev = [self.datastore updateAttachments:@[imgAttachment, txtAttachment]
                                     forRev:rev
                                      error:nil];
    STAssertEquals((NSUInteger)2, 
                   [[self.datastore attachmentsForRev:rev error:nil] count], 
                   @"Wrong number of attachments");
    
    // Add a third attachment
    
    CDTAttachment *txtAttachment2 = [[CDTUnsavedDataAttachment alloc] initWithData:txtData
                                                                              name:@"lorem2"  
                                                                              type:@"text/plain"];
    rev = [self.datastore updateAttachments:@[txtAttachment2]
                                     forRev:rev
                                      error:nil];
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev
                                                       error:nil];
    STAssertEquals((NSUInteger)3, [attachments count], @"Wrong number of attachments");
    
    // Confirm each attachment has the correct data
    
    NSArray *expected = @[@[@"bonsai-boston", imageData], 
                          @[@"lorem", txtData], 
                          @[@"lorem2", txtData] 
                          ];
    for (NSArray *item in expected) {
        NSString *name = item[0];
        NSData *data = item[1];
        
        NSData *inputMD5 = [self MD5:data];
        
        CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:name
                                                                      forRev:rev
                                                                       error:nil];
        
        NSInputStream *stream = [retrievedAttachment getInputStream];
        [stream open];
        NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
        [stream close];
        
        STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    }
    
    // Check db and fs
    
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");  // image
    STAssertTrue([self attachmentExists:@"3FF2989BCCF52150BBA806BAE1DB2E0B06AD6F88.blob"],
                 @"Attachment file doesn't exist");  // text
    
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
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

-(void) testAddAttachments
{
    NSError *error = nil;
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:body
                                                                error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:imageData
                                                                             name:@"bonsai-boston" 
                                                                             type:@"image/jpg"];
    rev = [self.datastore updateAttachments:@[imgAttachment]
                                     forRev:rev
                                      error:nil];
    
    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    NSData *txtData = [NSData dataWithContentsOfFile:txtPath];
    CDTAttachment *txtAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:txtData
                                                                             name:@"lorem"  
                                                                             type:@"text/plain"];
    rev = [self.datastore updateAttachments:@[txtAttachment]
                                     forRev:rev
                                      error:nil];
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev
                                                       error:nil];
    STAssertEquals((NSUInteger)2, [attachments count], @"Wrong number of attachments");
    
    for (NSArray *item in @[ @[@"bonsai-boston", imageData], @[@"lorem", txtData] ]) {
        NSString *name = item[0];
        NSData *data = item[1];
        
        NSData *inputMD5 = [self MD5:data];
        
        CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:name
                                                                      forRev:rev
                                                                       error:nil];
        
        NSInputStream *stream = [retrievedAttachment getInputStream];
        [stream open];
        NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
        [stream close];
        
        STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    }
    
    // Check db and fs
    
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");  // image
    STAssertTrue([self attachmentExists:@"3FF2989BCCF52150BBA806BAE1DB2E0B06AD6F88.blob"],
                 @"Attachment file doesn't exist");  // text
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@3, @"bonsai-boston", @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@3, @"lorem", @"text/plain", @(txtData.length), @3, @0, @(txtData.length)],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

- (void)testRead
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body
                                                                error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    
    NSData *inputMD5 = [self MD5:data];
    
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                             name:attachmentName 
                                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[imgAttachment]
                                                           forRev:rev1
                                                            error:nil];
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev2
                                                       error:nil];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");  
    
    CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:attachmentName
                                                                  forRev:rev2
                                                                   error:nil];
    
    STAssertNotNil(retrievedAttachment, @"retrievedAttachment was nil");
    
    NSInputStream *stream = [retrievedAttachment getInputStream];
    [stream open];
    NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
    [stream close];
    
    STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
}

- (void)testUpdate
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body
                                                                 error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *imgAttachment = [[CDTUnsavedDataAttachment alloc] initWithData:imageData
                                                                             name:attachmentName 
                                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[imgAttachment]
                                                           forRev:rev1
                                                            error:nil];
    
    //
    // Replace image with text file
    //
    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    NSData *txtData = [NSData dataWithContentsOfFile:txtPath];
    CDTAttachment *attachment2 = [[CDTUnsavedDataAttachment alloc] initWithData:txtData
                                                                           name:attachmentName 
                                                                           type:@"text/plain"];
    
    NSData *inputMD5 = [self MD5:txtData];
    
    CDTDocumentRevision *rev3 = [self.datastore updateAttachments:@[attachment2]
                                                           forRev:rev2
                                                            error:nil];  
    
    CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:attachmentName
                                                                  forRev:rev3
                                                                   error:nil];
    
    NSInputStream *stream = [retrievedAttachment getInputStream];
    [stream open];
    NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
    [stream close];
    
    STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    
    // Check db and fs
    
    // Both files will remain until a -compact, even though the
    // image was "overwritten"
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");  // image
    STAssertTrue([self attachmentExists:@"3FF2989BCCF52150BBA806BAE1DB2E0B06AD6F88.blob"],
                 @"Attachment file doesn't exist");  // text
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, attachmentName, @"image/jpg", @(imageData.length), @2, @0, @(imageData.length)],
        @[@3, attachmentName, @"text/plain", @(txtData.length), @3, @0, @(txtData.length)],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

- (void)testDelete
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    NSData *data;
    NSArray *attachments;
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body
                                                                 error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName 
                                                                          type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev1
                                                            error:nil];
    
    attachments = [self.datastore attachmentsForRev:rev2
                                              error:nil];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");
    
    //
    // Delete the attachment we added
    //
    
    CDTDocumentRevision *rev3 = [self.datastore removeAttachments:@[attachmentName]
                                                          fromRev:rev2
                                                            error:nil];
    
    // rev2 should still have an attachment
    attachments = [self.datastore attachmentsForRev:rev2
                                              error:nil];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    
    // whereas rev3 should not
    attachments = [self.datastore attachmentsForRev:rev3
                                              error:nil];
    STAssertEquals((NSUInteger)0, [attachments count], @"Wrong number of attachments");
    
    // Check db and fs
    
    // The file will remain until a -compact, even though the
    // attachment was deleted
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");  // image
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        @[@2, attachmentName, @"image/jpg", @(data.length), @2, @0, @(data.length)],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

#pragma mark Test CDTUnsavedFileAttachment

-(void) testCDTUnsavedFileAttachment
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body
                                                                 error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    NSData *inputMD5 = [self MD5:data];
    
    CDTAttachment *imgAttachment = [[CDTUnsavedFileAttachment alloc] initWithPath:imagePath
                                                                             name:attachmentName
                                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[imgAttachment]
                                                           forRev:rev1
                                                            error:nil];
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev2
                                                       error:nil];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");  
    
    CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:attachmentName
                                                                  forRev:rev2
                                                                   error:nil];
    
    STAssertNotNil(retrievedAttachment, @"retrievedAttachment was nil");
    
    NSInputStream *stream = [retrievedAttachment getInputStream];
    [stream open];
    NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
    [stream close];
    
    STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    
    // Check file exists, but we've checked DB several times so assume okay
    STAssertTrue([self attachmentExists:@"D55F9AC778BAF2256FA4DE87AAC61F590EBE66E0.blob"],
                 @"Attachment file doesn't exist");  // image
}

#pragma mark Test some failure modes

-(void) testNilDataPreventsInitAttachment
{
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:nil
                                                                          name:@"test_attachment" 
                                                                          type:@"image/jpg"];
    STAssertNil(attachment, @"Shouldn't be able to create attachment with nil data");
}

-(void) testBadFilePathPreventsInitAttachment
{
    CDTAttachment *attachment = [[CDTUnsavedFileAttachment alloc] initWithPath:@"/non_existant"
                                                                          name:@"test_attachment"
                                                                          type:@"text/plain"];
    STAssertNil(attachment, @"Shouldn't be able to create attachment with bad file path");
}

-(void) testFileDeletedAfterAttachmentCreatedGivesNilStream
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *tempPath = [self tempFileName];
    
    STAssertTrue([fm copyItemAtPath:[bundle pathForResource:@"bonsai-boston" ofType:@"jpg"]
                             toPath:tempPath
                              error:nil],
                 @"File couldn't be copied");
    
    CDTAttachment *attachment = [[CDTUnsavedFileAttachment alloc] initWithPath:tempPath
                                                                          name:@"test_attachment"
                                                                          type:@"text/plain"];
    STAssertNotNil(attachment, @"File path should exist");
    
    STAssertTrue([fm removeItemAtPath:tempPath
                                error:nil],
                 @"File couldn't be deleted");
    
    STAssertNil([attachment getInputStream], @"File deleted, input stream should be nil");
    
    // Check fs and db -- file shouldn't exist, database should be empty
    
    STAssertTrue([self attachmentsPathIsEmpty], @"Attachments directory wasn't empty");
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
}

-(void) testNilAttachmentStream
{
    NSError *error;
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body
                                                                 error:&error];
    
    CDTNullAttachment *attachment = [[CDTNullAttachment alloc] initWithName:@"name"
                                                                       type:@"type"
                                                                       size:100];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev1
                                                            error:&error];
    
    // Should fail, we shouldn't get a revision and should get a decent error
    STAssertNil(rev2, @"rev2 should be nil");
    STAssertNotNil(error, @"error shouldn't have been nil");
    STAssertEquals((NSInteger)kTDStatusAttachmentStreamError, 
                   error.code, 
                   @"Error should be kTDStatusAttachmentStreamError");
    
    // Database should be empty
    
    STAssertTrue([self attachmentsPathIsEmpty], @"Attachments directory wasn't empty");
    
    [self.dbutil.queue inDatabase:^(FMDatabase *db ) {
        NSArray *expectedRows = @[
        @[@"sequence", @"filename", @"type", @"length", @"revpos", @"encoding", @"encoded_length"],
        ];
        
        MRDatabaseContentChecker *dc = [[MRDatabaseContentChecker alloc] init];
        NSError *validationError;
        STAssertTrue([dc checkDatabase:db
                                 table:@"attachments"
                               hasRows:expectedRows
                                 error:&validationError],
                     [dc formattedErrors:validationError]);
    }];
    
}

#pragma mark - Utilities

-(NSString*)tempFileName
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
