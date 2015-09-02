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

@class CDTDocumentRevision;

/**
 A simple class that maps from a document revision to a Todo task, to
 prevent typos in keys and hold the type information in one place.
 */
@interface CDTTodo : NSObject

@property (nonatomic,strong) NSString *taskDescription;
@property (nonatomic) BOOL completed;

/**
 Uptodate version of the CDTDocumentRevision associated with this task.
 */
@property (nonatomic, strong, readonly) CDTDocumentRevision *rev;

/**
 Create a new task
 */
-(instancetype)initWithDescription:(NSString*)description completed:(BOOL)completed;

/**
 Initialise an existing task from a document revision.
 */
- (instancetype)initWithDocumentRevision:(CDTDocumentRevision *)rev;

@end
