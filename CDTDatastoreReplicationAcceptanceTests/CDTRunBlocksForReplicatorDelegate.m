//
//  CDTRunBlocksForReplicatorDelegate.m
//  ReplicationAcceptance
//
//  Created by Adam Cox on 1/12/15.
//
//

#import "CDTRunBlocksForReplicatorDelegate.h"

@implementation CDTRunBlocksForReplicatorDelegate


-(void) replicatorDidChangeState:(CDTReplicator *)replicator
{
    if (self.changeStateBlock) {
        self.changeStateBlock(replicator);
    }
}

-(void) replicatorDidChangeProgress:(CDTReplicator*)replicator
{
    if (self.changeProgressBlock) {
        self.changeProgressBlock(replicator);
    }
}

-(void) replicatorDidError:(CDTReplicator *)replicator info:(NSError *)info
{
    if (self.errorBlock) {
        self.errorBlock(replicator, info);
    }
}

@end
