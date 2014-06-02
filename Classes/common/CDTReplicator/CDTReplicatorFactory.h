//
//  CDTReplicatorFactory.h
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

@class CDTDatastore;
@class CDTReplicator;
@class CDTDatastoreManager;
@class CDTAbstractReplication;

/**
* Replication errors.
*/
typedef NS_ENUM(NSInteger, CDTReplicatorFactoryErrors) {
    /**
     * CDTReplicator was not fully constucted
     */
    CDTReplicatorFactoryErrorNilReplicatorObject = 1,
    /**
       Error creating a new CDTDocumentBody
     */
    CDTReplicatorFactoryErrorNilDocumentBodyForReplication  = 2
};

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
 * CDTPullReplication and CDTPushReplication (subclasses of CDTAbstractReplication)
 * provide configuration parameters for the construction of the CDTReplicator.
 *
 * @param replication a CDTPullReplication or CDTPushReplication
 * @param error report error information
 *
 * @return a CDTReplicator instance which can be used to start and
 *  stop the replication itself.
 */
- (CDTReplicator*)oneWay:(CDTAbstractReplication*)replication
                   error:(NSError * __autoreleasing *)error;


/**
 The following methods will soon be deprecated. 
 @see CDTReplicatorFactor -oneWay:(CDTAbstractReplication*).
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
