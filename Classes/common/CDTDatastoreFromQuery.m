//
//  CDTDatastoreFromQuery.m
//  
//
//  Created by tomblench on 15/10/2014.
//
//

#import <Foundation/Foundation.h>
#import "CDTDatastoreFromQuery.h"
#import "CDTPullReplication.h"
#import "CDTReplicatorFactory.h"
#import "CDTDatastoreManager.h"
#import "CDTReplicatorDelegate.h"


@interface CDTDatastoreFromQuery ()


@end



@implementation CDTDatastoreFromQueryPushDelegate
- (void)replicatorDidComplete:(CDTReplicator*)replicator
{
    NSLog(@"done, would now purge");
}
@end

@implementation CDTDatastoreFromQuery

-(id)initWithQuery:(CDTDatastoreQuery*)query
  datastoreManager:(CDTDatastoreManager*)manager
            remote:(NSURL*)remote
{
    if (self = [super init]) {
        _datastoreManager = manager;
        _query = query;
        _docIds = [self queryToDocIds:_query];
        _remote = remote;
        _pushDelegate = [[CDTDatastoreFromQueryPushDelegate alloc] init];
        // TODO datastore name to be derived from query
        _datastore = [manager datastoreNamed:[self queryToDatastoreName:query] error:nil];
    }
    return self;
}

-(id)initWithQuery:(CDTDatastoreQuery*)query
    localDirectory:(NSString*)local
            remote:(NSURL*)remote
{
    if (self = [super init]) {
        NSError *err;
        _datastoreManager = [[CDTDatastoreManager alloc] initWithDirectory:local error:&err];
        // TODO why is _datastoreManager.manager.replicatorManager.replicatorsBySessionID nil?
        _query = query;
        _docIds = [self queryToDocIds:_query];
        _remote = remote;
        _pushDelegate = [[CDTDatastoreFromQueryPushDelegate alloc] init];
        // TODO datastore name to be derived from query
        _datastore = [_datastoreManager datastoreNamed:[self queryToDatastoreName:query] error:nil];
        _factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.datastoreManager];
        [_factory start];

    }
    return self;
}

-(NSArray*)queryToDocIds:(CDTDatastoreQuery*)query
{
    // dummy implementation
    return @[@"doc-1",@"doc-2",@"doc-3"];
}

-(NSString*)queryToDatastoreName:(CDTDatastoreQuery*)query
{
    // TODO
    return @"test";
}

-(CDTReplicator*)pull
{
    // standard pull by doc id
    // could purge before / after?
    
    
    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:self.remote
                                                                  target:self.datastore];
    pull.clientFilterDocIds = self.docIds;
    
    NSError *error;
    CDTReplicator *replicator =  [_factory oneWay:pull error:&error];
    return replicator;
 }

-(CDTReplicator*)push
{
    // has the id list changed?
    // push everything
    // then purge local docs not in id list
    // TODO - how to manage lifecycle, need to add a block to run on completion of push using notifications

    CDTPullReplication *push = [CDTPullReplication replicationWithSource:self.remote
                                                                  target:self.datastore];
    NSError *error;
    CDTReplicator *replicator =  [_factory oneWay:push error:&error];
    replicator.delegate = _pushDelegate;
    
    return replicator;
}

@end

