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

@implementation CDTTodo

-(instancetype)initWithDescription:(NSString*)description completed:(BOOL)completed
{
    self = [super init];
    if (self) {
        self.description = description;
        self.completed = completed;
    }
    return self;
}

+(instancetype)fromDict:(NSDictionary*)dict
{
    return [[[self class] alloc] initWithDescription:[dict objectForKey:@"description"]
                                      completed:[[dict objectForKey:@"completed"] boolValue]];
}

-(NSDictionary*)toDict
{
    NSDictionary *dict = @{
                          @"description": self.description,
                          @"completed": @(self.completed),
                          @"type": @"com.cloudant.sync.example.task"
                          };
    return dict;
}

@end
