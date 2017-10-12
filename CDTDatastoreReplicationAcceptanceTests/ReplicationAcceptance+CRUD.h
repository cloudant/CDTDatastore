//
//  CloudantReplicationBase+CRUD.h
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 05/02/2014.
//
//

#import "ReplicationAcceptance.h"

@class CDTDocumentRevision;

@interface ReplicationAcceptance (CRUD)

-(void) createLocalDocs:(NSInteger)count;
-(void) createLocalDocs:(NSInteger)count suffixFrom:(NSInteger)start;
-(void) createLocalDocs:(NSInteger)count
             suffixFrom:(NSInteger)start
                reverse:(BOOL)reverse
                updates:(BOOL)updates;

-(void) createLocalDocWithId:(NSString*)docId revs:(NSInteger)n_revs;

-(CDTDocumentRevision*) addRevsToDocumentRevision:(CDTDocumentRevision*)rev count:(NSInteger)n_revs;

-(void) createRemoteDocs:(NSInteger)count;
-(void) createRemoteDocs:(NSInteger)count suffixFrom:(NSInteger)start;
-(void) createRemoteDocWithId:(NSString*)docId revs:(NSInteger)n_revs;
-(NSString*) createRemoteDocWithId:(NSString *)ddocid body:(NSDictionary*)ddocbody;
-(void) createRemoteDocs:(NSInteger)count at:(NSURL*)url revs:(NSInteger)n_revs;

-(NSString*) deleteRemoteDocWithId:(NSString *)docId;

-(NSDictionary*) remoteDbMetadata;

-(void) assertRemoteDatabaseHasDocCount:(NSInteger)count deletedDocs:(NSInteger)deleted;

@end
