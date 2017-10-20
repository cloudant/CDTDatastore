//
// Created by Rhys Short on 02/09/2016.
// Copyright © 2016 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import "CDTDatastore.h"
#import "CDTReplicatorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface CDTDatastore (Replication)

/**
 * Creates a push replicator.
 * @param target The URL of the remote database to push to.
 * @param delegate An optional delegate for the replication
 * @param error A pointer to an error that will be set if the replicator could not be created.
 * @param username          The username to authenticate with.
 * @param password          The password to authenticate with.
 * @return A push replicator.
 */
- (nullable CDTReplicator*) pushReplicationTarget:(NSURL*)target
                                         username:(nullable NSString*)username
                                         password:(nullable NSString*)password
                                     withDelegate:(nullable NSObject<CDTReplicatorDelegate>*)delegate
                                            error:(NSError *__autoreleasing *) error;

/**
 * Creates a push replicator.
 * @param target The URL of the remote database to push to.
 * @param delegate An optional delegate for the replication
 * @param error A pointer to an error that will be set if the replicator could not be created.
 * @param IAMAPIKey         IAM API Key to authenticate with.
 * @return A push replicator.
 */
- (nullable CDTReplicator*) pushReplicationTarget:(NSURL *)target
                               IAMAPIKey:(NSString *)IAMAPIKey
                            withDelegate:(NSObject <CDTReplicatorDelegate> *)delegate
                                   error:(NSError *__autoreleasing *)error;

/**
 * Creates a pull replicator.
 * @param source The URL of the database from which to pull.
 * @param delegate An optional delegate for the replication.
 * @param error A pointer to an error that will be set if the replicator could not be created.
 * @param username          The username to authenticate with.
 * @param password          The password to authenticate with.
 * @return A pull replicator.
 */
- (nullable CDTReplicator*) pullReplicationSource:(NSURL*)source
                                         username:(nullable NSString*) username
                                         password:(nullable NSString*)password
                                     withDelegate:(nullable NSObject<CDTReplicatorDelegate>*)delegate
                                            error:(NSError *__autoreleasing *) error;

/**
 * Creates a pull replicator.
 * @param source The URL of the database from which to pull.
 * @param delegate An optional delegate for the replication.
 * @param error A pointer to an error that will be set if the replicator could not be created.
 * @param IAMAPIKey         IAM API Key to authenticate with.
 * @return A pull replicator.
 */
- (nullable CDTReplicator*) pullReplicationSource:(NSURL *)source
                                        IAMAPIKey:(NSString *)IAMAPIKey
                                     withDelegate:(NSObject <CDTReplicatorDelegate> *)delegate
                                            error:(NSError *__autoreleasing *)error;


/**
 Asynchronously pushes data in this datastore to the server.

 @param target            The URL of the remote database to push the data to.
 @param completionHandler A block to call when the replication completes or errors.
 */
- (void) pushReplicationWithTarget:(NSURL*) target
                 completionHandler:(void (^ __nonnull)(NSError* __nullable)) completionHandler
         NS_SWIFT_NAME(push(to:completionHandler:));


/**
 Asynchronously pull data from a remote server to this local datastore.

 @param source            The URL of the remote database from which to pull data.
 @param completionHandler A block to call when the replication completes or errors.
 */
- (void) pullReplicationWithSource:(NSURL*) source
                 completionHandler:(void (^ __nonnull)(NSError* __nullable)) completionHandler
         NS_SWIFT_NAME(pull(from:completionHandler:));

/**
 Asynchronously pushes data in this datastore to the server.

 @param target            The URL of the remote database to push the data to.
 @param completionHandler A block to call when the replication completes or errors.
 @param username          The username to authenticate with.
 @param password          The password to authenticate with.
 */
- (void) pushReplicationWithTarget:(NSURL*) target
                          username:(nullable NSString*) username
                          password:(nullable NSString*) password
                 completionHandler:(void (^ __nonnull)(NSError* __nullable)) completionHandler
NS_SWIFT_NAME(push(to:username:password:completionHandler:));

/**
 Asynchronously pushes data in this datastore to the server.
 
 @param target            The URL of the remote database to push the data to.
 @param completionHandler A block to call when the replication completes or errors.
 @param IAMAPIKey         IAM API Key to authenticate with.
 */
- (void) pushReplicationWithTarget:(NSURL *)target
                        IAMAPIKey:(NSString *)IAMAPIKey
                completionHandler:(void (^ __nonnull)(NSError *__nullable))completionHandler
NS_SWIFT_NAME(push(to:IAMAPIKey:completionHandler:));

/**
 Asynchronously pull data from a remote server to this local datastore.

 @param source            The URL of the remote database from which to pull data.
 @param completionHandler A block to call when the replication completes or errors.
 @param username          The username to authenticate with.
 @param password          The password to authenticate with.
 */
- (void) pullReplicationWithSource:(NSURL*) source
                          username:(nullable NSString*) username
                          password:(nullable NSString*) password
                 completionHandler:(void (^ __nonnull)(NSError* __nullable)) completionHandler
NS_SWIFT_NAME(pull(from:username:password:completionHandler:));

/**
 Asynchronously pull data from a remote server to this local datastore.
 
 @param source            The URL of the remote database from which to pull data.
 @param completionHandler A block to call when the replication completes or errors.
 @param IAMAPIKey         IAM API Key to authenticate with.
 */
- (void) pullReplicationWithSource:(NSURL*) source
                         IAMAPIKey:(NSString *)IAMAPIKey
                 completionHandler:(void (^ __nonnull)(NSError* __nullable)) completionHandler
NS_SWIFT_NAME(pull(from:IAMAPIKey:completionHandler:));

@end

NS_ASSUME_NONNULL_END
