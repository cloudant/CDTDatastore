//
//  ChangeTrackerDelegate.m
//  ReplicationAcceptance
//
//  Created by Adam Cox on 1/8/15.
//
//

#import "ChangeTrackerDelegate.h"
#import "TDURLConnectionChangeTracker.h"

@implementation ChangeTrackerDelegate

- (void)changeTrackerReceivedChanges:(NSArray*)changes
{
    if (self.changesBlock) {
        self.changesBlock(changes);
    }
}

- (void)changeTrackerStopped:(TDChangeTracker*)tracker
{
    if (self.stoppedBlock) {
        self.stoppedBlock(tracker);
    }
}

-(void)changeTrackerReceivedChange:(NSDictionary*)change
{
    if (self.changeBlock) {
        self.changeBlock(change);
    }
}

@end
