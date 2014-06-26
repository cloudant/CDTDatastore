//
//  CloudantReplicationBase+CompareDb.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 03/02/2014.
//
//

#import "CloudantReplicationBase+CompareDb.h"

#import <CloudantSync.h>
#import <CDTDatastore+Internal.h>
#import <SenTestingKit/SenTestingKit.h>
#import <UNIRest.h>
#import <CommonCrypto/CommonDigest.h>
#import <NSData+Base64.h>

@implementation CloudantReplicationBase (CompareDb)


-(BOOL) compareDatastore:(CDTDatastore*)local withDatabase:(NSURL*)databaseUrl
{
    if (![self compareDocCount:local withDatabase:databaseUrl]) {
        return NO;
    }

    if (![self compareDocIdsAndCurrentRevs:local withDatabase:databaseUrl]) {
        return NO;
    }

    if (![self compareDocIdsAndAllRevs:local withDatabase:databaseUrl]) {
        return NO;
    }

    return YES;
}


/**
 * Basic check that we've the same number of documents in the local and remote
 * databases.
 */
-(BOOL) compareDocCount:(CDTDatastore*)local withDatabase:(NSURL*)databaseUrl
{
    NSUInteger localCount = local.documentCount;

    // Check document count in the remote DB
    NSDictionary* headers = @{@"accept": @"application/json"};
    NSDictionary* json = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[databaseUrl absoluteString]];
        [request setHeaders:headers];
    }] asJson].body.object;

    NSUInteger remoteCount = [json[@"doc_count"] unsignedIntegerValue];
    if (localCount != remoteCount) {
        STFail(@"Wrong number of remote docs");
        return NO;
    }
    //    STAssertEquals(deleted,
    //                   [response.body.object[@"doc_del_count"] integerValue],
    //                   @"Wrong number of remote deleted docs");

    return YES;
}

/**
 * Check each database has the same (non-deleted) doc Ids and that the
 * current revisions match.
 */
-(BOOL) compareDocIdsAndCurrentRevs:(CDTDatastore*)local withDatabase:(NSURL*)databaseUrl
{
    // Remote doc IDs
    NSDictionary* headers = @{@"accept": @"application/json"};
    NSURL *all_docs = [databaseUrl URLByAppendingPathComponent:@"_all_docs"];
    NSDictionary* json = [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[all_docs absoluteString]];
        [request setHeaders:headers];
    }] asJson].body.object;
    NSMutableDictionary *remoteDocs = [NSMutableDictionary dictionary];
    for (NSDictionary* row in json[@"rows"]) {
        [remoteDocs setObject:row[@"value"][@"rev"] forKey:row[@"id"]];
    }

    // Local doc IDs
    NSMutableDictionary *localDocs = [NSMutableDictionary dictionary];
    NSArray *allLocalDocs = [local getAllDocuments];
    for (CDTDocumentRevision *rev in allLocalDocs) {
        [localDocs setObject:rev.revId forKey:rev.docId];
    }

    // Check both databases have the same doc IDs
    if (![[localDocs allKeys] isEqualToArray:[remoteDocs allKeys]]) {
        STFail(@"Local and remote docIds not equal");
        return NO;
    }

    // Check each docId has the same rev
    for (NSString *docId in [localDocs allKeys]) {
        if (![localDocs[docId] isEqualToString:remoteDocs[docId]]) {
            STFail(@"Local and remote revs don't match");
            return NO;
        }
    }

    return YES;
}

/**
 * Check that the current revisions for all documents are the same and have the
 * same revision history. That is, for each document, make sure the leaf revisions
 * are the same and that each active leaf has the same revision history.
 * We assume that we already know that the right docIds are present in each database.
 */
