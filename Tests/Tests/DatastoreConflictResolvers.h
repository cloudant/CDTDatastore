//
//  DatastoreConflictResolvers.h
//  Tests
//
//  Created by Adam Cox on 5/1/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import "CDTConflictResolver.h"

/**
 This file and DatastoreConflictResolvers.m define a set of conflict resolvers
 used for testing purposes.
 */


/** 
 this class chooses the biggest revision generation
 */
@interface CDTTestBiggestRevResolver  : NSObject<CDTConflictResolver>
-(NSDictionary *) resolvedDocumentAsDictionary;  //made public for tests
@end


/** 
 This class deletes all docs with a conflict
 */
@interface CDTTestDeleteConflictedDocResolver  : NSObject<CDTConflictResolver>
@end


/**
 ParticluarDocBiggestResolver subclasses MyBiggestRevResolver.
 
 This let's you define a set of document IDs that will be resolved.
 Documents with _id not in this set will not resolve because
 -resolve:conflict: will return nil.
 */
@interface CDTTestParticularDocBiggestResolver : CDTTestBiggestRevResolver
@property (nonatomic, strong) NSSet* docIdsToResolve;
-(instancetype) initWithDocsToResolve:(NSSet *)docs;
@end


/** 
 This class does not resolve any document by implementing -resolve:conflict: to
 always return nil.
*/
@interface CDTTestDoesNoResolutionResolver  : NSObject<CDTConflictResolver>
@end
