//
//  CSDatastoreManager.h
//  CloudantSyncLib
//
//  Created by Michael Rhodes on 04/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const CDTDatastoreErrorDomain;

@class CDTDatastore;

/**
 * A CDTDatastoreManager manages a group of CDTDatastores. It also manages
 * the behind the scenes threading details to ensure the underlying SQLite
 * database is accessed safely.
 */
@interface CDTDatastoreManager : NSObject

/**
 * Initialises the datastore manager with a directory where the files
 * for datastores are persisted to disk.
 *
 * @param directoryPath  directory for files. This must exist.
 * @param outError  any errors will be delivered through this parameter.
 */
-(id)initWithDirectory:(NSString*)directoryPath
                 error:(NSError**)outError;

/**
 * Returns a datastore for the given name.
 */
-(CDTDatastore *)datastoreNamed:(NSString*)name
                          error:(NSError * __autoreleasing *)error;

@end
