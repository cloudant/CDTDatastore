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

#import "TDJSON.h"
#import "TD_Revision.h"
#import "TD_Body.h"

@interface CDTDocumentRevision ()

@property (nonatomic,strong,readonly) NSDictionary *attachments;
@property (nonatomic,strong,readonly) TD_RevisionList *revs;
@property (nonatomic,strong,readonly) NSArray *revsInfo;
@property (nonatomic,strong,readonly) NSArray *conflicts;

@end

@implementation CDTDocumentRevision

-(id)initWithTDRevision:(TD_Revision*)rev
{
    self = [super init];
    if (self) {
        _td_rev = rev;
    }
    return self;
}

-(TD_Revision*)TD_RevisionValue
{
    return self.td_rev;
}

-(NSString*)docId
{
    return self.td_rev.docID;
}

-(NSString*)revId
{
    return self.td_rev.revID;
}

-(BOOL)deleted
{
    return self.td_rev.deleted;
}

-(SequenceNumber)sequence 
{
    return self.td_rev.sequence;
}


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
    
    return json;}

-(NSDictionary*)documentAsDictionary
{
    // First remove extra _properties added by TD_Database.m#extraPropertiesForRevision:options:
    // and put them into attributes
    NSMutableDictionary *touch_properties = [self.td_rev.body.properties mutableCopy];

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

@end
