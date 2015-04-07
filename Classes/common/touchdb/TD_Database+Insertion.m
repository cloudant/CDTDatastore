//
//  TD_Database+Insertion.m
//  TouchDB
//
//  Created by Jens Alfke on 12/27/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.

#import "TD_Database+Insertion.h"
#import "TD_Database+Attachments.h"
#import "TD_Revision.h"
#import "TDCanonicalJSON.h"
#import "TD_Attachment.h"
#import "TDInternal.h"
#import "TDMisc.h"
#import "Test.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"

#import "CDTLogging.h"

#ifdef GNUSTEP
#import <openssl/sha.h>
#else
#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>
#endif

NSString* const TD_DatabaseChangeNotification = @"TD_DatabaseChange";

@interface TD_ValidationContext : NSObject <TD_ValidationContext> {
   @private
    TD_Database* _db;
    TD_Revision* _currentRevision, *_newRevision;
    TDStatus _errorType;
    NSString* _errorMessage;
    NSArray* _changedKeys;
}
- (id)initWithDatabase:(TD_Database*)db
              revision:(TD_Revision*)currentRevision
           newRevision:(TD_Revision*)newRevision;
@property (readonly) TD_Revision* currentRevision;
@property TDStatus errorType;
@property (copy) NSString* errorMessage;
@end

@implementation TD_Database (Insertion)

#pragma mark - DOCUMENT & REV IDS:

+ (BOOL)isValidDocumentID:(NSString*)str
{
    // http://wiki.apache.org/couchdb/HTTP_Document_API#Documents
    if (str.length == 0) return NO;
    if ([str characterAtIndex:0] == '_') return [str hasPrefix:@"_design/"];
    return YES;
    // "_local/*" is not a valid document ID. Local docs have their own API and shouldn't get here.
}

/** Generates a new document ID at random. */
+ (NSString*)generateDocumentID { return TDCreateUUID(); }

/** Given an existing revision ID, generates an ID for the next revision.
    Returns nil if prevID is invalid. */
