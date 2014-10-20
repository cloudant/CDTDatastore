//
//  CloudantReplicationBase.h
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantReplicationBase.h"

@class CDTDatastore;
@class CDTReplicatorFactory;
@class CDTReplicator;
@class CDTDatastoreFromQuery;

@interface ReplicationAcceptance : CloudantReplicationBase

@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) CDTReplicatorFactory *replicatorFactory;

@property (nonatomic, strong) NSURL *primaryRemoteDatabaseURL;

@end