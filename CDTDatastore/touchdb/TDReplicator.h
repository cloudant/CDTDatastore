//
//  TDReplicator.h
//  TouchDB
//
//  Created by Jens Alfke on 12/6/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.
//

#import <Foundation/Foundation.h>
#import "CDTURLSession.h"

@class TD_Database, TD_RevisionList, TDBatcher, TDReachability;
@protocol TDAuthorizer;

/** Posted when replicator starts running. */
extern NSString* _Nullable TDReplicatorStartedNotification;

/** Posted when changesProcessed or changesTotal changes. */
extern NSString* _Nullable TDReplicatorProgressChangedNotification;

/** Posted when replicator stops running. */
extern NSString* _Nullable TDReplicatorStoppedNotification;

/** Abstract base class for push or pull replications. */
@interface TDReplicator : NSObject {
   @protected
    NSThread* _thread;
    TD_Database* __weak _db;
    NSURL* _remote;
    BOOL _continuous;
    NSString* _filterName;
    NSDictionary* _filterParameters;
    NSArray* _docIDs;
    NSObject* _lastSequence;
    BOOL _lastSequenceChanged;
    NSDictionary* _remoteCheckpoint;
    BOOL _savingCheckpoint, _overdueForSave;
    BOOL _running, _online, _active;
    unsigned _revisionsFailed;
    NSError* _error;
    NSString* _sessionID;
    TDBatcher* _batcher;
    NSMutableArray* _remoteRequests;
    int _asyncTaskCount;
    NSUInteger _changesProcessed, _changesTotal;
    CFAbsoluteTime _startTime;
    id<TDAuthorizer> _authorizer;
    NSDictionary* _requestHeaders;
   @private
    TDReachability* _host;
}

+ (NSString*_Nullable)progressChangedNotification;
+ (NSString*_Nullable)stoppedNotification;

- (instancetype _Nullable )initWithDB:(TD_Database*_Nullable)db
                               remote:(NSURL*_Nullable)remote
                      push:(BOOL)push
                continuous:(BOOL)continuous
                         interceptors:(NSArray*_Nullable)interceptors;

@property (weak, readonly) TD_Database* _Nullable db;
@property (readonly) NSURL* _Nullable remote;
@property (readonly) BOOL isPush;
@property (readonly) BOOL continuous;
@property (copy) NSString* _Nullable filterName;
@property (copy) NSDictionary* _Nullable filterParameters;
@property (copy) NSArray* _Nullable docIDs;

/** Whether to ignore saved changes feed checkpoints */
@property (nonatomic) BOOL reset;

/** Heartbeat value used for _changes requests during pull (in ms) */
@property (nonatomic) NSNumber* _Nullable heartbeat;

@property (nonatomic, strong,readonly) CDTURLSession * _Nullable session;
@property (nonatomic, weak) NSObject<CDTNSURLSessionConfigurationDelegate> * _Nullable sessionConfigDelegate;

/** Access to the replicator's NSThread execution state.*/
/** NSThread.executing*/
-(BOOL) threadExecuting;
/** NSThread.finished*/
-(BOOL) threadFinished;
/** NSThread.canceled*/
-(BOOL) threadCanceled;

/** Optional dictionary of headers to be added to all requests to remote servers. */
@property (copy) NSDictionary* _Nullable requestHeaders;

@property (strong) id<TDAuthorizer> _Nullable authorizer;

/** Do these two replicators have identical settings? */
- (bool)hasSameSettingsAs:(TDReplicator*_Nullable)other;

/** Starts the replicator.
    Replicators run asynchronously so nothing will happen until later.
    A replicator can only be started once; don't reuse it after it stops.

    @param taskGroup The dispatch_group_t to make the replicators part of.
 */
- (void)startWithTaskGroup:(dispatch_group_t _Nullable )taskGroup;

/** Request to stop the replicator.
    Any pending asynchronous operations will be canceled.
    TDReplicatorStoppedNotification will be posted when it finally stops. */
- (void)stop;

/** Attempt to cancel the replicator before it is executed on its thread */
- (BOOL) cancelIfNotStarted;

/** Is the replicator running? (Observable) */
@property (readonly, nonatomic) BOOL running;

/** Is the replicator able to connect to the remote host? */
@property (readonly, nonatomic) BOOL online;

/** Is the replicator actively sending/receiving revisions? (Observable) */
@property (readonly, nonatomic) BOOL active;

/** Latest error encountered while replicating.
    This is set to nil when starting. It may also be set to nil by the client if desired.
    Not all errors are fatal; if .running is still true, the replicator will retry. */
@property (strong, nonatomic) NSError* _Nullable error;

/** A unique-per-process string identifying this replicator instance. */
@property (copy, nonatomic) NSString* _Nullable sessionID;

/** Number of changes (docs or other metadata) transferred so far. */
@property (readonly, nonatomic) NSUInteger changesProcessed;

/** Approximate total number of changes to transfer.
    This is only an estimate and its value will change during replication. */
@property (readonly, nonatomic) NSUInteger changesTotal;

/** JSON-compatible array of status info about active remote HTTP requests. */
@property (readonly) NSArray* _Nullable activeRequestsStatus;

/** Exposed for testing. Returns the doc ID for the checkpoint document. */
- (NSString *_Nullable)remoteCheckpointDocID;

/** Completion Block to return results. It returns two values Response and Error. Both are optional objects and can have nil value.*/
typedef void(^ __nonnull ReplicatorTestCompletionHandler)(id __nullable response, NSError* __nullable error);


/**
 This test function will be used to test end point _local/{docId} .
 We're assuming to get an response in return of this api. and not an error.
 @param completionHandler A completion hanlder to return the response we got from the API call.
 */
- (void)testEndPointLocal:(ReplicatorTestCompletionHandler) completionHandler;

/**
 This test function will be used to test end point _bulk_get .
 We're assuming to get an response in return of this api. and not an error.
 @param completionHandler A completion hanlder to return the response we got from the API call.
 */
- (void)testBulkGet:(NSDictionary* _Nullable)requestBody handler:(ReplicatorTestCompletionHandler) completionHandler;

-(void) startReplicationThread:(dispatch_group_t _Nonnull )taskGroup;
@end
