//
//  CDTReplicator.m
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//
//

#import "CDTReplicator.h"

#import "CDTDatastore.h"
#import "CDTDocumentRevision.h"

#import "TD_Revision.h"
#import "TD_Database.h"
#import "TDReplicator.h"

const NSString *CDTReplicatorLog = @"CDTReplicator";

@interface CDTReplicator ()

@property (nonatomic,strong) CDTDatastore *replicatorDb;
@property (nonatomic,strong) CDTDocumentBody *body;
@property (nonatomic,strong) NSString *replicationDocumentId;

- (void) dbChanged: (NSNotification*)n;

// private readwrite properties
@property (nonatomic, readwrite) CDTReplicatorState state;
@property (nonatomic, readwrite) NSInteger changesProcessed;
@property (nonatomic, readwrite) NSInteger changesTotal;

@end

@implementation CDTReplicator

+(NSString*)stringForReplicatorState:(CDTReplicatorState)state {
    switch (state) {
        case CDTReplicatorStatePending:
            return @"CDTReplicatorStatePending";
        case CDTReplicatorStateStarted:
            return @"CDTReplicatorStateStarted";
        case CDTReplicatorStateStopped:
            return @"CDTReplicatorStateStopped";
        case CDTReplicatorStateStopping:
            return @"CDTReplicatorStateStopping";
        case CDTReplicatorStateComplete:
            return @"CDTReplicatorStateComplete";
        case CDTReplicatorStateError:
            return @"CDTReplicatorStateError";

    }
}

#pragma mark Initialise

-(id)initWithReplicatorDatastore:(CDTDatastore*)replicatorDb
         replicationDocumentBody:(CDTDocumentBody*)body;
{
    if (replicatorDb == nil || body == nil) {
        return nil;
    }

    self = [super init];
    if (self) {
        _replicatorDb = replicatorDb;
        _body = body;
        _state = CDTReplicatorStatePending;
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark Lifecycle

-(void)start
{
    NSError *error;

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(dbChanged:)
                                                 name: CDTDatastoreChangeNotification
                                               object: self.replicatorDb];

    // starts the replication immediately
    CDTDocumentRevision *rev = [self.replicatorDb createDocumentWithBody:self.body
                                                                   error:&error];
    if (error != nil) {
        LogTo(CDTReplicatorLog, @"start: Error starting replication: %@", error);
    } else {
        LogTo(CDTReplicatorLog, @"start: Replication document added");
    }

    // We only store the docId as the rev will change as the replicator
    // updates the state of the replication so the revId will be changing.
    self.replicationDocumentId = rev.docId;
    LogTo(CDTReplicatorLog, @"start: Replication document ID: %@", self.replicationDocumentId);

    [self updatedStateFromRevision:rev];
}

-(void)stop
{
    // We change straight to stopped, as we can't introspect
    // the underlying TDReplicator instance.
    self.state = CDTReplicatorStateStopped;

    if (self.replicationDocumentId == nil) {
        return;   // not started yet
    }

    NSError *error;

    // We have to get the latest version as the we need the revId
    // for deleting.
    // TODO revision could be changed before we delete.
    CDTDocumentRevision *current = [self.replicatorDb getDocumentWithId:self.replicationDocumentId
                                                                  error:&error];

    if (error != nil) {
        LogTo(CDTReplicatorLog, @"Error stopping replication: %@", error);
    } else {
        LogTo(CDTReplicatorLog, @"Replication document deleted");
    }

    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [self.replicatorDb deleteDocumentWithId:current.docId
                                        rev:current.revId
                                      error:&error];

    id<CDTReplicatorDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(replicatorDidChangeState:)]) {
        [delegate replicatorDidChangeState:self];
    }
    if ([delegate respondsToSelector:@selector(replicatorDidComplete:)]) {
        [delegate replicatorDidComplete:self];
    }
}

/*
 * Notified that a _replicator database document has been created/updated/deleted.
 * We need to update our state if it's our document.
 */
- (void) dbChanged: (NSNotification*)n {
    CDTDocumentRevision* rev = (n.userInfo)[@"rev"];
//    LogTo(CDTReplicatorLog, @"CDTReplicator: %@ %@", n.name, rev);
    [self updatedStateFromRevision:rev];
}

/*
 * Called when the replication document in the _replicator database has changed.
 */
-(void)updatedStateFromRevision:(CDTDocumentRevision*)rev {
    NSString* docID = rev.docId;
    if (![docID isEqualToString:self.replicationDocumentId])
        return;

//    LogTo(CDTReplicatorLog, @"CDTReplicator existing state: %@",
//          [CDTReplicator stringForReplicatorState:self.state]);

//    NSLog(@"updatedStateFromRevion got: %@", rev.documentAsDictionary);

    NSDictionary *body = [rev documentAsDictionary];

    BOOL progressChanged = NO;
    NSDictionary *stats = [body objectForKey:@"_replication_stats"];
    if (nil != stats) {
        self.changesProcessed = [((NSNumber*)stats[@"changesProcessed"]) integerValue];
        self.changesTotal = [((NSNumber*)stats[@"changesTotal"]) integerValue];
        progressChanged = YES;
    }

    CDTReplicatorState oldState = self.state;

    if (rev.deleted) {
        // Should not happen, but we can assume completed
        self.state = CDTReplicatorStateComplete;
    } else {
        NSString* state = [rev documentAsDictionary][@"_replication_state"];

        if ([state isEqualToString:@"triggered"]) {
            self.state = CDTReplicatorStateStarted;
        } else if ([state isEqualToString:@"error"]) {
            self.state = CDTReplicatorStateError;
        } else if ([state isEqualToString:@"completed"]) {
            self.state = CDTReplicatorStateComplete;
        } else {
            // probably nil, so pending as the replicator's not yet picked it up
            self.state = CDTReplicatorStatePending;
        }
    }

//    LogTo(CDTReplicatorLog, @"CDTReplicator new state: %@",
//          [CDTReplicator stringForReplicatorState:self.state]);

    // Lots of possible delegate messages at this point
    id<CDTReplicatorDelegate> delegate = self.delegate;

    if (progressChanged && [delegate respondsToSelector:@selector(replicatorDidChangeProgress:)])
    {
        [delegate replicatorDidChangeProgress:self];
    }

    BOOL stateChanged = (oldState != self.state);
    if (stateChanged && [delegate respondsToSelector:@selector(replicatorDidChangeState:)])
    {
        [delegate replicatorDidChangeState:self];
    }

    // We're completing this time if we're transitioning from an active state into an inactive
    // non-error state.
    BOOL completingTransition = (stateChanged && self.state != CDTReplicatorStateError &&
                                 [self isActiveState:oldState] &&
                                 ![self isActiveState:self.state]);
    if (completingTransition && [delegate respondsToSelector:@selector(replicatorDidComplete:)]) {
        [delegate replicatorDidComplete:self];
    }

    // We've errored if we're transitioning from an active state into an error state.
    BOOL erroringTransition = (stateChanged && self.state == CDTReplicatorStateError &&
                               [self isActiveState:oldState]);
    if (erroringTransition && [delegate respondsToSelector:@selector(replicatorDidError:info:)]) {
        [delegate replicatorDidError:self info:nil];
    }
}

#pragma mark Status information

-(BOOL)isActive {
    return [self isActiveState:self.state];
}

/*
 * Returns whether `state` is an active state for the replicator.
 */
-(BOOL)isActiveState:(CDTReplicatorState)state
{
    return state == CDTReplicatorStatePending ||
    state == CDTReplicatorStateStarted ||
    state == CDTReplicatorStateStopping;
}

@end
