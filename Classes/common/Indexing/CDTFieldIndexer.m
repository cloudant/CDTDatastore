//
//  CDTFieldIndexer.m
//
//
//  Created by Thomas Blench on 06/02/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTFieldIndexer.h"

#import "CDTDocumentRevision.h"

#import "TD_Revision.h"
#import "TD_Body.h"

@implementation CDTFieldIndexer

- (id)initWithFieldName:(NSString *)fieldName type:(CDTIndexType)type
{
    self = [super init];
    if (self) {
        _fieldName = fieldName;
        _type = type;
    }
    return self;
}

- (NSArray *)valuesForRevision:(CDTDocumentRevision *)revision indexName:(NSString *)indexName
{
    NSObject *value = [[revision body] valueForKey:_fieldName];

    // only index strings, numbers, or arrays
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return @[ value ];
    } else if ([value isKindOfClass:[NSArray class]]) {
        return (NSArray *)value;
    }

    return nil;
}

@end
