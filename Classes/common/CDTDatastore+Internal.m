//
//  CDTDatastore+Internal.m
//
//  Created by G. Adam Cox on 27/03/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.


#import "CDTDatastore+Internal.h"
#import "TD_Database.h"
#import "CDTDocumentRevision.h"

@implementation CDTDatastore (Internal)

/*
 * Only to be used within a queued database transaction. You MUST also
 * ensure that the database exists and is open before you call this method
 * (TD_Database -open:).
 */
-(NSArray*) activeRevisionsForDocumentId:(NSString*)docId database:(FMDatabase *)db
{
    
    TD_RevisionList* revs = [self.database getAllRevisionsOfDocumentID:docId
                                                           onlyCurrent:YES
                                                        excludeDeleted:YES
                                                              database:db];
    
    NSMutableArray *results = [NSMutableArray array];
    
    for (TD_Revision *tdRev in revs) {
        [self.database loadRevisionBody:tdRev options:0 database:db];
        
        CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:tdRev];
        [results addObject:ob];
    }
    
    return results;
}


@end
