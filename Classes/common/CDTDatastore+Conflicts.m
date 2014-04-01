//
//  CDTDatastore+Conflicts.m
//
//
//  Created by G. Adam Cox on 13/03/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTDatastore+Conflicts.h"
#import "CDTDocumentRevision.h"
#import "TD_Revision.h"
#import "TD_Database+Conflicts.h"
#import "CDTConflictResolver.h"
#import "CDTDocumentBody.h"
#import "TDStatus.h"

@implementation CDTDatastore (Conflicts)


-(NSArray*) conflictsForDocument:(CDTDocumentRevision*)revision
{
    return [self conflictsForDocumentId:revision.docId];
}

-(NSArray*) conflictsForDocumentId:(NSString*)docId
{
    TD_RevisionList* revs = [self.database getAllRevisionsOfDocumentID:docId
                                                           onlyCurrent:YES];
    NSMutableArray *results = [NSMutableArray array];
    for (TD_Revision *td_rev in revs.allRevisions) {
        CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:td_rev];
        [results addObject:ob];
    }
    return results.count > 1 ? results : nil;
}

-(NSArray*) getConflictedDocumentIds
{
    return [self.database getConflictedDocumentIds];
}

-(void) enumerateConflictsUsingBlock:(void (^)(NSString *documentId, NSUInteger idx, BOOL *stop))block
{
    [[self getConflictedDocumentIds] enumerateObjectsUsingBlock:block];
}


@end
