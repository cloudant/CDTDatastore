//
//  CDTDocumentRevision.m
//  CloudantSync
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTDocumentRevision.h"
#import "CDTMutableDocumentRevision.h"
#import "TDJSON.h"
#import "TD_Revision.h"
#import "TD_Body.h"

@interface CDTDocumentRevision ()


@property (nonatomic,strong,readonly) TD_RevisionList *revs;
@property (nonatomic,strong,readonly) NSArray *revsInfo;
@property (nonatomic,strong,readonly) NSArray *conflicts;
@property (nonatomic,strong,readonly) TD_Body *td_body;
@property (nonatomic,strong,readonly) NSDictionary *private_body;
@property (nonatomic,strong,readonly) NSDictionary *private_attachments;

@end

@implementation CDTDocumentRevision

@synthesize docId = _docId;
@synthesize revId = _revId;
@synthesize deleted = _deleted;
@synthesize sequence = _sequence;

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *) revId
              body:(NSDictionary *)body
       attachments:(NSDictionary *) attachments
{
    return [self initWithDocId:docId
                    revisionId:revId
                          body:body
                       deleted:NO
                   attachments:attachments
                      sequence:0];
}

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *)revId
              body:(NSDictionary *)body
           deleted:(BOOL)deleted
       attachments:(NSDictionary *)attachments
          sequence:(SequenceNumber)sequence
{
 
    self = [super init];
    
    if(self){
        
        if(!docId || !revId || !body){
            return nil;
        }
        _docId = docId;
        _revId = revId;
        _deleted = deleted;
        _private_attachments = attachments;
        _sequence = sequence;
        if(!deleted){
            NSMutableDictionary *mutableCopy = [body mutableCopy];
            
            NSPredicate *_prefixPredicate = [NSPredicate predicateWithFormat:@" self BEGINSWITH '_'"];
            
            NSArray * keysToRemove = [[body allKeys]
                                      filteredArrayUsingPredicate: _prefixPredicate];
            
            [mutableCopy removeObjectsForKeys:keysToRemove];
            _private_body = [NSDictionary dictionaryWithDictionary:mutableCopy];
        }
        else
            _private_body = [NSDictionary dictionary];
    }
    return self;
    
    
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(NSData*)documentAsDataError:(NSError * __autoreleasing *)error
{
    NSError *innerError = nil;
    
    NSData *json = [[TDJSON dataWithJSONObject:self.body options:0 error:&innerError] copy];
    
    if (!json) {
        Warn(@"CDTDocumentRevision: couldn't convert to JSON");
        *error = innerError;
        return nil;
    }
    
    return json;
}



-(CDTMutableDocumentRevision*)mutableCopy
{
    CDTMutableDocumentRevision *mutableCopy = [[CDTMutableDocumentRevision alloc] initWithSourceRevisionId:self.revId];
    mutableCopy.docId = self.docId;
    mutableCopy.attachments = self.attachments;
    mutableCopy.body = self.private_body;
    
    return mutableCopy;
}

-(NSDictionary*)body
{
    return self.private_body;
}

-(NSDictionary*)attachments
{
    return self.private_attachments;
}

@end
