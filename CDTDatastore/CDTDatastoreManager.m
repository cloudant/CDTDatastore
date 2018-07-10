//
//  CSDatastoreManager.m
//  CloudantSyncLib
//
//  Created by Michael Rhodes on 04/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTDatastoreManager.h"
#import "CDTDatastore+EncryptionKey.h"
#import "CDTEncryptionKeyNilProvider.h"
#import "CDTLogging.h"

#import "TD_DatabaseManager.h"
#import "TD_Database.h"

NSString *const CDTDatastoreErrorDomain = @"CDTDatastoreErrorDomain";
NSString *const CDTExtensionsDirName = @"_extensions";

@interface CDTDatastoreManager ()

@property NSMutableDictionary<NSString*, CDTDatastore*> *openDatastores;

@end

@implementation CDTDatastoreManager

- (id)initWithDirectory:(NSString *)directoryPath error:(NSError **)outError
{
    self = [super init];
    if (self) {
        _openDatastores = [NSMutableDictionary dictionary];
        _manager =
            [[TD_DatabaseManager alloc] initWithDirectory:directoryPath options:nil error:outError];
        if (!_manager) {
            self = nil;
        }
    }

    return self;
}

- (CDTDatastore *)datastoreNamed:(NSString *)name error:(NSError *__autoreleasing *)error
{
    CDTEncryptionKeyNilProvider *provider = [CDTEncryptionKeyNilProvider provider];

    return [self datastoreNamed:name withEncryptionKeyProvider:provider error:error];
}

- (CDTDatastore *)datastoreNamed:(NSString *)name
       withEncryptionKeyProvider:(id<CDTEncryptionKeyProvider>)provider
                           error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        CDTDatastore *datastore = _openDatastores[name];
        if (datastore != nil) {
            CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"returning already open CDTDatastore %@", name);
            return datastore;
        }
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"opening new CDTDatastore %@", name);

        
        NSString *errorReason = nil;
        TD_Database *db = [self.manager databaseNamed:name];
        if (db) {
            datastore = [[CDTDatastore alloc] initWithManager:self database:db encryptionKeyProvider:provider];
            
            if (!datastore) {
                errorReason = NSLocalizedString(@"Wrong key?", nil);
            }
        } else {
            errorReason = NSLocalizedString(@"Invalid name?", nil);
        }
        
        if (!datastore && error) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey : NSLocalizedString(@"Couldn't create database.", nil),
                                       NSLocalizedFailureReasonErrorKey : errorReason,
                                       NSLocalizedRecoverySuggestionErrorKey : errorReason
                                       };
            *error = [NSError errorWithDomain:CDTDatastoreErrorDomain code:400 userInfo:userInfo];
        }
        
        if (datastore != nil) {
            _openDatastores[name] = datastore;
        }
        return datastore;
        
    }
}

- (void)closeDatastoreNamed:(NSString *)name {
    @synchronized (self) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"closing CDTDatastore %@", name);
        CDTDatastore *ds = _openDatastores[name];
        if (ds == nil) {
            // this may not be an issue if delete was already called and it was removed there
            CDTLogWarn(CDTDATASTORE_LOG_CONTEXT, @"can't find CDTDatastore to close %@", name);
            return;
        }
        [[ds database] close];
        [_openDatastores removeObjectForKey:name];
    }
}

- (void)dealloc {
    CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"-dealloc CDTDatastoreManager %@", self);
    [_openDatastores removeAllObjects];
    _manager = nil;
}

- (BOOL)deleteDatastoreNamed:(NSString *)name error:(NSError *__autoreleasing *)error
{
    @synchronized (self) {
        // first delete the SQLite database and any attachments
        NSError *localError = nil;
        BOOL success = [self.manager deleteDatabaseNamed:name error:&localError];
        if (!success && error) {
            if ([localError.domain isEqualToString:kTD_DatabaseManagerErrorDomain] &&
                (localError.code == kTD_DatabaseManagerErrorCodeInvalidName)) {
                localError = [NSError errorWithDomain:CDTDatastoreErrorDomain
                                                 code:404
                                             userInfo:localError.userInfo];
            }
            
            *error = localError;
        }
        
        if (success) {
            // delete any cloudant extensions
            // remove the open datastore: this ensures that any associated index manager has -dealloc
            // called on it _before_ we attempt to delete its underlying database
            CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"calling close from delete %@", name);
            [_openDatastores removeObjectForKey:name];
            NSString *dbPath = [self.manager pathForName:name];;
            NSString *extPath = [dbPath stringByDeletingLastPathComponent];
            extPath = [extPath
                       stringByAppendingPathComponent:[name stringByAppendingString:CDTExtensionsDirName]];
            
            NSFileManager *fm = [NSFileManager defaultManager];
            
            BOOL isDirectory;
            BOOL extenstionsExists = [fm fileExistsAtPath:extPath isDirectory:&isDirectory];
            if (extenstionsExists && isDirectory) {
                success = [fm removeItemAtPath:extPath error:&localError];
                if (!success && error) {
                    *error = localError;
                }
            }
        }
        
        return success;
    }
}

- (NSArray* /* NSString */) allDatastores
{
    return [self.manager allDatabaseNames];
}

@end