- (NSString*)generateIDForRevision:(TD_Revision*)rev
                          withJSON:(NSData*)json
                       attachments:(NSDictionary*)attachments
                            prevID:(NSString*)prevID
{
    // Revision IDs have a generation count, a hyphen, and a hex digest.
    unsigned generation = 0;
    if (prevID) {
        generation = [TD_Revision generationFromRevID:prevID];
        if (generation == 0) return nil;
    }

    // Generate a digest for this revision based on the previous revision ID, document JSON,
    // and attachment digests. This doesn't need to be secure; we just need to ensure that this
    // code consistently generates the same ID given equivalent revisions.
    MD5_CTX ctx;
    unsigned char digestBytes[MD5_DIGEST_LENGTH];
    MD5_Init(&ctx);

    NSData* prevIDUTF8 = [prevID dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger length = prevIDUTF8.length;
    if (length > 0xFF) return nil;
    uint8_t lengthByte = length & 0xFF;
    MD5_Update(&ctx, &lengthByte, 1);  // prefix with length byte
    if (length > 0) MD5_Update(&ctx, prevIDUTF8.bytes, length);

    uint8_t deletedByte = rev.deleted != NO;
    MD5_Update(&ctx, &deletedByte, 1);

    for (NSString* attName in [attachments.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        TD_Attachment* attachment = attachments[attName];
        MD5_Update(&ctx, &attachment->blobKey, sizeof(attachment->blobKey));
    }

    MD5_Update(&ctx, json.bytes, json.length);

    MD5_Final(digestBytes, &ctx);
    NSString* digest = TDHexFromBytes(digestBytes, sizeof(digestBytes));
    return [NSString stringWithFormat:@"%u-%@", generation + 1, digest];
}

/**
 * Adds a new document ID to the 'docs' table.
 * Must be called from within an FMDatabaseQueue block */
- (SInt64)insertDocumentID:(NSString*)docID inDatabase:(FMDatabase*)db
{
    Assert([TD_Database isValidDocumentID:docID]);  // this should be caught before I get here

    if (![db executeUpdate:@"INSERT INTO docs (docid) VALUES (?)", docID]) {
        return -1;
    }
    return db.lastInsertRowId;
}

/** Extracts the history of revision IDs (in reverse chronological order) from the _revisions key */
+ (NSArray*)parseCouchDBRevisionHistory:(NSDictionary*)docProperties
{
    NSDictionary* revisions = $castIf(NSDictionary, docProperties[@"_revisions"]);
    if (!revisions) return nil;
    // Extract the history, expanding the numeric prefixes:
    NSArray* revIDs = $castIf(NSArray, revisions[@"ids"]);
    __block int start = [$castIf(NSNumber, revisions[@"start"]) intValue];
    if (start) revIDs = [revIDs my_map:^(id revID) { return $sprintf(@"%d-%@", start--, revID); }];
    return revIDs;
}

#pragma mark - INSERTION:

/** Returns the JSON to be stored into the 'json' column for a given TD_Revision.
    This has all the special keys like "_id" stripped out. */
- (NSData*)encodeDocumentJSON:(TD_Revision*)rev
{
    static NSSet* sSpecialKeysToRemove, *sSpecialKeysToLeave;
    if (!sSpecialKeysToRemove) {
        sSpecialKeysToRemove =
            [[NSSet alloc] initWithObjects:@"_id", @"_rev", @"_attachments", @"_deleted",
                                           @"_revisions", @"_revs_info", @"_conflicts",
                                           @"_deleted_conflicts", @"_local_seq", nil];
        sSpecialKeysToLeave =
            [[NSSet alloc] initWithObjects:@"_replication_id", @"_replication_state",
                                           @"_replication_state_time", @"_replication_stats", nil];
    }

    NSDictionary* origProps = rev.properties;
    if (!origProps) return nil;

    // Don't leave in any "_"-prefixed keys except for the ones in sSpecialKeysToLeave.
    // Keys in sSpecialKeysToIgnore (_id, _rev, ...) are left out, any others trigger an error.
    NSMutableDictionary* properties =
        [[NSMutableDictionary alloc] initWithCapacity:origProps.count];
    for (NSString* key in origProps) {
        if (![key hasPrefix:@"_"] || [sSpecialKeysToLeave member:key]) {
            properties[key] = origProps[key];
        } else if (![sSpecialKeysToRemove member:key]) {
            CDTLogInfo(CDTDATASTORE_LOG_CONTEXT,
                    @"TD_Database: Invalid top-level key '%@' in document to be inserted", key);
            return nil;
        }
    }

    // Create canonical JSON -- this is important, because the JSON data returned here will be used
    // to create the new revision ID, and we need to guarantee that equivalent revision bodies
    // result in equal revision IDs.
    NSData* json = [TDCanonicalJSON canonicalData:properties];
    return json;
}

- (TD_Revision*)winnerWithDocID:(SInt64)docNumericID
                      oldWinner:(NSString*)oldWinningRevID
                     oldDeleted:(BOOL)oldWinnerWasDeletion
                         newRev:(TD_Revision*)newRev
                       database:(FMDatabase*)db
{
    if (!oldWinningRevID) return newRev;
    NSString* newRevID = newRev.revID;
    if (!newRev.deleted) {
        if (oldWinnerWasDeletion || TDCompareRevIDs(newRevID, oldWinningRevID) > 0)
            return newRev;  // this is now the winning live revision
    } else if (oldWinnerWasDeletion) {
        if (TDCompareRevIDs(newRevID, oldWinningRevID) > 0)
            return newRev;  // doc still deleted, but this beats previous deletion rev
    } else {
        // Doc was alive. How does this deletion affect the winning rev ID?
        BOOL deleted;
        NSString* winningRevID =
            [self winningRevIDOfDocNumericID:docNumericID isDeleted:&deleted database:db];
        if (!$equal(winningRevID, oldWinningRevID)) {
            if ($equal(winningRevID, newRev.revID))
                return newRev;
            else {
                TD_Revision* winningRev =
                    [[TD_Revision alloc] initWithDocID:newRev.docID revID:winningRevID deleted:NO];
                return winningRev;
            }
        }
    }
    return nil;  // no change
}

/** Posts a local NSNotification of a new revision of a document. */
- (void)notifyChange:(TD_Revision*)rev source:(NSURL*)source winningRev:(TD_Revision*)winningRev
{
    NSDictionary* userInfo =
        $dict({ @"rev", rev }, { @"source", source }, { @"winner", winningRev });
    [[NSNotificationCenter defaultCenter] postNotificationName:TD_DatabaseChangeNotification
                                                        object:self
                                                      userInfo:userInfo];
}

// Raw row insertion. Returns new sequence, or 0 on error
- (SequenceNumber)insertRevision:(TD_Revision*)rev
                    docNumericID:(SInt64)docNumericID
                  parentSequence:(SequenceNumber)parentSequence
                         current:(BOOL)current
                            JSON:(NSData*)json
                        database:(FMDatabase*)db
{
    if (![db executeUpdate:@"INSERT INTO revs (doc_id, revid, parent, current, deleted, json) "
                            "VALUES (?, ?, ?, ?, ?, ?)",
                           @(docNumericID), rev.revID, (parentSequence ? @(parentSequence) : nil),
                           @(current), @(rev.deleted), json]) {
        return 0;
    }
    return rev.sequence = db.lastInsertRowId;
}

/** Public method to add a new revision of a document. */
- (TD_Revision*)putRevision:(TD_Revision*)rev
             prevRevisionID:(NSString*)prevRevID  // rev ID being replaced, or nil if an insert
                     status:(TDStatus*)outStatus
{
    return [self putRevision:rev prevRevisionID:prevRevID allowConflict:NO status:outStatus];
}

/**
 Public method that should be used when you wish to make multiple putRevisions within a single
 database transation via TD_Database -inTransaction:
 */
- (TD_Revision*)putRevision:(TD_Revision*)rev
             prevRevisionID:(NSString*)previousRevID
              allowConflict:(BOOL)allowConflict
                     status:(TDStatus*)outStatus
                   database:(FMDatabase*)db
{
    TD_Revision* winningRev = nil;
    return [self putRevision:rev
              prevRevisionID:previousRevID
               allowConflict:allowConflict
                      status:outStatus
                    database:db
              withWinningRev:&winningRev];
}

/**
 Private method that should be used when you wish to make multiple putRevisions within a single
 database transation via TD_Database -inTransaction: The winningRev should be used with
 -notifyChange:source:winningRev
 */
- (TD_Revision*)putRevision:(TD_Revision*)rev
             prevRevisionID:(NSString*)previousRevID
              allowConflict:(BOOL)allowConflict
                     status:(TDStatus*)outStatus
                   database:(FMDatabase*)db
             withWinningRev:(TD_Revision**)winningRev

{
    CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"PUT rev=%@, prevRevID=%@, allowConflict=%d", rev,
            previousRevID, allowConflict);
    Assert(outStatus);

    BOOL deleted = rev.deleted;

    if (!rev || (previousRevID && !rev.docID) || (deleted && !rev.docID) ||
        (rev.docID && ![TD_Database isValidDocumentID:rev.docID])) {
        *outStatus = kTDStatusBadID;
        return nil;
    }

    if (rev.body == nil && !deleted) {
        *outStatus = kTDStatusBadJSON;
        return nil;
    }

    TDStatus status;
    NSString* docID = rev.docID;

    //// PART I: In which are performed lookups and validations prior to the insert...

    // Get the doc's numeric ID (doc_id) and its current winning revision:
    SInt64 docNumericID = docID ? [self getDocNumericID:docID database:db] : 0;
    BOOL oldWinnerWasDeletion = NO;
    NSString* oldWinningRevID = nil;
    if (docNumericID > 0) {
        // Look up which rev is the winner, before this insertion
        // OPT: This rev ID could be cached in the 'docs' row
        oldWinningRevID = [self winningRevIDOfDocNumericID:docNumericID
                                                 isDeleted:&oldWinnerWasDeletion
                                                  database:db];
    }

    SequenceNumber parentSequence = 0;
    if (previousRevID) {
        // Replacing: make sure given previousRevID is current & find its sequence number:
        if (docNumericID <= 0) {
            *outStatus = kTDStatusNotFound;
            return nil;
        }
        parentSequence = [self getSequenceOfDocument:docNumericID
                                            revision:previousRevID
                                         onlyCurrent:!allowConflict
                                            database:db];
        if (parentSequence == 0) {
            // Not found: kTDStatusNotFound or a kTDStatusConflict, depending on whether there is
            // any current revision
            if (!allowConflict && [self existsDocumentWithID:docID revisionID:nil database:db])
                *outStatus = kTDStatusConflict;
            else
                *outStatus = kTDStatusNotFound;
            return nil;
        }

        if (_validations.count > 0) {
            // Fetch the previous revision and validate the new one against it:
            TD_Revision* prevRev =
                [[TD_Revision alloc] initWithDocID:docID revID:previousRevID deleted:NO];
            status = [self validateRevision:rev previousRevision:prevRev];
            if (TDStatusIsError(status)) {
                *outStatus = status;
                return nil;
            }
        }

    } else {
        // Inserting first revision.
        if (deleted && docID) {
            // Didn't specify a revision to delete: NotFound or a Conflict, depending
            *outStatus = [self existsDocumentWithID:docID revisionID:nil database:db]
                             ? kTDStatusConflict
                             : kTDStatusNotFound;
            return nil;
        }

        // Validate:
        status = [self validateRevision:rev previousRevision:nil];
        if (TDStatusIsError(status)) {
            *outStatus = status;
            return nil;
        }

        if (docID) {
            // Inserting first revision, with docID given (PUT):
            if (docNumericID <= 0) {
                // Doc ID doesn't exist at all; create it:
                docNumericID = [self insertDocumentID:docID inDatabase:db];
                if (docNumericID <= 0) {
                    *outStatus = kTDStatusDBError;
                    return nil;
                }
            } else {
                // Doc ID exists; check whether current winning revision is deleted:
                if (oldWinnerWasDeletion) {
                    previousRevID = oldWinningRevID;
                    parentSequence = [self getSequenceOfDocument:docNumericID
                                                        revision:oldWinningRevID
                                                     onlyCurrent:NO
                                                        database:db];
                } else if (oldWinningRevID) {
                    // The current winning revision is not deleted, so this is a conflict
                    *outStatus = kTDStatusConflict;
                    return nil;
                }
            }
        } else {
            // Inserting first revision, with no docID given (POST): generate a unique docID:
            docID = [[self class] generateDocumentID];
            docNumericID = [self insertDocumentID:docID inDatabase:db];
            if (docNumericID <= 0) {
                *outStatus = kTDStatusDBError;
                return nil;
            }
        }
    }

    //// PART II: In which we prepare for insertion...

    // Get the attachments:
    NSDictionary* attachments = [self attachmentsFromRevision:rev status:&status];
    if (!attachments) {
        *outStatus = status;
        return nil;
    }

    // Bump the revID and update the JSON:
    NSData* json = nil;
    if (rev.properties) {
        json = [self encodeDocumentJSON:rev];
        if (!json) {
            *outStatus = kTDStatusBadJSON;
            return nil;
        }
        if (json.length == 2 && memcmp(json.bytes, "{}", 2) == 0) json = nil;
    }
    NSString* newRevID =
        [self generateIDForRevision:rev withJSON:json attachments:attachments prevID:previousRevID];
    if (!newRevID) {
        *outStatus = kTDStatusBadID;  // invalid previous revID (no numeric prefix)
        return nil;
    }
    Assert(docID);
    rev = [rev copyWithDocID:docID revID:newRevID];
    //*revPointer = rev;

    // Don't store a SQL null in the 'json' column -- I reserve it to mean that the revision data
    // is missing due to compaction or replication.
    // Instead, store an empty zero-length blob.
    if (json == nil) json = [NSData data];

    //// PART III: In which the actual insertion finally takes place:

    SequenceNumber sequence = [self insertRevision:rev
                                      docNumericID:docNumericID
                                    parentSequence:parentSequence
                                           current:YES
                                              JSON:json
                                          database:db];
    if (!sequence) {
        // The insert failed. If it was due to a constraint violation, that means a revision
        // already exists with identical contents and the same parent rev. We can ignore this
        // insert call, then.
        if (db.lastErrorCode != SQLITE_CONSTRAINT) {
            *outStatus = kTDStatusDBError;
            return nil;
        }
        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Duplicate rev insertion: %@ / %@", docID, newRevID);
        *outStatus = kTDStatusOK;
        rev.body = nil;
        return nil;
    }

    // Make replaced rev non-current:
    if (parentSequence > 0) {
        if (![db executeUpdate:@"UPDATE revs SET current=0 WHERE sequence=?", @(parentSequence)]) {
            *outStatus = kTDStatusDBError;
            return nil;
        }
    }

    // Store any attachments:
    status = [self processAttachments:attachments
                          forRevision:rev
                   withParentSequence:parentSequence
                           inDatabase:db];
    if (TDStatusIsError(status)) {
        *outStatus = status;
        return nil;
    }

    // Success!
    *outStatus = deleted ? kTDStatusOK : kTDStatusCreated;

    // Figure out what the new winning rev ID is.
    // (This is confusing -- it is just related to notification purposes.
    // Typically this just sets winningRev = rev, or to nil when there's a conflict)
    *winningRev = [self winnerWithDocID:docNumericID
                              oldWinner:oldWinningRevID
                             oldDeleted:oldWinnerWasDeletion
                                 newRev:rev
                               database:db];

    return rev;
}

/** Public method to add a new revision of a document. */
- (TD_Revision*)putRevision:(TD_Revision*)revToInsert
             prevRevisionID:(NSString*)previousRevID  // rev ID being replaced, or nil if an insert
              allowConflict:(BOOL)allowConflict
                     status:(TDStatus*)outStatus
{
    // Reassign variables passed in that we (possibly) modify to __block variables.
    __block TD_Revision* winningRev = nil;
    __block TD_Revision* newRev = nil;

    *outStatus =
        kTDStatusDBError;  // default error is Internal Server Error, if we return nil below
    __weak TD_Database* weakSelf = self;
    [_fmdbQueue inTransaction:^(FMDatabase* db, BOOL* rollback) {
        TD_Database* strongSelf = weakSelf;
        newRev = [strongSelf putRevision:revToInsert
                          prevRevisionID:previousRevID
                           allowConflict:allowConflict
                                  status:outStatus
                                database:db
                          withWinningRev:&winningRev];

        bool success = (*outStatus < 300);
        if (!success) {
            *rollback = !success;
        }
    }];

    if (TDStatusIsError(*outStatus)) return nil;

    //// EPILOGUE: A change notification is sent...
    [self notifyChange:newRev source:nil winningRev:winningRev];
    return newRev;
}

/** Public method to add an existing revision of a document (probably being pulled). */
- (TDStatus)forceInsert:(TD_Revision*)rev
        revisionHistory:(NSArray*)history  // in *reverse* order, starting with rev's revID
                 source:(NSURL*)source
{
    NSString* docID = rev.docID;
    NSString* revID = rev.revID;
    if (![TD_Database isValidDocumentID:docID] || !revID) return kTDStatusBadID;

    NSUInteger historyCount = history.count;
    if (historyCount == 0) {
        history = @[ revID ];
        historyCount = 1;
    } else if (!$equal(history[0], revID))
        return kTDStatusBadID;

    __block TD_Revision* winningRev = nil;
    __block TDStatus result = kTDStatusCreated;
    __weak TD_Database* weakSelf = self;
    [_fmdbQueue inTransaction:^(FMDatabase* db, BOOL* rollback) {
        TD_Database* strongSelf = weakSelf;
        BOOL success = NO;
        @try {
            // First look up the document's row-id and all locally-known revisions of it:
            TD_RevisionList* localRevs = nil;
            SInt64 docNumericID = [strongSelf getDocNumericID:docID database:db];
            if (docNumericID > 0) {
                localRevs = [strongSelf getAllRevisionsOfDocumentID:docID
                                                          numericID:docNumericID
                                                        onlyCurrent:NO
                                                     excludeDeleted:NO
                                                           database:db];
                if (!localRevs) {
                    result = kTDStatusDBError;
                    return;
                }
            } else {
                docNumericID = [strongSelf insertDocumentID:docID inDatabase:db];
                if (docNumericID <= 0) {
                    result = kTDStatusDBError;
                    return;
                }
            }

            // Validate against the latest common ancestor:
            if (_validations.count > 0) {
                TD_Revision* oldRev = nil;
                for (NSUInteger i = 1; i < historyCount; ++i) {
                    oldRev = [localRevs revWithDocID:docID revID:history[i]];
                    if (oldRev) break;
                }
                TDStatus status = [strongSelf validateRevision:rev previousRevision:oldRev];
                if (TDStatusIsError(status)) {
                    result = status;
                    return;
                }
            }

            // Look up which rev is the winner, before this insertion
            // OPT: This rev ID could be cached in the 'docs' row
            BOOL oldWinnerWasDeletion;
            NSString* oldWinningRevID = [strongSelf winningRevIDOfDocNumericID:docNumericID
                                                                     isDeleted:&oldWinnerWasDeletion
                                                                      database:db];

            // Walk through the remote history in chronological order, matching each revision ID to
            // a local revision. When the list diverges, start creating blank local revisions to
            // fill
            // in the local history:
            SequenceNumber sequence = 0;
            SequenceNumber localParentSequence = 0;
            for (NSInteger i = historyCount - 1; i >= 0; --i) {
                NSString* revID = history[i];
                TD_Revision* localRev = [localRevs revWithDocID:docID revID:revID];
                if (localRev) {
                    // This revision is known locally. Remember its sequence as the parent of the
                    // next one:
                    sequence = localRev.sequence;
                    Assert(sequence > 0);
                    localParentSequence = sequence;

                } else {
                    // This revision isn't known, so add it:
                    TD_Revision* newRev;
                    NSData* json = nil;
                    BOOL current = NO;
                    if (i == 0) {
                        // Hey, this is the leaf revision we're inserting:
                        newRev = rev;
                        json = [strongSelf encodeDocumentJSON:rev];
                        if (!json) {
                            result = kTDStatusBadJSON;
                            return;
                        }
                        current = YES;
                    } else {
                        // It's an intermediate parent, so insert a stub:
                        newRev = [[TD_Revision alloc] initWithDocID:docID revID:revID deleted:NO];
                    }

                    // Insert it:
                    sequence = [strongSelf insertRevision:newRev
                                             docNumericID:docNumericID
                                           parentSequence:sequence
                                                  current:current
                                                     JSON:json
                                                 database:db];
                    if (sequence <= 0) {
                        result = kTDStatusDBError;
                        return;
                    }
                    newRev.sequence = sequence;

                    if (i == 0) {
                        // Write any changed attachments for the new revision. As the parent
                        // sequence use
                        // the latest local revision (this is to copy attachments from):
                        TDStatus status;
                        NSDictionary* attachments =
                            [strongSelf attachmentsFromRevision:rev status:&status];
                        if (attachments)
                            status = [strongSelf processAttachments:attachments
                                                        forRevision:rev
                                                 withParentSequence:localParentSequence
                                                         inDatabase:db];
                        if (TDStatusIsError(status)) {
                            result = status;
                            return;
                        }
                    }
                }
            }

            // Mark the latest local rev as no longer current:
            if (localParentSequence > 0 && localParentSequence != sequence) {
                if (![db executeUpdate:@"UPDATE revs SET current=0 WHERE sequence=?",
                                       @(localParentSequence)]) {
                    result = kTDStatusDBError;
                    return;
                }
            }

            // Figure out what the new winning rev ID is:
            winningRev = [strongSelf winnerWithDocID:docNumericID
                                           oldWinner:oldWinningRevID
                                          oldDeleted:oldWinnerWasDeletion
                                              newRev:rev
                                            database:db];

            success = YES;
        }
        @finally { *rollback = !success; }
    }];

    // Notify and return:
    [self notifyChange:rev source:source winningRev:winningRev];
    return result;
}

#pragma mark - PURGING / COMPACTING:

- (TDStatus)compact
{
    // Can't delete any rows because that would lose revision tree history.
    // But we can remove the JSON of non-current revisions, which is most of the space.

    __block TDStatus result;
    __weak TD_Database* weakSelf = self;
    [_fmdbQueue inDatabase:^(FMDatabase* db) {
        TD_Database* strongSelf = weakSelf;
        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"TD_Database: Deleting JSON of old revisions...");
        if (![db executeUpdate:@"UPDATE revs SET json=null WHERE current=0"]) {
            result = kTDStatusDBError;
            return;
        }

        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Deleting old attachments...");
        result = [strongSelf garbageCollectAttachments:db];

        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Flushing SQLite WAL...");
        FMResultSet* rset = [db executeQuery:@"PRAGMA wal_checkpoint(RESTART)"];
        @try {
            if (!rset || db.hadError) {
                result = kTDStatusDBError;
                return;
            }
        }
        @finally { [rset close]; }

        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Vacuuming SQLite database...");
        if (![db executeUpdate:@"VACUUM"]) {
            result = kTDStatusDBError;
            return;
        }
    }];

    if (result == kTDStatusDBError) {
        return result;
    }

    // TODO syncronise the open/close?

    CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Closing and re-opening database...");
    [_fmdbQueue close];

    if (![self openFMDBWithEncryptionKeyProvider:_keyProviderToOpenDB]) return kTDStatusDBError;

    CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"...Finished database compaction.");
    return result;
}

