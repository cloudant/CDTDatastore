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
#import "TD_Database.h"

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


+(CDTDocumentRevision*)createRevisionFromJson:(NSData*)json error:(NSError * __autoreleasing *) error
{
    NSDictionary* jsonDict = [NSJSONSerialization JSONObjectWithData:json options:0 error:error];
    
    //these values are defined in the couchDB get/${db}/ ${docid} api reference
    
    NSArray* allowed_prefixedValues = @[@"_id",
                                        @"_rev",
                                        @"_deleted",
                                        @"_attachments",
                                        @"_conflicts",
                                        @"_deleted_conflicts",
                                        @"_local_seq",
                                        @"_revs_info",
                                        @"_revisions"
                                        ];
    if(*error)
        return nil;
    
    NSPredicate *_prefixPredicate = [NSPredicate predicateWithFormat:@" self BEGINSWITH '_' \
                                                                        && NOT (self IN %@)",
                                                                     allowed_prefixedValues
                                                                    ];
    
    NSArray * invalidKeys = [[jsonDict allKeys] filteredArrayUsingPredicate:_prefixPredicate];
    
    if([invalidKeys count] != 0){
        *error = TDStatusToNSError(kTDStatusBadJSON,nil);
        return nil;
    }
    
    NSString * docId = [jsonDict objectForKey:@"_id"];
    NSString * revId = [jsonDict objectForKey:@"_rev"];
    NSNumber * deleted = [jsonDict objectForKey:@"_deleted"];
    
    if(!deleted)
        deleted = [NSNumber numberWithBool:NO];
    
    
    NSMutableDictionary * body = [jsonDict mutableCopy];
    [body removeObjectsForKeys:allowed_prefixedValues];
    
    return [[CDTDocumentRevision alloc]initWithDocId:docId
                                          revisionId:revId
                                                body:body
                                             deleted:[deleted boolValue]];
    
}

#pragma mark convenience constructors
-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *) revId
              body:(NSDictionary *)body
           deleted:(BOOL) deleted
{
    
    return [self initWithDocId:docId
                    revisionId:revId
                          body:body
                       deleted:deleted
                   attachments:[NSDictionary dictionary]];
}

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *)revId
              body:(NSDictionary *)body
           deleted:(BOOL)deleted
          sequence:(SequenceNumber)sequence
{
    return [self initWithDocId:docId
                    revisionId:revId
                          body:body
                       deleted:deleted
                   attachments:[NSDictionary dictionary]
                      sequence:sequence];
}

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *) revId
              body:(NSDictionary *)body
           deleted:(BOOL) deleted
       attachments:(NSDictionary *) attachments
{
    return [self initWithDocId:docId
                    revisionId:revId
                          body:body
                       deleted:deleted
                   attachments:attachments
                      sequence:0];
}

#pragma mark Actual constructor

-(id)initWithDocId:(NSString *)docId
        revisionId:(NSString *)revId
              body:(NSDictionary *)body
           deleted:(BOOL)deleted
       attachments:(NSDictionary *)attachments
          sequence:(SequenceNumber)sequence
{
 
    self = [super init];
    
    if(self){
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
    
    NSDictionary *processed_document = [self documentAsDictionary];
    NSData *json = [[TDJSON dataWithJSONObject:processed_document options:0 error:&innerError] copy];
    
    if (!json) {
        Warn(@"CDTDocumentRevision: couldn't convert to JSON");
        *error = innerError;
        return nil;
    }
    
    return json;
}

-(NSDictionary*)documentAsDictionary
{
    // First remove extra _properties added by TD_Database.m#extraPropertiesForRevision:options:
    // and put them into attributes
    NSMutableDictionary *touch_properties = [self.body mutableCopy];

    // _id, _rev, _deleted are already stored outside the dictionary
    [touch_properties removeObjectForKey:@"_id"];
    [touch_properties removeObjectForKey:@"_rev"];
    [touch_properties removeObjectForKey:@"_deleted"];

    _revs = touch_properties[@"_revs"];
    [touch_properties removeObjectForKey:@"_revs"];

    _revsInfo = touch_properties[@"_revs_info"];
    [touch_properties removeObjectForKey:@"_revs_info"];

    _conflicts = touch_properties[@"_conflicts"];
    [touch_properties removeObjectForKey:@"_conflicts"];
    
    // Unused properties
    [touch_properties removeObjectForKey:@"_local_seq"];
    [touch_properties removeObjectForKey:@"_attachments"];

    // return a non-mutable dictionary
    return [NSDictionary dictionaryWithDictionary:touch_properties];
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
