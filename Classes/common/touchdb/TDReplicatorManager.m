//
//  TDReplicatorManager.m
//  TouchDB
//
//  Created by Jens Alfke on 2/15/12.
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
//  http://wiki.apache.org/couchdb/Replication#Replicator_database
//  http://www.couchbase.com/docs/couchdb-release-1.1/index.html

#import "TDReplicatorManager.h"
#import "TD_Database.h"
#import "TD_Database+Insertion.h"
#import "TD_Database+Replication.h"
#import "TDPusher.h"
#import "TDPuller.h"
#import "TD_View.h"
#import "TDInternal.h"
#import "TDMisc.h"
#import "MYBlockUtils.h"
#import "CDTLogging.h"
#import "TDStatus.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIApplication.h>
#endif

@interface TDReplicatorManager ()
// replicator objects in this set will never be started.
// the queue block on the replication thread will exit immediately
@property (nonatomic, strong) NSMutableSet *cancelReplicator;
// replicator objects in this set have been started and
// cannot be canceled by TDReplicatorManager. (They can, however, still be stopped.)
@property (nonatomic, strong) NSMutableSet *replicatorStarted;

@end

@implementation TDReplicatorManager

- (id)initWithDatabaseManager:(TD_DatabaseManager *)dbManager
{
    self = [super init];
    if (self) {
        _dbManager = dbManager;
        _thread = [NSThread currentThread];
        _replicatorsBySessionID = [[NSMutableDictionary alloc] init];
        _cancelReplicator = [[NSMutableSet alloc] init];
        _replicatorStarted = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc { [self stop]; }

- (void)start
{
    if (_serverThread) return;  // we're already running a thread.

    _serverThread =
        [[NSThread alloc] initWithTarget:self selector:@selector(runServerThread) object:nil];
    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"Starting TDReplicatorManager thread %@ ...", _serverThread);
    [_serverThread start];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(someDbDeleted:)
                                                 name:TD_DatabaseWillBeDeletedNotification
                                               object:nil];
}

- (void)stop
{
    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"STOP %@", self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _replicatorsBySessionID = nil;
    _stopRunLoop = YES;
    _serverThread = nil;
}

- (NSString *)docIDForReplicator:(TDReplicator *)repl
{
    return [[_replicatorsBySessionID allKeysForObject:repl] lastObject];
}

#pragma mark - Replication thread management

/**
 * We want a server thread only for the replicator stuff.
 * Taken from TDServer.m.
 */
- (void)runServerThread
{
    @autoreleasepool
    {
        CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"TDReplicatorManager thread starting...");

        [[NSThread currentThread] setName:@"TDReplicatorManager"];
#ifndef GNUSTEP
        // Add a no-op source so the runloop won't stop on its own:
        CFRunLoopSourceContext context = {};  // all zeros
        CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &context);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
#endif

        // Now run:
        while (!_stopRunLoop &&
               [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                        beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]])
            ;

        CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"TDReplicatorManager thread exiting");
    }
}

- (void)queue:(void (^)())block
{
    Assert(_serverThread, @"-queue: called after -stop");
    MYOnThread(_serverThread, block);
}

- (TDReplicator *)createReplicatorWithProperties:(NSDictionary *)properties
                                           error:(NSError *__autoreleasing *)error
{
    TDStatus outStatus;
    TDReplicator *repl = [_dbManager replicatorWithProperties:properties status:&outStatus];

    if (!repl) {
        if (error) {
            *error = TDStatusToNSError(outStatus, nil);
        }
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"ReplicatorManager: Can't create replicator for %@",
                properties);
        return nil;
    }
    repl.sessionID = TDCreateUUID();

    _replicatorsBySessionID[repl.sessionID] = repl;

    return repl;
}

- (void)startReplicator:(TDReplicator *)repl
{
    if (![_replicatorsBySessionID objectForKey:repl.sessionID]) {
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"ReplicatorManager: You must create TDReplicators with "
                @"TDReplicatorManager -createReplicatorWithProperties. " @"Replicator not started");
        return;
    }

    __weak TDReplicatorManager *weakSelf = self;

    [self queue:^{
        __strong TDReplicatorManager *strongSelf = weakSelf;
        @synchronized(strongSelf)
        {
            if ([strongSelf.cancelReplicator containsObject:repl]) {
                return;
            }
            [strongSelf.replicatorStarted addObject:repl];
        }

        CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"ReplicatorManager: %@ (%@) was queued.", [repl class],
                repl.sessionID);

        [repl start];
    }];
}

- (BOOL)cancelIfNotStarted:(TDReplicator *)repl
{
    @synchronized(self)
    {
        if ([self.replicatorStarted containsObject:repl]) {
            return NO;
        }
        [self.cancelReplicator addObject:repl];
        return YES;
    }
}

#pragma mark - NOTIFICATIONS:

#pragma mark - NSNotifcationCenter handlers

// Notified that some database is being deleted; delete any associated replication document:
- (void)someDbDeleted:(NSNotification *)n
{
    TD_Database *db = n.object;
    if ([_dbManager.allOpenDatabases indexOfObjectIdenticalTo:db] == NSNotFound) return;
    NSString *dbName = db.name;

    TDQueryOptions options = kDefaultTDQueryOptions;
    options.includeDocs = YES;

    // loop through all replicators to see if any of them are pushing/pulling from
    // the deleted local database.
    for (NSString *replicationId in [_replicatorsBySessionID allKeys]) {
        TDReplicator *repl = [_replicatorsBySessionID objectForKey:replicationId];
        if ([repl.db.name isEqualToString:dbName]) {
            CDTLogInfo(CDTREPLICATION_LOG_CONTEXT,
                    @"ReplicatorManager: %@ (%@) stopped because local database was deleted",
                    [repl class], replicationId);

            [_replicatorsBySessionID removeObjectForKey:replicationId];

            NSString *msg =
                [NSString stringWithFormat:@"ReplicationManager stopped replication %@ (%@).",
                                           [repl class], replicationId];
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : NSLocalizedString(msg, nil)};

            repl.error = [NSError errorWithDomain:TDInternalErrorDomain
                                             code:TDReplicatorManagerErrorLocalDatabaseDeleted
                                         userInfo:userInfo];

            [repl stop];
        }
    }
}

@end