- (TDStatus)purgeRevisions:(NSDictionary*)docsToRevs result:(NSDictionary**)outResult
{
    // <http://wiki.apache.org/couchdb/Purge_Documents>
    NSMutableDictionary* result = $mdict();
    if (outResult) *outResult = result;
    if (docsToRevs.count == 0) return kTDStatusOK;

    __weak TD_Database* weakSelf = self;
    return [self inTransaction:^TDStatus(FMDatabase* db) {
        TD_Database* strongSelf = weakSelf;
        for (NSString* docID in docsToRevs) {
            SInt64 docNumericID = [strongSelf getDocNumericID:docID database:db];
            if (!docNumericID) {
                continue;  // no such document; skip it
            }
            NSArray* revsPurged;
            NSArray* revIDs = $castIf(NSArray, docsToRevs[docID]);
            if (!revIDs) {
                return kTDStatusBadParam;
            } else if (revIDs.count == 0) {
                revsPurged = @[];
            } else if ([revIDs containsObject:@"*"]) {
                // Delete all revisions if magic "*" revision ID is given:
                if (![db executeUpdate:@"DELETE FROM revs WHERE doc_id=?", @(docNumericID)]) {
                    return kTDStatusDBError;
                }
                revsPurged = @[ @"*" ];

            } else {
                // Iterate over all the revisions of the doc, in reverse sequence order.
                // Keep track of all the sequences to delete, i.e. the given revs and ancestors,
                // but not any non-given leaf revs or their ancestors.
                FMResultSet* r = [db executeQuery:@"SELECT revid, sequence, parent FROM revs "
                                                   "WHERE doc_id=? ORDER BY sequence DESC",
                                                  @(docNumericID)];
                if (!r) return kTDStatusDBError;
                NSMutableSet* seqsToPurge = [NSMutableSet set];
                NSMutableSet* seqsToKeep = [NSMutableSet set];
                NSMutableSet* revsToPurge = [NSMutableSet set];
                while ([r next]) {
                    NSString* revID = [r stringForColumnIndex:0];
                    id sequence = @([r longLongIntForColumnIndex:1]);
                    id parent = @([r longLongIntForColumnIndex:2]);
                    if (([seqsToPurge containsObject:sequence] || [revIDs containsObject:revID]) &&
                        ![seqsToKeep containsObject:sequence]) {
                        // Purge it and maybe its parent:
                        [seqsToPurge addObject:sequence];
                        [revsToPurge addObject:revID];
                        if ([parent longLongValue] > 0) [seqsToPurge addObject:parent];
                    } else {
                        // Keep it and its parent:
                        [seqsToPurge removeObject:sequence];
                        [revsToPurge removeObject:revID];
                        [seqsToKeep addObject:parent];
                    }
                }
                [r close];
                [seqsToPurge minusSet:seqsToKeep];

                CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"Purging doc '%@' revs (%@); asked for (%@)", docID,
                        [revsToPurge.allObjects componentsJoinedByString:@", "],
                        [revIDs componentsJoinedByString:@", "]);

                if (seqsToPurge.count) {
                    // Now delete the sequences to be purged.
                    NSString* sql =
                        $sprintf(@"DELETE FROM revs WHERE sequence in (%@)",
                                 [seqsToPurge.allObjects componentsJoinedByString:@","]);
                    if (![db executeUpdate:sql]) return kTDStatusDBError;
                    if ((NSUInteger)db.changes != seqsToPurge.count)
                        CDTLogWarn(CDTDATASTORE_LOG_CONTEXT,
                                @"purgeRevisions: Only %i sequences deleted of (%@)", db.changes,
                                [seqsToPurge.allObjects componentsJoinedByString:@","]);
                }
                revsPurged = revsToPurge.allObjects;
            }
            result[docID] = revsPurged;
        }
        return kTDStatusOK;
    }];
}

