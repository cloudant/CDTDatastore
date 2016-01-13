//
//  CDTTodo.m
//  Project
//
//  Created by Michael Rhodes on 19/03/2014.
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

#import "CDTTodo.h"

#import <CDTDatastore/CloudantSync.h>

@implementation CDTTodo

-(instancetype)initWithDescription:(NSString*)description completed:(BOOL)completed
{
    self = [super init];
    if (self) {
        _rev = [CDTDocumentRevision revision];
        _rev.body = [@{
            @"description" : description,
            @"completed" : @(completed),
            @"type" : @"com.cloudant.sync.example.task"
        } mutableCopy];
    }
    return self;
}

- (instancetype)initWithDocumentRevision:(CDTDocumentRevision *)rev
{
    self = [super init];
    if (self) {
        _rev = rev;
    }
    return self;
}

- (NSString *)taskDescription { return self.rev.body[@"description"]; }

- (void)setTaskDescription:(NSString *)taskDescription
{
    self.rev.body[@"description"] = taskDescription;
}

- (BOOL)completed { return [self.rev.body[@"completed"] boolValue]; }

- (void)setCompleted:(BOOL)completed { self.rev.body[@"completed"] = @(completed); }

@end
