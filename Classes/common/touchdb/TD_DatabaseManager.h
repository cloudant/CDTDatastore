//
//  TD_DatabaseManager.h
//  TouchDB
//
//  Created by Jens Alfke on 3/22/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright(c) 2014 Cloudant, Inc.

#import <Foundation/Foundation.h>
#import "TDStatus.h"

@protocol CDTEncryptionKey;

@class TD_Database, TDReplicator;
//@class TDReplicatorManager;

typedef struct TD_DatabaseManagerOptions {
    bool readOnly;
    bool noReplicator;
} TD_DatabaseManagerOptions;

extern const TD_DatabaseManagerOptions kTD_DatabaseManagerDefaultOptions;

/** Manages a directory containing TD_Databases. */
@interface TD_DatabaseManager : NSObject {
   @private
    NSString* _dir;
    TD_DatabaseManagerOptions _options;
    NSMutableDictionary* _databases;
}

+ (BOOL)isValidDatabaseName:(NSString*)name;

- (id)initWithDirectory:(NSString*)dirPath
                options:(const TD_DatabaseManagerOptions*)options
                  error:(NSError**)outError;

@property (readonly) NSString* directory;

- (TD_Database*)databaseNamed:(NSString*)name withEncryptionKey:(id<CDTEncryptionKey>)encryptionKey;
- (TD_Database*)existingDatabaseNamed:(NSString*)name
                    withEncryptionKey:(id<CDTEncryptionKey>)encryptionKey;

- (BOOL)deleteDatabaseNamed:(NSString*)name withEncryptionKey:(id<CDTEncryptionKey>)encryptionKey;

@property (readonly) NSArray* allDatabaseNames;
@property (readonly) NSArray* allOpenDatabases;

- (void)close;

- (TDStatus)validateReplicatorProperties:(NSDictionary*)properties;
- (TDReplicator*)replicatorWithProperties:(NSDictionary*)body status:(TDStatus*)outStatus;

#if DEBUG  // made public for testing (Adam Cox, Cloudant. 2014-1-20)
+ (TD_DatabaseManager*)createEmptyAtPath:(NSString*)path;
+ (TD_DatabaseManager*)createEmptyAtTemporaryPath:(NSString*)name;
#endif

@end
