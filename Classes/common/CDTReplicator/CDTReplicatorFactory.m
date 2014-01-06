//
//  CDTReplicatorFactory.m
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//
//

#import "CDTReplicatorFactory.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTReplicator.h"
#import "CDTDocumentRevision.h"
#import "CDTDocumentBody.h"

#import "TDReplicatorManager.h"

@interface CDTReplicatorFactory ()

@property (nonatomic,strong) CDTDatastoreManager *manager;

- (CDTReplicator*)setUpReplicatorWithBody:(CDTDocumentBody*)body;

@end

@implementation CDTReplicatorFactory

- (CDTReplicator*)onewaySourceDatastore:(CDTDatastore*)source
                              targetURI:(NSURL*)target {
    NSError *error;

    NSDictionary *replicationDoc = @{
        @"source": source.name,
        @"target": [target absoluteString]
        };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:replicationDoc];

    CDTDatastoreManager *m = self.manager;
    CDTDatastore *datastore = [m datastoreNamed:kTDReplicatorDatabaseName error:&error];

    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:datastore
                                                           replicationDocumentBody:body];

    return replicator;
}

- (CDTReplicator*)onewaySourceURI:(NSURL*)source
                  targetDatastore:(CDTDatastore*)target {
    NSDictionary *replicationDoc = @{
                                     @"source": [source absoluteString],
                                     @"target": target.name
                                     };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:replicationDoc];
    
    return [self setUpReplicatorWithBody:body];
}

@end