#pragma mark - VALIDATION:

- (void)defineValidation:(NSString*)validationName asBlock:(TD_ValidationBlock)validationBlock
{
    if (validationBlock) {
        if (!_validations) _validations = [[NSMutableDictionary alloc] init];
        [_validations setValue:[validationBlock copy] forKey:validationName];
    } else {
        [_validations removeObjectForKey:validationName];
    }
}

- (TD_ValidationBlock)validationNamed:(NSString*)validationName
{
    return _validations[validationName];
}

- (TDStatus)validateRevision:(TD_Revision*)newRev previousRevision:(TD_Revision*)oldRev
{
    if (_validations.count == 0) return kTDStatusOK;
    TD_ValidationContext* context =
        [[TD_ValidationContext alloc] initWithDatabase:self revision:oldRev newRevision:newRev];
    TDStatus status = kTDStatusOK;
    for (NSString* validationName in _validations) {
        TD_ValidationBlock validation = [self validationNamed:validationName];
        if (!validation(newRev, context)) {
            status = context.errorType;
            break;
        }
    }
    return status;
}

@end

@implementation TD_ValidationContext

- (id)initWithDatabase:(TD_Database*)db
              revision:(TD_Revision*)currentRevision
           newRevision:(TD_Revision*)newRevision
{
    self = [super init];
    if (self) {
        _db = db;
        _currentRevision = currentRevision;
        _newRevision = newRevision;
        _errorType = kTDStatusForbidden;
        _errorMessage = @"invalid document";
    }
    return self;
}

