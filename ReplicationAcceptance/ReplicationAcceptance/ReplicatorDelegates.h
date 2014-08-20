//
//  ReplicatorDelegates.h
//  ReplicationAcceptance
//
//  Created by Adam Cox on 7/28/14.
//
//

#import <Foundation/Foundation.h>
#import "CDTReplicatorDelegate.h"
#import "CDTReplicator.h"

@class CDTDatastoreManager;

@interface CDTTestReplicatorDelegateStopAfterStart :  NSObject <CDTReplicatorDelegate>
@end
