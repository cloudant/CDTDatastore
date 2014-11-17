//
//  CSDatastoreBody.m
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTDocumentBody.h"

#import "TD_Body.h"
#import "TD_Revision.h"
#import "TDJSON.h"

@implementation CDTDocumentBody

- (id)init
{
    self = [super init];
    if (self) {
        _td_body = [[TD_Body alloc] initWithProperties:@{}];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if (self) {
        if (![TDJSON isValidJSONObject:dict]) return nil;

        _td_body = [[TD_Body alloc] initWithProperties:dict];
    }
    return self;
}

- (id)initWithTDRevision:(TD_Revision *)rev
{
    self = [super init];
    if (self) {
        _td_body = [rev body];
    }
    return self;
}

- (TD_Revision *)TD_RevisionValue { return [[TD_Revision alloc] initWithBody:self.td_body]; }

@end
