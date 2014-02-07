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
@class CDTDatastoreManager;

/**
 Factory for CDTReplicator objects.

 The _source_ or _target_ NSURL parameters used in the
 methods below must include:

     protocol://[username:password@]host[:port]/database_name

 _protocol_, _host_ and _database_name_ are required.
 If no _port_ is provided, the default for _protocol_ is used.
 Using a _database_name_ containing a `/` is not supported.
 */
@interface CDTReplicatorFactory : NSObject

/**---------------------------------------------------------------------------------------
 * @name Getting a replicator factory set up
 *  --------------------------------------------------------------------------------------
 */

/**
 Initialise with a datastore manager object.
 
 This manager is used for the `_replicator` database used to manage
 replications internally.
 
 @param dsManager the manager of the datastores that this factory will replicate to and from.
 */
- (id) initWithDatastoreManager: (CDTDatastoreManager*)dsManager;

/**
 Start the background thread for replications.
 
 No replications will progress until -start is called.
 */
- (void) start;

/**
 Stop the background thread for replications.
 
 This will stop all in progress replications.
 */
- (void) stop;


/**---------------------------------------------------------------------------------------
 * @name Creating replication jobs
 *  --------------------------------------------------------------------------------------
 */

/**
 * Create a CDTReplicator object set up to replicate changes from the
 * local datastore to a remote database.
 *
 * @param source local CDTDatastore to replicate changes from.
 * @param target remote database to replicate changes to.
 *
 * @return a CDTReplicator instance which can be used to start and
 *  stop the replication itself.
 */
- (CDTReplicator*)onewaySourceDatastore:(CDTDatastore*)source
                              targetURI:(NSURL*)target;

/**
 * Create a CDTReplicator object set up to replicate changes from a
 * remote database to the local datastore.
 *
 * @param source remote database to replicate changes from.
 * @param target local CDTDatastore to replicate changes to.
 *
 * @return a CDTReplicator instance which can be used to start and
 *  stop the replication itself.
 */
- (CDTReplicator*)onewaySourceURI:(NSURL*)source
                  targetDatastore:(CDTDatastore*)target;

@end
