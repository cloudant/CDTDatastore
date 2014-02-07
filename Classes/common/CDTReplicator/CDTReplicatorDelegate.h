//
//  CDTReplicatorDelegate.h
//  
//
//  Created by Michael Rhodes on 07/02/2014.
//
//

#import <Foundation/Foundation.h>

@class CDTReplicator;
@class CDTReplicationErrorInfo;

/**
 The delegate of a CDTReplicator must adopt the CDTReplicatorDelegate protocol. The protocol
 allows the delegate to be notified of updates during replication. All methods are optional.
 */
@protocol CDTReplicatorDelegate <NSObject>

// all methods are optional
@optional

/**
 * <p>Called when the replicator changes state.</p>
 *
 * <p>May be called from any worker thread.</p>
 *
 * @param replicator the replicator issuing the event.
 */
-(void) replicatorDidChangeState:(CDTReplicator*)replicator;

/**
 * <p>Called whenever the replicator changes progress</p>
 *
 * <p>May be called from any worker thread.</p>
 *
 * @param replicator the replicator issuing the event.
 */
-(void) replicatorDidChangeProgress:(CDTReplicator*)replicator;

/**
 * <p>Called when a state transition to COMPLETE or STOPPED is
 * completed.</p>
 *
 * <p>May be called from any worker thread.</p>
 *
 * <p>Continuous replications (when implemented) will never complete.</p>
 *
 * @param replicator the replicator issuing the event.
 */
- (void)replicatorDidComplete:(CDTReplicator*)replicator;

/**
 * <p>Called when a state transition to ERROR is completed.</p>
 *
 * <p>Errors may include things such as:</p>
 *
 * <ul>
 *      <li>incorrect credentials</li>
 *      <li>network connection unavailable</li>
 * </ul>
 *
 *
 * <p>May be called from any worker thread.</p>
 *
 * @param replicator the replicator issuing the event.
 * @param info information about the error that occurred.
 */
- (void)replicatorDidError:(CDTReplicator*)replicator info:(CDTReplicationErrorInfo*)info;

@end
