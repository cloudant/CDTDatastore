//
//  CDTReplicatorListener.h
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//
//

#import <Foundation/Foundation.h>

@protocol CDTReplicatorListener <NSObject>

/**
 * <p>Called when a state transition to COMPLETE or STOPPED is
 * completed.</p>
 *
 * <p>{@code complete} may be called from one of the replicator's
 * worker threads.</p>
 *
 * <p>Continuous replications (when implemented) will never complete.</p>
 *
 * @param replicator the replicator issuing the event.
 */
- (void)complete:(CDTReplicator*)replicator;

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
 * <p>{@code error} may be called from one of the replicator's worker
 * threads.</p>
 *
 * @param replicator the replicator issuing the event.
 * @param error information about the error that occurred.
 */
- (void)error:(CDTReplicator*)replicator info:(CDTReplicationErrorInfo*)info;

@end
