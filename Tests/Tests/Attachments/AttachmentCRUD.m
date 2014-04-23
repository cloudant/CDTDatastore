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

#import "CloudantSyncTests.h"
#import "DBQueryUtils.h"
#import "AmazonMD5Util.h"

@interface AttachmentCRUD : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) DBQueryUtils *dbutil;

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

- (void)testCreate
{
    NSError *error = nil;
    NSString *attachmentName = @"test_an_attachment";
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithBody:body
                                                                error:&error];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[]
                                                           forRev:rev];
    
    STAssertNotNil(rev2, @"Updating with an empty attachments array gave nil response");
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [CDTAttachment attachmentWithData:data
                                                             name:attachmentName 
                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev3 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev2];
    
    STAssertNotNil(rev3, @"Updating with a non-empty attachments array gave nil response");
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev3];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");    
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
    
    CDTAttachment *imgAttachment = [CDTAttachment attachmentWithData:imageData
                                                                name:@"bonsai-boston" 
                                                                type:@"image/jpg"];
    CDTAttachment *txtAttachment = [CDTAttachment attachmentWithData:txtData
                                                                name:@"lorem" 
                                                                type:@"text/plain"];
    
    rev = [self.datastore updateAttachments:@[imgAttachment, txtAttachment]
                                     forRev:rev];
    
    STAssertNotNil(rev, @"Updating with a non-empty attachments array gave nil response");
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev];
    STAssertEquals((NSUInteger)2, [attachments count], @"Wrong number of attachments");
    
    for (NSArray *item in @[ @[@"bonsai-boston", imageData], @[@"lorem", txtData] ]) {
        NSString *name = item[0];
        NSData *data = item[1];
        
        NSData *inputMD5 = [self MD5:data];
        
        CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:name
                                                                      forRev:rev];
        
        NSInputStream *stream = [retrievedAttachment getInputStream];
        [stream open];
        NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
        [stream close];
        
        STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
    }
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
    
    CDTAttachment *attachment = [CDTAttachment attachmentWithData:data
                                                             name:attachmentName 
                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev1];
    
    NSArray *attachments = [self.datastore attachmentsForRev:rev2];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");  
    
    CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:attachmentName
                                                                  forRev:rev2];
    
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
    NSData *data;
    
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body
                                                                 error:&error];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
    data = [NSData dataWithContentsOfFile:imagePath];
    
    CDTAttachment *attachment = [CDTAttachment attachmentWithData:data
                                                             name:attachmentName 
                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev1];
    
    //
    // Replace image with text file
    //
    NSString *txtPath = [bundle pathForResource:@"lorem" ofType:@"txt"];
    data = [NSData dataWithContentsOfFile:txtPath];
    
    CDTAttachment *attachment2 = [CDTAttachment attachmentWithData:data
                                                             name:attachmentName 
                                                              type:@"text/plain"];
    
    NSData *inputMD5 = [self MD5:data];
    
    CDTDocumentRevision *rev3 = [self.datastore updateAttachments:@[attachment2]
                                                           forRev:rev2];  
    
    CDTAttachment *retrievedAttachment = [self.datastore attachmentNamed:attachmentName
                                                                  forRev:rev3];
    
    NSInputStream *stream = [retrievedAttachment getInputStream];
    [stream open];
    NSData *retrievedMD5 = [AmazonMD5Util base64md5FromStream:stream];
    [stream close];
    
    STAssertEqualObjects(retrievedMD5, inputMD5, @"Received MD5s");
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
    
    CDTAttachment *attachment = [CDTAttachment attachmentWithData:data
                                                             name:attachmentName 
                                                             type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.datastore updateAttachments:@[attachment]
                                                           forRev:rev1];
    
    attachments = [self.datastore attachmentsForRev:rev2];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    STAssertEqualObjects([attachments[0] name], attachmentName, @"Attachment wasn't in document");
    
    //
    // Delete the attachment we added
    //
    
    CDTDocumentRevision *rev3 = [self.datastore removeAttachments:@[attachmentName]
                                                          fromRev:rev2];
    
    // rev2 should still have an attachment
    attachments = [self.datastore attachmentsForRev:rev2];
    STAssertEquals((NSUInteger)1, [attachments count], @"Wrong number of attachments");
    
    // whereas rev3 should not
    attachments = [self.datastore attachmentsForRev:rev3];
    STAssertEquals((NSUInteger)0, [attachments count], @"Wrong number of attachments");
}

#pragma mark - Utilities

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
    
    // Convert unsigned char buffer to NSString of hex values
//    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
//    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
//        [output appendFormat:@"%02x",md5Buffer[i]];
//    
//    return output;
}

@end
