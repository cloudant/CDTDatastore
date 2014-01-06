//
//  CDTReplicator.m
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//
//

#import "CDTReplicator.h"

#import "CDTDatastore.h"
#import "CDTDocumentRevision.h"

@interface CDTReplicator ()

@property (nonatomic,strong) CDTDatastore *replicatorDb;
@property (nonatomic,strong) CDTDocumentBody *body;
@property (nonatomic,strong) NSString *replicationDocumentId;

@end

@implementation CDTReplicator

-(id)initWithReplicatorDatastore:(CDTDatastore*)replicatorDb
         replicationDocumentBody:(CDTDocumentBody*)body;
{
    self = [super init];
    if (self) {
        _replicatorDb = replicatorDb;
        _body = body;
    }
    return self;
}

-(void)start
{
    NSError *error;

    // starts the replication immediately
    CDTDocumentRevision *rev = [self.replicatorDb createDocumentWithBody:self.body
                                                                   error:&error];

    self.replicationDocumentId = rev.docId;
}

-(void)stop
{
    if (self.replicationDocumentId == nil) {
        return;   // not started yet
    }

    NSError *error;

    CDTDocumentRevision *current = [self.replicatorDb getDocumentWithId:self.replicationDocumentId
                                                                  error:&error];

    [self.replicatorDb deleteDocumentWithId:current.docId
                                        rev:current.revId
                                      error:&error];
}

-(CDTReplicatorState)state
{
    if (self.replicationDocumentId == nil) {
        return CDTReplicatorStatePending;   // not started yet
    }

    NSError *error;

    CDTDocumentRevision *current = [self.replicatorDb getDocumentWithId:self.replicationDocumentId
                                                                  error:&error];

    NSString *state = [[current documentAsDictionary] objectForKey:@"_replication_state"];

    if ([state isEqualToString:@"triggered"]) {
        return CDTReplicatorStateStarted;
    } else if ([state isEqualToString:@"error"]) {
        return CDTReplicatorStateError;
    } else if ([state isEqualToString:@"completed"]) {
        return CDTReplicatorStateComplete;
    } else {
        // probably nil, so pending as the replicator's not yet picked it up
        return CDTReplicatorStatePending;
    }
}

@end
