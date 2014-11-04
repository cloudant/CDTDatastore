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

@interface CDTTestReplicatorDelegateDeleteLocalDatastoreAfterStart : NSObject <CDTReplicatorDelegate>
@property (nonatomic, strong) CDTDatastoreManager *dsManager;
@property (nonatomic, strong) NSString* databaseToDelete;
@property (nonatomic, strong) NSError *error;
@end

@interface CDTTestReplicatorMultiThreaded :  NSObject <CDTReplicatorDelegate>
@property (nonatomic, weak) CDTReplicator* firstReplicator;
@property (nonatomic, weak) CDTReplicator* secondReplicator;
@property (nonatomic) BOOL multiThreaded;
@end