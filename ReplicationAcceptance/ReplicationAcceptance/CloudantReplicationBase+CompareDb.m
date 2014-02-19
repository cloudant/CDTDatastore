//
//  CloudantReplicationBase+CompareDb.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 03/02/2014.
//
//

#import "CloudantReplicationBase+CompareDb.h"

#import <CloudantSync.h>
#import <SenTestingKit/SenTestingKit.h>
#import <UNIRest.h>

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
        NSArray *allRevisions = [local conflictsForDocument:document];

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

@end
