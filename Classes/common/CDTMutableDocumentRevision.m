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

@property (strong,nonatomic,readwrite) NSMutableDictionary * private_attachments;
@property (strong,nonatomic,readwrite) NSMutableDictionary * private_body;

@end

@implementation CDTMutableDocumentRevision

@synthesize docId =_docId;
@synthesize revId = _revId;
@synthesize deleted = _deleted;
NSMutableArray * _attachments =nil;
NSMutableDictionary* _body=nil;



+(CDTMutableDocumentRevision *)revision
{
    
    return [[CDTMutableDocumentRevision alloc ]init];
    
}

-(id)initWithDocumentId:(NSString *)documentId body:(NSMutableDictionary *) body
{
    self = [super init];
    
    if(self){
        //do set up
        _docId = documentId;
        _body = body;
    }
    
    return self;
}

-(void)setBody:(NSDictionary *)body
{
    self.private_body = [body mutableCopy];
}

-(NSMutableDictionary*)body
{
    return self.private_body;
}

-(NSMutableDictionary*)attachments
{
    return self.private_attachments;
}

-(void)setAttachments:(NSMutableDictionary *)attachments
{
    self.private_attachments = [attachments mutableCopy];
}

@end
