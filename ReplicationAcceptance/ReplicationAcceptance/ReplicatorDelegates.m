//
//  ReplicatorDelegates.m
//  ReplicationAcceptance
//
//  Created by Adam Cox on 7/28/14.
//
//

#import "ReplicatorDelegates.h"
#import "CloudantSync.h"
#import "Logging.h"

#pragma mark CDTTestReplicatorDelegateStopAfterStart

@implementation CDTTestReplicatorDelegateStopAfterStart

-(void) replicatorDidChangeState:(CDTReplicator *)replicator
{
    if (replicator.state == CDTReplicatorStateStarted) {
        [replicator stop];
    }
}

@end;

