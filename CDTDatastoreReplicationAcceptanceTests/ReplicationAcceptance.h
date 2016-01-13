//
//  CloudantReplicationBase.h
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <XCTest/XCTest.h>

#import "CloudantReplicationBase.h"
#import "ReplicatorURLProtocol.h"

@class CDTDatastore;
@class CDTReplicatorFactory;


@interface ReplicationAcceptance : CloudantReplicationBase

@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) CDTReplicatorFactory *replicatorFactory;

@property (nonatomic, strong) NSURL *primaryRemoteDatabaseURL;

@end
