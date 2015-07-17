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

@property (strong, nonatomic, readwrite) NSMutableDictionary *private_attachments;
@property (strong, nonatomic, readwrite) NSMutableDictionary *private_body;

@end

@implementation CDTMutableDocumentRevision

@synthesize docId = _docId;
@synthesize revId = _revId;
@synthesize deleted = _deleted;

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
        _private_body = body ? body : [NSMutableDictionary dictionary];
        _private_attachments = attachments ? attachments : [NSMutableDictionary dictionary];
        _sourceRevId = sourceRevId;
    }
    
    return self;
}

- (void)setBody:(NSDictionary *)body { self.private_body = [body mutableCopy]; }

- (NSMutableDictionary *)body { return self.private_body; }

- (NSMutableDictionary *)attachments { return self.private_attachments; }

- (void)setAttachments:(NSMutableDictionary *)attachments
{
    self.private_attachments = [attachments mutableCopy];
}

-(CDTMutableDocumentRevision*) mutableCopy{
    CDTMutableDocumentRevision * copy = [super mutableCopy];
    copy.sourceRevId = self.sourceRevId;
    return copy;
}

@end
