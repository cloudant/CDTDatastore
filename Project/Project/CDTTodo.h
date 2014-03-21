//
//  CDTTodo.h
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

#import <Foundation/Foundation.h>

/**
 A simple class that maps from a JSON document to a Todo task, to
 prevent typos in keys and hold the type information in one place.
 */
@interface CDTTodo : NSObject

@property (nonatomic,strong) NSString *description;
@property (nonatomic) BOOL completed;

-(instancetype)initWithDescription:(NSString*)description completed:(BOOL)completed;

+(instancetype)fromDict:(NSDictionary*)dict;
-(NSDictionary*)toDict;

@end
