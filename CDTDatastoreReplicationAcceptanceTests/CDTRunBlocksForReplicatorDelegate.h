//
//  CDTRunBlocksForReplicatorDelegate.h
//  ReplicationAcceptance
//
//  Created by Adam Cox on 1/12/15.
//
//

#import <Foundation/Foundation.h>
#import "CDTReplicatorDelegate.h"
#import "CDTReplicator.h"

typedef void (^changeStateBlock)(CDTReplicator* replicator);
typedef void (^changeProgressBlock)(CDTReplicator* replicator);
typedef void (^errorBlock)(CDTReplicator *replicator, NSError *error);

@interface CDTRunBlocksForReplicatorDelegate : NSObject  <CDTReplicatorDelegate>

@property (nonatomic, copy) changeStateBlock changeStateBlock;
@property (nonatomic, copy) changeProgressBlock changeProgressBlock;
@property (nonatomic, copy) errorBlock errorBlock;

@end
