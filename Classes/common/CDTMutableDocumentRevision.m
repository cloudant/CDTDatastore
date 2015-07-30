//
//  CDTMutableDocumentRevision.m
//
//
//  Created by Rhys Short on 22/07/2014.
//
//

#import "CDTMutableDocumentRevision.h"
#import "TD_Body.h"

@interface CDTMutableDocumentRevision ()

@end

@implementation CDTMutableDocumentRevision

@synthesize docId = _docId;
@synthesize revId = _revId;
@synthesize deleted = _deleted;
@synthesize body = _body;
@synthesize attachments = _attachments;

+ (CDTMutableDocumentRevision *)revision { return [[CDTMutableDocumentRevision alloc] init]; }


-(instancetype) init {
    return [self initWithDocumentId:nil body:nil attachments:nil sourceRevisionId:nil];
}

- (instancetype)initWithDocumentId:(NSString *)documentId body:(NSMutableDictionary *)body
{
    return [self initWithDocumentId:documentId body:body attachments:nil sourceRevisionId:nil];
}

- (instancetype)initWithSourceRevisionId:(NSString *)sourceRevId
{
    return [self initWithDocumentId:nil body:nil attachments:nil sourceRevisionId:sourceRevId];
}

- (instancetype)initWithDocumentId:(NSString*) documentId
                              body:(NSMutableDictionary *)body
                       attachments: (NSMutableDictionary *)attachments
                  sourceRevisionId:(NSString*)sourceRevId {
    
    //deliberately call init rather than initWithDocId:revisionId:body:attachments:
    // we need the revision id to be nil for the APIs on CDTDatastore to work.
    self = [super init];
    
    if (self){
        _docId = documentId;
        _body = body ? body : [NSMutableDictionary dictionary];
        _attachments = attachments ? attachments : [NSMutableDictionary dictionary];
        _sourceRevId = sourceRevId;
    }
    
    return self;
}

-(CDTMutableDocumentRevision*) mutableCopy{
    CDTMutableDocumentRevision * copy = [super mutableCopy];
    copy.sourceRevId = self.sourceRevId;
    return copy;
}

@end
