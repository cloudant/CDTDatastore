//
//  CloudantReplicationBase.h
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <SenTestingKit/SenTestingKit.h>

@class CDTDatastoreManager;

@interface CloudantReplicationBase : SenTestCase

@property (nonatomic,strong) CDTDatastoreManager *factory;
@property (nonatomic,strong) NSString *factoryPath;

@property (nonatomic, strong) NSURL *remoteRootURL;
@property (nonatomic, strong) NSString *remoteDbPrefix;

@end
