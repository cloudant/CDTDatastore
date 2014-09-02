//
//  CDTDatastoreFromQuery.h
//  
//
//  Created by tomblench on 15/10/2014.
//
//

#ifndef _CDTDatastoreFromQuery_h
#define _CDTDatastoreFromQuery_h

#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"
#import "CDTReplicator.h"
#import "CDTReplicatorFactory.h"

@class CDTDatastoreFromQuery;

@interface CDTCustomDelegateReplicator: CDTReplicator
- (void) setDelegate:(NSObject<CDTReplicatorDelegate>*)delegate;

@property (readonly,strong) NSObject<CDTReplicatorDelegate> *userDelegate;
@property (readonly,strong) NSObject<CDTReplicatorDelegate> *privateDelegate;

@end

// TODO - this is just for prototyping, represent query as opaque object
@interface CDTDatastoreQuery : NSObject

@property (strong) NSDictionary *queryDictionary;

@end

@interface CDTDatastoreFromQueryPushDelegate : NSObject<CDTReplicatorDelegate>

- (id)initWithDatastore:(CDTDatastoreFromQuery*)datastore;
- (void)replicatorDidComplete:(CDTReplicator*)replicator;

@property (readonly,strong) CDTDatastoreFromQuery *datastore;

@end

@interface CDTDatastoreFromQuery : NSObject

@property (readonly,strong) CDTDatastoreQuery *query;

// TODO - for now this is the current set of filtered doc IDs
@property NSArray *docIds;


@property (readonly,strong) CDTDatastoreManager *datastoreManager;

// façade lots of operations into CDTDatastore
@property (readonly,strong) CDTDatastore *datastore;

// URL of remote database
@property (readonly,strong) NSURL *remote;

@property (readonly,strong) CDTDatastoreFromQueryPushDelegate *pushDelegate;

@property (readonly,strong) CDTReplicatorFactory *factory;

// TODO - private?
-(NSString*)queryToDatastoreName:(CDTDatastoreQuery*)query;

-(id)initWithQuery:(CDTDatastoreQuery*)query
    localDirectory:(NSString*)local
            remote:(NSURL*)remote;

-(id)initWithQuery:(CDTDatastoreQuery*)query
  datastoreManager:(CDTDatastoreManager*)manager
            remote:(NSURL*)remote;

// TODO these might take arguments eg error         
-(CDTReplicator*)pull;
-(CDTReplicator*)push;


@end


#endif
