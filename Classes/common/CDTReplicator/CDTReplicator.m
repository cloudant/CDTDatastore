//
//  CDTReplicator.m
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTReplicator.h"

#import "CDTReplicatorFactory.h"
#import "CDTDocumentRevision.h"

#import "TD_Revision.h"
#import "TD_Database.h"
#import "TDReplicator.h"
#import "TDReplicatorManager.h"

const NSString *CDTReplicatorLog = @"CDTReplicator";

@interface CDTReplicator ()

@property (nonatomic,strong) TDReplicatorManager *replicatorManager;
@property (nonatomic,strong) NSDictionary *properties;
@property (nonatomic, strong) TDReplicator *tdReplicator;

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

-(id)initWithTDReplicatorManager:(TDReplicatorManager*)replicatorManager
           replicationProperties:(NSDictionary*)properties;
{
    if (replicatorManager == nil || properties == nil) {
        return nil;
    }

    self = [super init];
    if (self) {
        _replicatorManager = replicatorManager;
        _properties = properties;
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
    if (self.tdReplicator.running) {
        LogTo(CDTReplicatorLog, @"start: Already running.");
        return;
    }
    
    //TDReplicator's can't be restarted, so always instantiate a new one.
    self.tdReplicator = [self.replicatorManager createReplicatorWithProperties:self.properties];
    
    if (!self.tdReplicator) {
        Warn(@"CDTReplicator -start. Unable to instantiate TDReplicator!");
        self.state = CDTReplicatorStateError;
        return;
    }
    
    self.changesTotal = self.changesProcessed = 0;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(replicatorStopped:)
                                                 name: TDReplicatorStoppedNotification
                                               object: self.tdReplicator];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(replicatorProgressChanged:)
                                                 name: TDReplicatorProgressChangedNotification
                                               object: self.tdReplicator];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(replicatorStarted:)
                                                 name: TDReplicatorStartedNotification
                                               object: self.tdReplicator];
    
    // queues the replication on the TDReplicatorManager's replication thread
    [self.replicatorManager startReplicator:self.tdReplicator];
    
    LogTo(CDTReplicatorLog, @"start: ReplicationManager starting %@, sessionID %@",
          [self.tdReplicator class], self.tdReplicator.sessionID);

}

-(void)stop
{
    if (self.state == CDTReplicatorStateStopping ||
        self.state == CDTReplicatorStateStopped )
        return;
    
    self.state = CDTReplicatorStateStopping;

    id<CDTReplicatorDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(replicatorDidChangeState:)]) {
        [delegate replicatorDidChangeState:self];
    }
    
    [self.tdReplicator stop];
}


// Notified that a TDReplicator has stopped:
- (void) replicatorStopped: (NSNotification*)n {
    TDReplicator* repl = n.object;
    
    LogTo(CDTReplicatorLog, @"replicatorStopped: %@. type: %@ sessionId: %@", n.name,
          [repl class], repl.sessionID);
    
    [self updatedStateFromReplicator];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:self.tdReplicator];
    
}

// Notified that a TDReplicator has started:
- (void) replicatorStarted: (NSNotification*)n {
    TDReplicator* repl = n.object;
    
    LogTo(CDTReplicatorLog, @"replicatorStarted: %@ type: %@ sessionId: %@", n.name,
          [repl class], repl.sessionID);
    
    [self updatedStateFromReplicator];
}

/*
 * Called when progress has been reported by the TDReplicator.
 */
-(void) replicatorProgressChanged: (NSNotification *)n
{
    [self updatedStateFromReplicator];
}

-(void)updatedStateFromReplicator
{

    BOOL progressChanged = NO;
    if (self.changesProcessed != self.tdReplicator.changesProcessed ||
        self.changesTotal != self.tdReplicator.changesTotal) {

        self.changesProcessed = self.tdReplicator.changesProcessed;
        self.changesTotal = self.tdReplicator.changesTotal;
        progressChanged = YES;
    }
    
    CDTReplicatorState oldState = self.state;

    if (self.tdReplicator.running)
        self.state = CDTReplicatorStateStarted;
    else if (self.tdReplicator.error)
        self.state = CDTReplicatorStateError;
    else
        self.state = CDTReplicatorStateComplete;

    
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
        [delegate replicatorDidError:self info:self.tdReplicator.error];
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
