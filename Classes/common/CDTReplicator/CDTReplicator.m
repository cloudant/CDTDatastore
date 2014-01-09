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

const NSString *CDTReplicatorLog = @"CDTReplicator";

@interface CDTReplicator ()

@property (nonatomic,strong) CDTDatastore *replicatorDb;
@property (nonatomic,strong) CDTDocumentBody *body;
@property (nonatomic,strong) NSString *replicationDocumentId;
@property (nonatomic) CDTReplicatorState mState;

- (void) dbChanged: (NSNotification*)n;

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
        _mState = CDTReplicatorStatePending;
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
                                                 name: TD_DatabaseChangeNotification
                                               object: self.replicatorDb.database];

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

    [self updatedStateFromRevision:rev.td_rev];
}

-(void)stop
{
    self.mState = CDTReplicatorStateStopping;

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
}


/**
 * Notified that a _replicator database document has been created/updated/deleted.
 * We need to update our state if it's our document.
 */
- (void) dbChanged: (NSNotification*)n {
    LogTo(CDTReplicatorLog, @"CDTReplicator: dbChanged");
    TD_Revision* rev = (n.userInfo)[@"rev"];
    LogTo(CDTReplicatorLog, @"CDTReplicator: %@ %@", n.name, rev);
    [self updatedStateFromRevision:rev];
}

-(void)updatedStateFromRevision:(TD_Revision*)rev {
    NSString* docID = rev.docID;
    if (![docID isEqualToString:self.replicationDocumentId])
        return;

    LogTo(CDTReplicatorLog, @"CDTReplicator existing state: %@",
          [CDTReplicator stringForReplicatorState:self.mState]);

    if (rev.deleted) {
        // Should not happen, but we can assume completed
        self.mState = CDTReplicatorStateComplete;
    } else {
        NSString *state = rev[@"_replication_state"];

        if ([state isEqualToString:@"triggered"]) {
            self.mState = CDTReplicatorStateStarted;
        } else if ([state isEqualToString:@"error"]) {
            self.mState = CDTReplicatorStateError;
        } else if ([state isEqualToString:@"completed"]) {
            self.mState = CDTReplicatorStateComplete;
        } else {
            // probably nil, so pending as the replicator's not yet picked it up
            self.mState = CDTReplicatorStatePending;
        }
    }
    LogTo(CDTReplicatorLog, @"CDTReplicator new state: %@",
          [CDTReplicator stringForReplicatorState:self.mState]);
}

#pragma mark Status information

-(CDTReplicatorState)state
{
    if (self.replicationDocumentId == nil) {
        return CDTReplicatorStatePending;   // not started yet
    }

    return self.mState;
}

-(BOOL)isActive {
    CDTReplicatorState state = [self mState];
    return state == CDTReplicatorStatePending || state == CDTReplicatorStateStarted || state == CDTReplicatorStateStopping;
}

@end
