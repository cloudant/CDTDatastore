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

#pragma mark CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart

@implementation CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart

-(void) checkAndDelete:(CDTReplicator* )replicator
{
    if (replicator.state == CDTReplicatorStateStarted && replicator.changesProcessed > 0) {
        [self.dsManager deleteDatastoreNamed:self.databaseToDelete error:nil];
    }
}
-(void) replicatorDidChangeState:(CDTReplicator *)replicator
{
    [self checkAndDelete:replicator];
}

-(void) replicatorDidChangeProgress:(CDTReplicator*)replicator
{
    [self checkAndDelete:replicator];
}

-(void) replicatorDidError:(CDTReplicator *)replicator info:(NSError *)info
{
    self.error = info;
}

@end
