//
//  CDTReplicator.h
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//
//

#import <Foundation/Foundation.h>

@class CDTDatastore;
@class CDTDocumentBody;
@class CDTReplicationListener;

/**
 * <p>Describes the state of a {@link Replicator} at a given moment.</p>
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
     * The last replication was stopped using
     * {@link com.cloudant.sync.replication.Replicator#stop()}.
     */
    CDTReplicatorStateStopped,
    /**
     * {@link com.cloudant.sync.replication.Replicator#stop()} has
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

@interface CDTReplicator : NSObject


-(id)initWithReplicatorDatastore:(CDTDatastore*)replicatorDb
         replicationDocumentBody:(CDTDocumentBody*)body;

/**
 * <p>Starts a replication.</p>
 *
 * <p>The replication will continue until the
 * replication is caught up with the source database; that is, until
 * there are no current changes to replicate.</p>
 *
 * <p>{@code start} can be called from any thread. It spawns background
 * threads for its work. The methods on the ReplicationListener
 * may be called from the background threads; any work that needs
 * to be on the main thread will need to be explicitly executed
 * on that thread.</p>
 *
 * <p>{@code start} will spawn a manager thread for the replication and
 * immediately return.</p>
 *
 * <p>A given replicator instance can be reused:</p>
 *
 * <ul>
 *  <li>If you call start when in {@link Replicator.State#PENDING},
 *   replication will start.</li>
 *  <li>In {@link Replicator.State#STARTED}, nothing changes.</li>
 *  <li>In {@link Replicator.State#STOPPING}, nothing changes.</li>
 *  <li>In {@link Replicator.State#ERROR}, the replication will restart.
 *   It's likely its going to error again, however, depending on whether
 *   the error is transient or not.</li>
 *  <li>In {@link Replicator.State#STOPPED} or
 *   {@link Replicator.State#COMPLETE}, the replication will start a
 *   second or further time.</li>
 * </ul>
 */
- (void)start;

/**
 * <p>Stops an in-progress replication.</p>
 *
 * <p>Already replicated changes will remain
 * in the datastore database.</p>
 *
 * <p>{@code stop} can be called from any thread. It will initiate a
 * shutdown process and return immediately.</p>
 *
 * <p>The shutdown process may take time as we need to wait for in-flight
 * network requests to complete before background threads can be safely
 * stopped. However, no modifications to the database will be made
 * after {@code stop} is called, including checkpoint related
 * operations.</p>
 *
 * <p>Consumers should check
 * {@link com.cloudant.sync.replication.Replicator#getState()} if they need
 * to know when the replicator has fully stopped. After {@code stop} is
 * called, the replicator will be in the {@link Replicator.State#STOPPING}
 * state while operations complete and will move to the
 * {@link Replicator.State#STOPPED} state when the replicator has fully
 * shutdown.</p>
 *
 * <p>It is also possible the replicator moves to the
 * {@link Replicator.State#ERROR} state if an error happened during the
 * shutdown process.</p>
 *
 * <p>If the replicator is in the {@link Replicator.State#PENDING} state,
 * it will immediately move to the {@link Replicator.State#STOPPED} state.
 * </p>
 */
- (void)stop;

/**
 * <p>Returns the {@link Replicator.State} this replicator is in.</p>
 *
 * <p>{@code getState} may be called from any thread.</p>
 *
 * <p>In all states other than {@link CDTReplicatorStateStarted} and
 * {@link CDTReplicatorStateStopping}, the replicator object
 * is idle with no background threads.</p>
 */
- (CDTReplicatorState)state;

/**
 * <p>Sets the replicator's {@link ReplicationListener}.</p>
 *
 * <p>Providing a listener is optional, but is a more efficient method
 * for keeping track of the replication than polling.</p>
 *
 * <p>To remove the listener, call send {@code null} as the
 * {@code listener} parameter.</p>
 *
 * @param listener a new listener to replace the current one. Use
 *                 {@code null} to set no listener.
 *
 * @see ReplicationListener
 */
@property (nonatomic,strong) CDTReplicationListener *listener;

@end
