//
//  TDPuller.h
//  TouchDB
//
//  Created by Jens Alfke on 12/2/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.
//

#import "TDReplicator.h"
#import "TD_Revision.h"
@class TDChangeTracker, TDSequenceMap;

/** Replicator that pulls from a remote CouchDB. */
@interface TDPuller : TDReplicator {
   @private
    TDChangeTracker* _changeTracker;
    BOOL _caughtUp;                     // Have I received all current _changes entries?
    TDSequenceMap* _pendingSequences;   // Received but not yet copied into local DB
    NSMutableArray* _revsToPull;        // Queue of TDPulledRevisions to download
    NSMutableArray* _deletedRevsToPull; // Separate lower-priority of deleted TDPulledRevisions
    NSMutableArray* _bulkRevsToPull;    // TDPulledRevisions that can be fetched in bulk
    NSUInteger _httpConnectionCount;    // Number of active NSURLConnections
    TDBatcher* _downloadsToInsert;      // Queue of TDPulledRevisions, with bodies, to insert in DB
    NSArray* _clientFilterDocIds;       // If set, only pull this subset of doc ids
    NSMutableSet *_clientFilterNewDocIds; // The set difference: _clientFilterDocIds - all doc ids in DB
}

// overriden from TDReplicator
- (NSString*) remoteCheckpointDocID;
// overriden from TDReplicator
- (void) addToInbox: (TD_Revision*)rev;
- (void) setClientFilterDocIds:(NSArray *)clientFilterDocIds;
@end

/** A revision received from a remote server during a pull. Tracks the opaque remote sequence ID. */
@interface TDPulledRevision : TD_Revision {
   @private
    id _remoteSequenceID;
    bool _conflicted;
}

@property (copy) id remoteSequenceID;
@property bool conflicted;

@end
