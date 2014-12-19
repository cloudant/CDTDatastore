//
//  ReplicatorCoreData.h
//  ReplicationAcceptance
//
//  Created by Jimi Xenidis on 12/19/14.
//
//

#import "CloudantReplicationBase.h"

@interface ReplicatorCoreData : CloudantReplicationBase

@property (nonatomic, strong) NSURL *primaryRemoteDatabaseURL;

@end
