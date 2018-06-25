//
//  TD_DatabaseManager.m
//  TouchDB
//
//  Created by Jens Alfke on 3/22/12.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.

#import "TD_DatabaseManager.h"
#import "TD_Database.h"
#import "TDPusher.h"
#import "TDInternal.h"
#import "TDMisc.h"
#import "CDTLogging.h"
#import "CollectionUtils.h"
#import "Test.h"

const TD_DatabaseManagerOptions kTD_DatabaseManagerDefaultOptions;

NSString *const kTD_DatabaseManagerErrorDomain = @"kTD_DatabaseManagerErrorDomain";
NSUInteger const kTD_DatabaseManagerErrorCodeInvalidName = 404;

const NSString* TD_Server = @"TD_Server";

@implementation TD_DatabaseManager

#define kDBExtension @"touchdb"

// http://wiki.apache.org/couchdb/HTTP_database_API#Naming_and_Addressing
#define kLegalChars @"abcdefghijklmnopqrstuvwxyz0123456789_$()+-/"
static NSCharacterSet* kIllegalNameChars;

+ (void)initialize
{
    if (self == [TD_DatabaseManager class]) {
        kIllegalNameChars =
            [[NSCharacterSet characterSetWithCharactersInString:kLegalChars] invertedSet];
    }
}

+ (TD_DatabaseManager*)createEmptyAtPath:(NSString*)path
{
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    NSError* error;
    TD_DatabaseManager* dbm = [[self alloc] initWithDirectory:path options:NULL error:&error];
    Assert(dbm, @"Failed to create db manager at %@: %@", path, error);
    AssertEqual(dbm.directory, path);
    return dbm;
}

+ (TD_DatabaseManager*)createEmptyAtTemporaryPath:(NSString*)name
{
    return [self createEmptyAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

- (id)initWithDirectory:(NSString*)dirPath
                options:(const TD_DatabaseManagerOptions*)options
                  error:(NSError**)outError
{
    self = [super init];
    if (self) {
        _dir = [dirPath copy];
        _databases = [[NSMutableDictionary alloc] init];
        _options = options ? *options : kTD_DatabaseManagerDefaultOptions;

        // Create the directory but don't fail if it already exists:
        NSError* error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:_dir
                                       withIntermediateDirectories:NO
                                                        attributes:nil
                                                             error:&error]) {
            BOOL isDir;
            if (!TDIsFileExistsError(error) ||
                ([[NSFileManager defaultManager] fileExistsAtPath:_dir isDirectory:&isDir] &&
                 !isDir)) {
                if (outError) *outError = error;
                return nil;
            }
        }
    }
    return self;
}

- (void)dealloc
{
    CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"DEALLOC %@", self);
    [self close];
}

@synthesize directory = _dir;

#pragma mark - DATABASES:

+ (BOOL)isValidDatabaseName:(NSString*)name
{
    if (name.length > 0 && [name rangeOfCharacterFromSet:kIllegalNameChars].length == 0 &&
        islower([name characterAtIndex:0]) && ![name hasSuffix:@"_extensions"]) {
        return YES;
    } else {
        return NO;
    }
}

- (NSString*)pathForName:(NSString*)name
{
    if (![[self class] isValidDatabaseName:name]) return nil;
    name = [name stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    return [_dir stringByAppendingPathComponent:[name stringByAppendingPathExtension:kDBExtension]];
}

- (TD_Database*)databaseNamed:(NSString*)name
{
    @synchronized(self) {
        TD_Database* db = _databases[name];
        if (!db) {
            NSString* path = [self pathForName:name];
            if (!path) {
                CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"Database name not valid");
            } else {
                db = [[TD_Database alloc] initWithPath:path];
                if (_options.readOnly && !db.exists) {
                    CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Read-only db does not exist. Return nil");
                    
                    db = nil;
                } else {
                    db.name = name;
                    db.readOnly = _options.readOnly;
                    
                    _databases[name] = db;
                }
            }
        }
        
        return db;
    }
}

- (BOOL)deleteDatabaseNamed:(NSString *)name error:(NSError *__autoreleasing *)error
{
    @synchronized(self) {
        BOOL success = NO;
        
        TD_Database *db = _databases[name];
        if (db) {
            // Do not simply delete the files, use instance method
            success = [db deleteDatabase:error];
            if (success) {
                // Release cache
                [_databases removeObjectForKey:name];
            }
        } else {
            // Database not loaded in memory. Delete the files
            NSString *path = [self pathForName:name];
            if (path) {
                success = [TD_Database deleteClosedDatabaseAtPath:path error:error];
            } else if (error) {
                NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey : NSLocalizedString(@"Couldn't delete database.", nil),
                                           NSLocalizedFailureReasonErrorKey : NSLocalizedString(@"Invalid name?", nil),
                                           NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"Invalid name?", nil)
                                           };
                *error = [NSError errorWithDomain:kTD_DatabaseManagerErrorDomain
                                             code:kTD_DatabaseManagerErrorCodeInvalidName
                                         userInfo:userInfo];
            }
        }
        
        return success;
    }
}

- (NSArray*)allDatabaseNames
{
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_dir error:NULL];
    files = [files pathsMatchingExtensions:@[ kDBExtension ]];
    return [files my_map:^(id filename) {
        return [[filename stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@":"
                                                                                   withString:@"/"];
    }];
}

- (NSArray*) allOpenDatabases {
    return _databases.allValues;
}

- (void) close {
    @synchronized(self) {
        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"CLOSING %@ ...", self);
        for (TD_Database* db in _databases.allValues) {
            [db close];
        }
        [_databases removeAllObjects];
        CDTLogInfo(CDTDATASTORE_LOG_CONTEXT, @"CLOSED %@", self);
    }
}

@end
