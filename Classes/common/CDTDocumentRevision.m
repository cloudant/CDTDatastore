//
//  CDTDocumentRevision.m
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CDTDocumentRevision.h"

#import "TDJSON.h"
#import "TD_Revision.h"
#import "TD_Body.h"

@interface CDTDocumentRevision ()

@property (nonatomic,strong,readonly) TD_Revision *td_rev;

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


-(NSData*)documentAsData
{
    // First remove extra _properties added by TD_Database.m#extraPropertiesForRevision:options:
    // and put them into attributes
    NSDictionary *processed_document = [self documentAsDictionary];
    NSData *json = [[TDJSON dataWithJSONObject:processed_document options:0 error:NULL] copy];
    if (!json) {
        Warn(@"CDTDocumentRevision: couldn't convert to JSON");
    }
    return json;


//    if (!_json && !_error) {
//        _json = [[TDJSON dataWithJSONObject: _object options: 0 error: NULL] copy];
//        if (!_json) {
//            Warn(@"TD_Body: couldn't convert to JSON");
//            _error = YES;
//        }
//    }
//    return _json;
}

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

    _localSeq = touch_properties[@"_local_seq"];
    [touch_properties removeObjectForKey:@"_local_seq"];

    _attachments = touch_properties[@"_attachments"];
    [touch_properties removeObjectForKey:@"_attachments"];

    _revsInfo = touch_properties[@"_revs_info"];
    [touch_properties removeObjectForKey:@"_revs_info"];

    _conflicts = touch_properties[@"_conflicts"];
    [touch_properties removeObjectForKey:@"_conflicts"];

    // return a non-mutable dictionary
    return [NSDictionary dictionaryWithDictionary:touch_properties];
}

@end
