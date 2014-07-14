//
//  CDTReplicator.h
//
//
//  Created by Michael Rhodes on 10/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

#import "CDTReplicatorDelegate.h"

@class CDTDatastore;
@class CDTDocumentBody;
@class TDReplicatorManager;

/**
 * Describes the state of a CDTReplicator at a given moment.

 @see CDTReplicator
 */
typedef NS_ENUM(NSInteger, CDTReplicatorState) {
    /**
     * The replicator is initialised and is ready to start.
     */
    CDTReplicatorStatePending,
    /**
     * A replication is in progress.
     */
    CDTReplicatorStateStarted,
    /**
     * The last replication was stopped using -stop
     */
    CDTReplicatorStateStopped,
    /**
     * -stop has
     * been called and the replicator is stopping its worker threads.
     */
    CDTReplicatorStateStopping,
    /**
     * The last replication successfully completed.
     */
    CDTReplicatorStateComplete,
    /**
     * The last replication completed in error.
     */
    CDTReplicatorStateError
};

/**
 A CDTReplicator instance represents a replication job.

 In CouchDB terms, it wraps a document in the `_replicator` database.

 Use CDTReplicatorFactory to create instances of this class.

 @see CDTReplicatorFactory
 */
@interface CDTReplicator : NSObject


/**---------------------------------------------------------------------------------------
 * @name Replication status
 *  --------------------------------------------------------------------------------------
 */

/**
 The current replication state.

 @see CDTReplicatorState
 */
@property (nonatomic, readonly) CDTReplicatorState state;

/**
 The number of changes from the source's `_changes` feed this
 replicator has processed.
 */
@property (nonatomic, readonly) NSInteger changesProcessed;

/** Total number of changes read so far from the source's `_changes`
 feed.

 Note that this will increase as the replication continues and
 further reads of the `_changes` feed happen.
 */
@property (nonatomic, readonly) NSInteger changesTotal;

/**
 * Set the replicator's delegate.
 *
 * This allows for more efficient tracking of replication state than polling.
 *
 * @see CDTReplicatorDelegate
 */
@property (nonatomic,weak) NSObject<CDTReplicatorDelegate> *delegate;

/**
 Returns true if the state is `CDTReplicatorStatePending`, `CDTReplicatorStateStarted` or
 `CDTReplicatorStateStopping`.

 @see CDTReplicatorState
 */
-(BOOL)isActive;

/**
 Returns a string representation of a CDTReplicatorState value.

 @param state state to return string representation
 */
+(NSString*)stringForReplicatorState:(CDTReplicatorState)state;


/*
 Private so no docs
 */
-(id)initWithTDReplicatorManager:(TDReplicatorManager*)replicatorManager
           replicationProperties:(NSDictionary*)properties;


/**---------------------------------------------------------------------------------------
 * @name Controlling replication
 *  --------------------------------------------------------------------------------------
 */

/**
 * Starts a replication.
 *
 * The replication will continue until the
 * replication is caught up with the source database; that is, until
 * there are no current changes to replicate.
 *
 * -start can be called from any thread. It spawns background
 * threads for its work. The methods on the ReplicationListener
 * may be called from the background threads; any work that needs
 * to be on the main thread will need to be explicitly executed
 * on that thread.
 *
 * -start will spawn a manager thread for the replication and
 * immediately return.
 *
 * A given replicator instance can be reused:
 *
 * - If you call -start when in `CDTReplicatorStatePending`,
 *   replication will start.
 * - In `CDTReplicatorStateStarted`, nothing changes.
 * - In `CDTReplicatorStateStopping`, nothing changes.
 * - In `CDTReplicatorStateError`, the replication will restart.
 *   It's likely its going to error again, however, depending on whether
 *   the error is transient or not.
 * - In `CDTReplicatorStateStopped` or `CDTReplicatorStateComplete`, the
 *   replication will start a second or further time.
 *
 * @see CDTReplicatorState
 */
- (void)start;

/**
 * Stop an in-progress replication.
 *
 * Already replicated changes will remain in the datastore.
 *
 * -stop can be called from any thread. It will initiate a
 * shutdown process and return immediately.
 *
 * The shutdown process may take time as we need to wait for in-flight
 * network requests to complete before background threads can be safely
 * stopped. However, no modifications to the database will be made
 * after -stop is called, including checkpoint related
 * operations.
 *
 * Consumers should check -state if they need
 * to know when the replicator has fully stopped. After -stop is
 * called, the replicator will be in the `CDTReplicatorStateStopping`
 * state while operations complete and will move to the
 * `CDTReplicatorStateStopped` state when the replicator has fully
 * shutdown.
 *
 * It is also possible the replicator moves to the
 * `CDTReplicatorStateError` state if an error happened during the
 * shutdown process.
 *
 * If the replicator is in the `CDTReplicatorStateStopping` state,
 * it will immediately move to the `CDTReplicatorStateStopped` state.
 *
 * @see CDTReplicatorState
 */
- (void)stop;

@end
