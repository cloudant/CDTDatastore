//
//  CDTMutableDocumentRevision.m
//  
//
//  Created by Rhys Short on 22/07/2014.
//
//

#import "CDTMutableDocumentRevision.h"
#import "TD_Body.h"

@implementation CDTMutableDocumentRevision


+(CDTMutableDocumentRevision *)revision
{
    
    return [[CDTMutableDocumentRevision alloc ]init];
    
}

-(id)init{
    self = [super init];
    
    if(self){
        //do some set up here
    }
    return self;
}

-(id)initWithDocumentId:(NSString *)documentId andBody:(NSMutableDictionary *) body
{
    self = [super init];
    
    if(self){
        //do set up
        _docId = documentId;
        _body = body;
    }
    
    return self;
}

-(void)setBody:(NSMutableDictionary *)body
{
    _body = body;
}

-(void)setDocId:(NSString *)docId
{
    _docId = docId;
}

-(TD_Revision*)td_rev
{
    if(_td_rev){
        _td_rev.body = [[TD_Body alloc]initWithProperties:_body];
    } else {
        _td_rev = [[TD_Revision alloc]initWithProperties:_body];
    }
    
    return super.td_rev;
}

-(NSMutableArray*)attachments
{
    return _attachments;
}

-(void)setAttachments:(NSMutableArray *)attachments
{
    _attachments = attachments;
}

@end
