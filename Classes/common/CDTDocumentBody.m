//
//  CSDatastoreBody.m
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CDTDocumentBody.h"

#import "TD_Body.h"
#import "TD_Revision.h"

@implementation CDTDocumentBody

-(id)init
{
    self = [super init];
    if (self) {
        _td_body = [[TD_Body alloc] initWithProperties:@{}];
    }
    return self;
}

-(id)initWithDictionary:(NSDictionary*)dict
{
    self = [super init];
    if (self) {
        _td_body = [[TD_Body alloc] initWithProperties:dict];
    }
    return self;
}

-(id)initWithTDRevision:(TD_Revision*)rev
{
    self = [super init];
    if (self) {
        _td_body = [rev body];
    }
    return self;
}

-(TD_Revision*)TD_RevisionValue
{
    return [[TD_Revision alloc] initWithBody:self.td_body];
}

@end
