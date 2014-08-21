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
#import "CDTPullReplication.h"
#import "CDTPushReplication.h"

#import "TD_Revision.h"
#import "TD_Database.h"
#import "TDPusher.h"
#import "TDPuller.h"
#import "TDReplicatorManager.h"

const NSString *CDTReplicatorLog = @"CDTReplicator";
static NSString* const CDTReplicatorErrorDomain = @"CDTReplicatorErrorDomain";

@interface CDTReplicator ()

@property (nonatomic, strong) TDReplicatorManager *replicatorManager;
@property (nonatomic, strong) TDReplicator *tdReplicator;
@property (nonatomic, copy)   CDTAbstractReplication* cdtReplication;
@property (nonatomic, strong) NSDictionary *replConfig;
// private readwrite properties
@property (nonatomic, readwrite) CDTReplicatorState state;
@property (nonatomic, readwrite) NSInteger changesProcessed;
@property (nonatomic, readwrite) NSInteger changesTotal;

@property (nonatomic, copy) CDTFilterBlock pushFilter;
@property (nonatomic) BOOL started;

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
                     replication:(CDTAbstractReplication*)replication
                           error:(NSError * __autoreleasing*)error
{
    if (replicatorManager == nil || replication == nil) {
        return nil;
    }

    self = [super init];
    if (self) {
        _replicatorManager = replicatorManager;
        _cdtReplication = [replication copy];
        
        NSError *localError;
        _replConfig =[_cdtReplication dictionaryForReplicatorDocument:&localError];
        if (!_replConfig) {
            if(error) *error = localError;
            return nil;
        }
        
        _state = CDTReplicatorStatePending;
        _started = NO;
        
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark Lifecycle

- (void)start
{
    [self startWithError:nil];
}

- (BOOL)startWithError:(NSError * __autoreleasing*)error;
{
    @synchronized(self) {
        if (self.started) {
            LogTo(CDTReplicatorLog, @"start: CDTRepliplicator can only be started once."
                  @"Current State: %@", [CDTReplicator stringForReplicatorState:self.state]);
        
            if (error) {
                NSDictionary *userInfo =
                @{NSLocalizedDescriptionKey: NSLocalizedString(@"Data sync failed.", nil)};
                *error = [NSError errorWithDomain:CDTReplicatorErrorDomain
                                             code:CDTReplicatorErrorAlreadyStarted
                                         userInfo:userInfo];
            }
        
            return NO;
        }
    
        self.started = YES;
    }
    
    //TDReplicator's can't be restarted, so always instantiate a new one.
    NSError *localError;
    self.tdReplicator = [self.replicatorManager createReplicatorWithProperties:self.replConfig
                                                                         error:&localError];
    
    if (!self.tdReplicator) {
        self.state = CDTReplicatorStateError;

        //report the error to the Log
        Warn(@"CDTReplicator -start: Unable to instantiate TDReplicator."
             @"TD Error: %@ Current State: %@",
             localError, [CDTReplicator stringForReplicatorState:self.state]);

        if (error) {
            //build a CDT error
            NSDictionary *userInfo =
            @{NSLocalizedDescriptionKey: NSLocalizedString(@"Data sync failed.", nil)};
            *error = [NSError errorWithDomain:CDTReplicatorErrorDomain
                                         code:CDTReplicatorErrorTDReplicatorNil
                                     userInfo:userInfo];

        }
        return NO;
    }
    
    //create TD_FilterBlock that wraps the CDTFilterBlock and set the TDPusher.filter property.
    if ([self.cdtReplication isKindOfClass:[CDTPushReplication class]]) {
        
        CDTPushReplication *pushRep = (CDTPushReplication *)self.cdtReplication;
        if (pushRep.filter) {
            TDPusher *tdpusher = (TDPusher *)self.tdReplicator;
            CDTFilterBlock cdtfilter = [pushRep.filter copy];
            
            tdpusher.filter = ^(TD_Revision *rev, NSDictionary* params){
                return cdtfilter([[CDTDocumentRevision alloc] initWithTDRevision:rev], params);
            };
            
        }
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

    return YES;
}

-(void)stop
{

    @synchronized(self) {
        
        //can only stop once. If state == 'stopped', 'stopping', 'complete', or 'error'
        //then -stop has either already been called, or the replicator stopped due to
        //completion or error.
        
        //only the switch block is within the @synchronized in order to prevent the
        //delegate's replicatorDidChangeState method from blocking significantly.
        
        switch (self.state) {
            case CDTReplicatorStatePending:
            case CDTReplicatorStateStarted:
                self.state = CDTReplicatorStateStopped;
                break;
                
            default:
                return;
        }
       
    }
    
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
    
    BOOL progressChanged = [self updateProgress];
    
    BOOL stateChanged = NO;

    switch (self.state) {
        case CDTReplicatorStatePending:
        case CDTReplicatorStateStopping:
            
            if (self.tdReplicator.error) {
                self.state = CDTReplicatorStateError;
            }
            else {
                self.state = CDTReplicatorStateStopped;
            }
            stateChanged = YES;
            
            break;
            
        case CDTReplicatorStateStarted:
            
            if (self.tdReplicator.error) {
                self.state = CDTReplicatorStateError;
            }
            else {
                self.state = CDTReplicatorStateComplete;
            }
            stateChanged = YES;
            
        //do nothing if the state is already 'complete' or 'error'.
        //which should be impossible.
        default:
            Warn(@"CDTReplicator -replicatorStopped was called with unexpected state = %@",
                 [[self class] stringForReplicatorState:self.state]);
            break;
    }
    
    id<CDTReplicatorDelegate> delegate = self.delegate;
    
    if (progressChanged && [delegate respondsToSelector:@selector(replicatorDidChangeProgress:)]) {
        [delegate replicatorDidChangeProgress:self];
    }
    
    if (stateChanged && [delegate respondsToSelector:@selector(replicatorDidChangeState:)]) {
        [delegate replicatorDidChangeState:self];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:self.tdReplicator];
    
}

// Notified that a TDReplicator has started:
- (void) replicatorStarted: (NSNotification*)n {
    TDReplicator* repl = n.object;
    
    LogTo(CDTReplicatorLog, @"replicatorStarted: %@ type: %@ sessionId: %@", n.name,
          [repl class], repl.sessionID);
    
    CDTReplicatorState oldState = self.state;
    self.state = CDTReplicatorStateStarted;
    
    id<CDTReplicatorDelegate> delegate = self.delegate;

    BOOL stateChanged = (oldState != self.state);
    if (stateChanged && [delegate respondsToSelector:@selector(replicatorDidChangeState:)]) {
        [delegate replicatorDidChangeState:self];
    }
}

/*
 * Called when progress has been reported by the TDReplicator.
 */
-(void) replicatorProgressChanged: (NSNotification *)n
{
    BOOL progressChanged = [self updateProgress];
    
    CDTReplicatorState oldState = self.state;
    
    if (self.tdReplicator.running)
        self.state = CDTReplicatorStateStarted;
    else if (self.tdReplicator.error)
        self.state = CDTReplicatorStateError;
    else
        self.state = CDTReplicatorStateComplete;
    
    
    // Lots of possible delegate messages at this point
    id<CDTReplicatorDelegate> delegate = self.delegate;
    
    if (progressChanged && [delegate respondsToSelector:@selector(replicatorDidChangeProgress:)]) {
        [delegate replicatorDidChangeProgress:self];
    }
    
    BOOL stateChanged = (oldState != self.state);
    if (stateChanged && [delegate respondsToSelector:@selector(replicatorDidChangeState:)]) {
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

-(BOOL) updateProgress
{
    BOOL progressChanged = NO;
    if (self.changesProcessed != self.tdReplicator.changesProcessed ||
        self.changesTotal != self.tdReplicator.changesTotal) {
        
        self.changesProcessed = self.tdReplicator.changesProcessed;
        self.changesTotal = self.tdReplicator.changesTotal;
        progressChanged = YES;
    }
    return progressChanged;
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
