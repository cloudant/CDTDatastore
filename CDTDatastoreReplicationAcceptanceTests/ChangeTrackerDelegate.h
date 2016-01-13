//
//  ChangeTrackerDelegate.h
//  ReplicationAcceptance
//
//  Created by Adam Cox on 1/8/15.
//
//

#import <Foundation/Foundation.h>
#import "TDChangeTracker.h"

typedef void (^changeTrackerReceivedChangesBlock)(NSArray *changes);
typedef void (^changeTrackerReceivedChangeBlock)(NSDictionary *change);
typedef void (^changeTrackerStoppedBlock)(TDChangeTracker *tracker);


@interface ChangeTrackerDelegate : NSObject <TDChangeTrackerClient>

@property (nonatomic, copy) changeTrackerReceivedChangesBlock changesBlock;
@property (nonatomic, copy) changeTrackerReceivedChangeBlock changeBlock;
@property (nonatomic, copy) changeTrackerStoppedBlock stoppedBlock;

@end
