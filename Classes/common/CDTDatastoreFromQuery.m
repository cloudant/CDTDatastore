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
#import "CDTDocumentRevision.h"
#import "TD_Database.h"
#import "TD_Database+Insertion.h"
#import "TDCanonicalJSON.h"

@implementation CDTDatastoreQuery : NSObject


@end

@implementation CDTDatastoreFromQueryPushDelegate

- (id)initWithDatastore:(CDTDatastoreFromQuery*)datastore
{
    if (self = [super init])
    {
        _datastore = datastore;
    }
    return self;
}

// TODO call all of the user delegates
- (void)replicatorDidComplete:(CDTDatastoreFromQuery*)replicator
{
    NSLog(@"done, now purging");
    NSMutableDictionary *revsToPurge = [NSMutableDictionary dictionary];
    NSDictionary *result;
    // purge every revision of every docid not in the filter list
    // TODO whatever the optimisation is to only get the doc ids
    for (CDTDocumentRevision *rev in [[_datastore datastore] getAllDocuments]) {
        if (![[_datastore docIds] containsObject:[rev docId]]) {
            NSMutableArray *revIds = [NSMutableArray array];
            for (CDTDocumentRevision *revObj in [[_datastore datastore] getRevisionHistory:rev]) {
                [revIds addObject:[revObj revId]];
            }
            [revsToPurge setObject:revIds forKey:[rev docId]];
        }
    }
    [[[_datastore datastore] database] purgeRevisions:revsToPurge result:&result];
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
        // TODO datastore name to be derived from query
        _datastore = [manager datastoreNamed:[self queryToDatastoreName:query] error:nil];
        _factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.datastoreManager];
        [_factory start];
        _pushDelegate = [[CDTDatastoreFromQueryPushDelegate alloc] initWithDatastore:self];
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
        // TODO datastore name to be derived from query
        _datastore = [_datastoreManager datastoreNamed:[self queryToDatastoreName:query] error:nil];
        _pushDelegate = [[CDTDatastoreFromQueryPushDelegate alloc] initWithDatastore:self];
        _factory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.datastoreManager];
        [_factory start];

    }
    return self;
}

-(NSArray*)queryToDocIds:(CDTDatastoreQuery*)query
{
    // dummy implementation
    // TODO
    return @[@"doc-1",@"doc-2",@"doc-3"];
}

-(NSString*)queryToDatastoreName:(CDTDatastoreQuery*)query
{
    NSLog(@"%@",[TDCanonicalJSON canonicalString: query.queryDictionary]);
    return TDHexSHA1Digest([TDCanonicalJSON canonicalData: query.queryDictionary]);
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