- (TD_Revision*)currentRevision
{
    if (_currentRevision) [_db loadRevisionBody:_currentRevision options:0];
    return _currentRevision;
}

@synthesize errorType = _errorType, errorMessage = _errorMessage;

- (NSArray*)changedKeys
{
    if (!_changedKeys) {
        NSMutableArray* changedKeys = [[NSMutableArray alloc] init];
        NSDictionary* cur = self.currentRevision.properties;
        NSDictionary* nuu = _newRevision.properties;
        for (NSString* key in cur.allKeys) {
            if (!$equal(cur[key], nuu[key]) && ![key isEqualToString:@"_rev"])
                [changedKeys addObject:key];
        }
        for (NSString* key in nuu.allKeys) {
            if (!cur[key] && ![key isEqualToString:@"_rev"] && ![key isEqualToString:@"_id"])
                [changedKeys addObject:key];
        }
        _changedKeys = changedKeys;
    }
    return _changedKeys;
}

- (BOOL)allowChangesOnlyTo:(NSArray*)keys
{
    for (NSString* key in self.changedKeys) {
        if (![keys containsObject:key]) {
            self.errorMessage = $sprintf(@"The '%@' property may not be changed", key);
            return NO;
        }
    }
    return YES;
}

- (BOOL)disallowChangesTo:(NSArray*)keys
{
    for (NSString* key in self.changedKeys) {
        if ([keys containsObject:key]) {
            self.errorMessage = $sprintf(@"The '%@' property may not be changed", key);
            return NO;
        }
    }
    return YES;
}

- (BOOL)enumerateChanges:(TDChangeEnumeratorBlock)enumerator
{
    NSDictionary* cur = self.currentRevision.properties;
    NSDictionary* nuu = _newRevision.properties;
    for (NSString* key in self.changedKeys) {
        if (!enumerator(key, cur[key], nuu[key])) {
            if (!_errorMessage)
                self.errorMessage = $sprintf(@"Illegal change to '%@' property", key);
            return NO;
        }
    }
    return YES;
}

@end
