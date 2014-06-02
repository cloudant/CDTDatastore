//
//  CDTAbstractReplication.h
//  
//
//  Created by Adam Cox on 4/8/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
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

extern NSString* const CDTReplicationErrorDomain;

/**
 * Replication errors.
 */
typedef NS_ENUM(NSInteger, CDTReplicationErrors) {
    /**
     No source is defined.
     */
    CDTReplicationErrorUndefinedSource,
    /**
     No target is defined
     */
    CDTReplicationErrorUndefinedTarget,
    /**
     Unsupported protocol. Only 'http' or 'https'.
     */
    CDTReplicationErrorInvalidScheme,
    /**
     Missing either a username or password.
     */
    CDTReplicationErrorIncompleteCredentials
};


/**
 This is an abstract base class for the CDTPushReplication and CDTPullReplication subclasses.
 Do not create instances of this class.
 
 CDTAbstractReplication objects encapsulate the parameters necessary
 for the CDTReplicationFactory to create a CDTReplicator object, which
 is used to start individual replication tasks.
 
 All replications require a remote datasource URL and a local CDTDatastore.
 These are specified with the -target and -source properties found in the subclasses.
 
 */
@interface CDTAbstractReplication : NSObject


/*
 ---------------------------------------------------------------------------------------
 The following methods/properties may be accessed instances of the CDTPushReplication
 and CDTPullReplication classes.
 
 These methods and properties are common to both push and pull replications and are used
 to set various replication options.
 
 http://docs.couchdb.org/en/latest/json-structure.html#replication-settings
 
 ---------------------------------------------------------------------------------------
 */


/*
 ---------------------------------------------------------------------------------------
 The following methods should not be accessed by a user of this class or the subclasses. 
 The only exception may be the dictionaryForReplicatorDocument method, in special circumstances.
 */

/** --------------------------------------------------------------------------------------
 @name For internal use only
 ---------------------------------------------------------------------------------------
 */

/** The NSDictionary is used by CDTReplicatorFactory to generate the proper document for the 
 _replicator database.
 
 @param error reports error information
 @return The NSDictionary that represents the JSON document to be written to the _replicator
 database.
 @warning This method is for internal use only. The CDTPushReplication and CDTPullReplication
     classes implement this method.

 */
-(NSDictionary*) dictionaryForReplicatorDocument:(NSError * __autoreleasing*)error;



/** Checks the content and format of the remoteDatastore URL to ensure that it uses a proper protocol (http or https) and has both a username and password (or neither).
 
 @warning This method is for internal use only. 
 @param url the URL to be validated
 @param error reports error information
 @return YES on valid URL.
 
 */
-(BOOL)validateRemoteDatastoreURL:(NSURL *)url error:(NSError * __autoreleasing*)error;


@end
