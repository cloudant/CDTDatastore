//
//  ReplicationAcceptance.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import <SenTestingKit/SenTestingKit.h>

#import <CloudantSync.h>

#import "CloudantReplicationBase.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTDocumentBody.h"
#import "CDTDocumentRevision.h"

@interface ReplicationAcceptance : CloudantReplicationBase

@property (nonatomic,strong) CDTDatastore *datastore;

@end

@implementation ReplicationAcceptance


- (void)setUp
{
    [super setUp];

    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];

    STAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    // Tear-down code here.

    self.datastore = nil;

    [super tearDown];
}


-(void)testPush100kDocuments
{
    NSError *error;
    NSUInteger n_docs = 1000;

    // Create a bunch of documents
    NSLog(@"Creating documents...");
    for (long i = 1; i < n_docs+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%li", i];
        NSDictionary *dict = @{@"hello": @"world"};
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
        CDTDocumentRevision *rev = [self.datastore createDocumentWithId:docId
                                                              body:body
                                                             error:&error];
        STAssertNil(error, @"Error creating docs: %@", error);
        STAssertNotNil(rev, @"Error creating docs: rev was nil, but so was error");

        if (i % 1000 == 0) {
            NSLog(@" -> %li documents created", i);
        }
    }
    STAssertEquals(self.datastore.documentCount, n_docs, @"Incorrect number of documents created");
}


@end
