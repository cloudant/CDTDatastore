//
//  CDTPullReplication.h
//
//
//  Created by Adam Cox on 4/8/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTAbstractReplication.h"

NS_ASSUME_NONNULL_BEGIN

/**

 CDTPullReplication objects are used to configure a replication of a
 remote Cloudant/CouchDB datastore to a local CDTDatastore. At minimum, source
 and target must be specified.

 Example usage:

    CDTDatastoreManager *manager = [...];
    CDTDatastore *datastore = [...];
    CDTReplicatorFactory *replicatorFactory = [...];

    NSURL *remote = [NSURL URLwithString:@"https://account.cloudant.com/myremotedb"];

    CDTPullReplication* pull = [CDTPullReplication replicationWithSource: remote
                                                                  target: datastore
                                                                username: "user"
                                                                password: "password"];

    NSError *error;
    CDTReplicator *rep = [replicatorFactory oneWay:pull error:&error];

    //check for error
    [rep start];

 */

@interface CDTPullReplication : CDTAbstractReplication <NSCopying>

/**
 @name Creating a replication configuration
 */

/** All CDTPullReplication objects must have a source and target.

  This is the same as calling [CDTPullReplication replicationWithSource: source target:target username: nil password: nil]

 @param source the remote server URL from which the data is replicated, if this contains user info
        it will be removed from the URL and replaced with CDTSessionCookieInterceptor
 @param target the local datastore to which the data is replicated.
 @return a CDTPullReplication object.

 */
+ (nonnull instancetype)replicationWithSource:(nonnull NSURL *)source
                                       target:(nonnull CDTDatastore *)target;

/** All CDTPullReplication objects must have a source and target.

 @param source the remote server URL from which the data is replicated, if this contains user info
        it will be removed from the URL and replaced with CDTSessionCookieInterceptor.
 @param target the local datastore to which the data is replicated.
 @param username the username to use when authenticating with the remote database.
 @param password the password to use when authenticating with the remote datbase.
 @return a CDTPullReplication object.

 @warning If credentials are included with the source URL and in the parameters, the credentials in the source URL
 will be ignored.

 */
+ (instancetype)replicationWithSource:(NSURL *)source
                               target:(CDTDatastore *)target
                             username:(nullable NSString *)username
                             password:(nullable NSString *)password;

/**
 * All CDTPullReplication objects must have a source and target.
 *
 * The CDTPullReplication uses an IAM API key to authenticate - see
 * https://console.bluemix.net/docs/services/Cloudant/guides/iam.html#ibm-cloud-identity-and-access-management
 * for more information about IAM.
 *
 * @param IAMAPIKey The IAM API key.
 * @return an initialsed instance of CDTAbstractReplication.
 */
+ (instancetype)replicationWithSource:(NSURL *)source
                               target:(CDTDatastore *)target
                            IAMAPIKey:(NSString *)IAMAPIKey;


/**
 @name Accessing the replication source and target
 */

/** The CDTDatastore to which the data is replicated.
 */
@property (nonnull, nonatomic, strong, readonly) CDTDatastore *target;

/** The NSURL for the remote datastore:

     protocol://host[:port]/remoteDatabaseName

 Only _http_ and _https_ are valid protocols.

 Consider using NSURLComponents if you need to set each component individually.

 @see CDTAbstractReplication.
 */
@property (nonnull, nonatomic, strong, readonly) NSURL *source;

/**
 @name Filtered pull replication
 */

/** The name of the filter to be used on the remote source.

 If this property is nil, the default, then no filter is used in the replication.

 See the Cloudant/CouchDB documentation on replication and filter functions.

 *
 [http://docs.cloudant.com/guides/replication/replication.html#filtered-replication](http://docs.cloudant.com/guides/replication/replication.html#filtered-replication)
 *
 [http://docs.couchdb.org/en/latest/couchapp/ddocs.html#filter-functions](http://docs.couchdb.org/en/latest/couchapp/ddocs.html#filter-functions)
 *
 [http://docs.couchdb.org/en/latest/json-structure.html#replication-settings](http://docs.couchdb.org/en/latest/json-structure.html#replication-settings)

 Filter functions in Cloudant/CouchDB are passed two arguments: a document revision and a
 request header.

    function(doc, request){ ... }

 Additional parameters to the filter function may be passed in via the `request.query` object.
 In CloudantSync, these parameters are specified with the [CDTPullReplication filterParams]
 property.

 Consider a design document on the remote server called "_design/users" with a filter function
 called "by_age_range":

    function(doc, req){
        var age = doc['user']['age'];

        if (age >= req.query.min && age <= req.query.max)
            return true;
        else
            return false;
    }

 Documents in this database have the following key-value structure
    {
        '_id':'foo',
        '_rev': '1-x',
        'user': {
                    'age' : 34
                }
        ...
    }

 Modifying the example above, in order to replicate from the remote database to the local
 datastore using this filter, specify:

    pull.filter = @"users/by_age_range";
    pull.filterParams = @{@"min":@23, @"max":@43};

 before calling:

    CDTReplicator *rep = [replicatorFactory oneWay:pull error:&error];

 The filter function acts on the document revisions found in the _changes feed,
 filtering the entries that appear.

 See the following for more information:

 * http://docs.couchdb.org/en/latest/replication/protocol.html
 * http://docs.couchdb.org/en/latest/api/database/changes.html


 */
@property (nullable, nonatomic, copy) NSString *filter;

/** The filter function query parameters

 @see -filter
 */
@property (nullable, nonatomic, copy) NSDictionary *filterParams;

@end

NS_ASSUME_NONNULL_END
