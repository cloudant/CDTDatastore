//
//  CSDatastoreManager.h
//  CloudantSyncLib
//
//  Created by Michael Rhodes on 04/07/2013.
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

extern NSString *const CDTDatastoreErrorDomain;

@protocol CDTEncryptionKeyRetrieving;

@class CDTDatastore;
@class TD_DatabaseManager;

/**
 A CDTDatastoreManager manages a group of CDTDatastores. It also manages
 the behind the scenes threading details to ensure the underlying SQLite
 database is accessed safely.

 @see CDTDatastore
 */
@interface CDTDatastoreManager : NSObject

@property (nonatomic, strong, readonly) TD_DatabaseManager *manager;

/**
 Initialises the datastore manager with a directory where the files will be persisted.

 @param directoryPath  directory for files. This must exist.
 @param outError will point to an NSError object in case of error.
 */
- (id)initWithDirectory:(NSString *)directoryPath error:(NSError **)outError;

/**
 Returns a datastore for the given name. Data in the datastore is not encrypted.
 If not key is provided at the moment the datastore is created, it can not be encrypted later on.

 @param name datastore name
 @param error will point to an NSError object in case of error.

 @see CDTDatastore
 */
- (CDTDatastore *)datastoreNamed:(NSString *)name error:(NSError *__autoreleasing *)error;

/**
 Returns a datastore for the given name. If a key is provided, datastore files are encrypted before
 saving to disk (attachments and extensions not included).
 If a key is provided the first time the datastore is open, only this key will be valid the next
 time. In the same way, if no key is informed, the datastore will not be cipher and can not be
 cipher later on.

 @param name datastore name
 @param retriever it returns the key to cipher the datastore
 @param error will point to an NSError object in case of error.

 @see CDTDatastore
 */
- (CDTDatastore *)datastoreNamed:(NSString *)name
      withEncryptionKeyRetriever:(id<CDTEncryptionKeyRetrieving>)retriever
                           error:(NSError *__autoreleasing *)error;

/**
 Deletes a datastore for the given name.

 All datastore files, including attachments and extensions, are deleted.

 Currently it is the responsibility of the caller to ensure that extensions should be shutdown (and
 their underlying databases closed) before calling this method.

 @param name datastore name
 @param error will point to an NSError object in case of error.

 */
- (BOOL)deleteDatastoreNamed:(NSString *)name error:(NSError *__autoreleasing *)error;

/**
 Deletes a datastore for the given name. If the datastore is encrypted, the same key used to open
 it has to be provided to delete it.

 All datastore files, including attachments and extensions, are deleted.

 Currently it is the responsibility of the caller to ensure that extensions should be shutdown (and
 their underlying databases closed) before calling this method.

 @param name datastore name
 @param retriever it returns the key to cipher the datastore
 @param error will point to an NSError object in case of error.

 */
- (BOOL)deleteDatastoreNamed:(NSString *)name
    withEncryptionKeyRetriever:(id<CDTEncryptionKeyRetrieving>)encryptionKey
                         error:(NSError *__autoreleasing *)error;

/**

 Returns an array of datastore names (NSString) that are managed by this CDTDatastoreManager.

 */
- (NSArray * /* NSString */)allDatastores;

@end
