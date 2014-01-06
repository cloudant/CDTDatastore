//
//  CDTReplicatorFactory.h
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//
//

#import <Foundation/Foundation.h>

@class CDTDatastore;
@class CDTReplicator;

/**
 * <p>Factory for {@link CDTDatastore} objects.</p>
 *
 * <p>The {@code source} or {@code target} {@link URI} parameters used in the
 * methods below must include:</p>
 *
 * <pre>
 *   protocol://[username:password@]host[:port]/database_name
 * </pre>
 *
 * <p><em>protocol</em>, <em>host</em> and <em>database_name</em> are required.
 * If no <em>port</em> is provided, the default for <em>protocol</em> is used.
 * Using a <em>database_name</em> containing a {@code /} is not supported.</p>
 */
@interface CDTReplicatorFactory : NSObject

/**
 * <p>Creates a Replicator object set up to replicate changes from the
 * local datastore to a remote database.</p>
 *
 * @param source local {@link CDTDatastore} to replicate changes from.
 * @param target remote database to replicate changes to.
 *
 * @return a {@link CDTReplicator} instance which can be used to start and
 *  stop the replication itself.
 *
 */
- (CDTReplicator*)onewaySourceDatastore:(CDTDatastore*)source
                              targetURI:(NSURL*)target;

/**
 * <p>Creates a Replicator object set up to replicate changes from a
 * remote database to the local datastore.</p>
 *
 * @param source remote database to replicate changes from.
 * @param target local {@link CDTDatastore} to replicate changes to.
 *
 * @return a {@link CDTReplicator} instance which can be used to start and
 *  stop the replication itself.
 */
- (CDTReplicator*)onewaySourceURI:(NSURL*)source
                  targetDatastore:(CDTDatastore*)target;

@end