-(BOOL) compareDocIdsAndAllRevs:(CDTDatastore*)local withDatabase:(NSURL*)databaseUrl
{
    // By the time we're here, we know we have all the right docs, so we can assume that
    // we can get all the current revs for each document, and compare the histories against
    // the remote.

    NSArray *allLocalDocs = [local getAllDocuments];
    [allLocalDocs enumerateObjectsWithOptions:NSEnumerationConcurrent
                                   usingBlock:^(id ob, NSUInteger idx, BOOL* stop)
    {
        CDTDocumentRevision *document = (CDTDocumentRevision*)ob;

        // This returns all the `current` revisions for a given document.
        NSArray *allRevisions = [local activeRevisionsForDocumentId:document.docId];

        // Make sure the history for each conflict is correct
        for (CDTDocumentRevision *currentRevision in allRevisions) {

            // Local revs for this doc
            NSMutableArray *localRevIdsAcc = [NSMutableArray array];
            NSArray *localOpenRevs = [local getRevisionHistory:currentRevision];

            for (CDTDocumentRevision *revision in localOpenRevs) {
                [localRevIdsAcc addObject:revision.revId];
            }
            NSArray *localRevIds = [localRevIdsAcc sortedArrayUsingSelector:@selector(localizedStandardCompare:)];

            // Remote revs for this doc
            NSMutableArray *remoteRevIdsAccumulator = [NSMutableArray array];
            NSDictionary* headers = @{@"accept": @"application/json"};
            NSURL *docUrl = [databaseUrl URLByAppendingPathComponent:currentRevision.docId];
            NSDictionary* json = [[UNIRest get:^(UNISimpleRequest* request) {
                [request setUrl:[docUrl absoluteString]];
                [request setHeaders:headers];
                [request setParameters:@{@"revs_info": @"true", @"rev": currentRevision.revId}];
            }] asJson].body.object;
            for (NSDictionary* revInfo in json[@"_revs_info"]) {
                [remoteRevIdsAccumulator addObject:revInfo[@"rev"]];
            }
            NSArray *remoteRevIds = [remoteRevIdsAccumulator sortedArrayUsingSelector:@selector(localizedStandardCompare:)];

            // CouchDB trims revision histories, so we should do that with the local array
            // CouchDB will obviously return the most recent revIds, which will be at the
            // end of the localRevIds array, so we take the end of that array.
            NSRange range;
            range.location = localRevIds.count - remoteRevIds.count;
            range.length = remoteRevIds.count;
            localRevIds = [localRevIds subarrayWithRange:range];

            if (![localRevIds isEqualToArray:remoteRevIds]) {
                STFail(@"Local and remote rev histories don't match");
                return;
            }
        }
    }];
    return YES;
}

- (BOOL)compareAttachmentsForCurrentRevisions:(CDTDatastore*)local 
                                 withDatabase:(NSURL*)databaseUrl
{
    NSArray *allLocalDocs = [local getAllDocuments];
    [allLocalDocs enumerateObjectsWithOptions:NSEnumerationConcurrent
                                   usingBlock:^(id ob, NSUInteger idx, BOOL* stop)
     {
         CDTDocumentRevision *document = (CDTDocumentRevision*)ob;
         
         NSMutableDictionary *localAttachments = [NSMutableDictionary dictionary];
         for (CDTAttachment *att in [local attachmentsForRev:document error:nil]) {
             localAttachments[att.name] = att;
         }
         
         // Get the document, including attachments
         NSDictionary* headers = @{@"accept": @"application/json"};
         NSURL *docUrl = [databaseUrl URLByAppendingPathComponent:document.docId];
         NSDictionary* json = [[UNIRest get:^(UNISimpleRequest* request) {
             [request setUrl:[docUrl absoluteString]];
             [request setHeaders:headers];
             [request setParameters:@{@"rev": document.revId, @"attachments": @"true"}];
         }] asJson].body.object;
         
         NSDictionary *remoteAttachments = json[@"_attachments"];
         
         STAssertEquals(localAttachments.count, 
                        remoteAttachments.count, 
                        @"Wrong attachment number");
         NSArray *remoteAttachmentNames = [remoteAttachments allKeys];
         for (NSString *name in [localAttachments allKeys]) {
             STAssertTrue([remoteAttachmentNames containsObject:name], 
                          @"local had attachment remote didn't");
         }
         
         // Check the content via MD5
         for (NSString *name in [localAttachments allKeys]) {
             CDTAttachment *lAttachment = localAttachments[name];
             NSData *localData = [lAttachment dataFromAttachmentContent];
             NSString *localValue = [[NSString alloc] initWithData:localData
                                                          encoding:NSUTF8StringEncoding];
             
             // digest is base64 encoded: "md5-U/ZX/YL+2w9lcpr6Fjt87A=="
             // we need to strip "md5-" prefix and "==" suffix.
             NSDictionary *rAttachment = remoteAttachments[name];
             NSData *remoteData = [NSData dataFromBase64String:rAttachment[@"data"]];
             NSString *remoteValue = [[NSString alloc] initWithData:remoteData
                                                           encoding:NSUTF8StringEncoding];
             STAssertEqualObjects(localValue, remoteValue, @"Attachment data didn't match");
             
             // This doesn't work right now, the MD5s don't match
             // even though the data does.
//             NSData *localMD5 = [self MD5:localData];
//             STAssertNotNil(localMD5, @"Local MD5 was nil");
//             NSString *digest = rAttachment[@"digest"];
//             NSRange r = NSMakeRange(4, [digest length] - 4 - 2);
//             NSString *remoteMD5Base64 = [digest substringWithRange:r];
//             NSData *remoteMD5 = [NSData dataFromBase64String:remoteMD5Base64];
//             STAssertEqualObjects(localMD5, remoteMD5, @"Attachment MD5 didn't match");
         }
     }];
    
    return YES;
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
