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
#import "CDTDatastore+Internal.h"
#import "CDTDocumentRevision.h"
#import "TD_Revision.h"
#import "TD_Database+Conflicts.h"
#import "TD_Database+Insertion.h"
#import "CDTConflictResolver.h"
#import "CDTDocumentBody.h"
#import "TDStatus.h"

@implementation CDTDatastore (Conflicts)


-(NSArray*) getConflictedDocumentIds
{
    if (![self.database open]) {
        return nil;
    }
    
    return [self.database getConflictedDocumentIds];
}

-(BOOL) resolveConflictsForDocument:(NSString*)docId
                           resolver:(NSObject<CDTConflictResolver>*)resolver
                              error:(NSError * __autoreleasing *)error
{
    if (![self.database open]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return NO;
    }
    
    __block NSError *localError;
    __weak CDTDatastore  *weakSelf = self;

    TDStatus retStatus = [self.database inTransaction:^TDStatus(FMDatabase *db) {
    
        CDTDatastore *strongSelf = weakSelf;
        localError = nil;
    
        NSArray *revsArray = [strongSelf activeRevisionsForDocumentId:docId database:db];
        
        if (revsArray.count <= 1) { //no conflicts for this doc
            return kTDStatusOK;
        }
        
        CDTDocumentRevision *resolvedRev = [resolver resolve:docId conflicts:revsArray];
        
        if (resolvedRev == nil) { //do nothing
            return kTDStatusOK;
        }
        
        //
        //ensure resolvedRev was in the revsArray
        //we check pointers instead of docid/revid of the returned resolvedRev
        //to protect against the scenario where a developer tries to circumvent
        //the API and return a modified document revision.
        NSUInteger resolvedRevIndex = [revsArray indexOfObjectPassingTest:
                                       ^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return obj == resolvedRev;
        }];
        
        if (resolvedRevIndex == NSNotFound) {
            localError = TDStatusToNSErrorWithInfo(kTDStatusCallbackError, nil, nil);
            
            Warn(@"CDTDatastore+Conflicts -resolveConflictsForDocument: The CDTDocumentRevision "
                 @"returned by CDTConflictResolver -resolve:conflicts was "
                 @"not found in conflicts array. "
                 @"Error code %ud, Document id: %@", kTDStatusCallbackError, docId);
            
            return kTDStatusCallbackError;
        }
        
        //
        //set all remaining conflicted revisions to deleted
        //
        for (CDTDocumentRevision *theRev in revsArray) {
            
            if (theRev == resolvedRev) {
                continue;
            }
            
            TD_Revision * toPutRevision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:YES];
            
            TDStatus status;
            [strongSelf.database putRevision:toPutRevision
                              prevRevisionID:theRev.revId
                               allowConflict:NO
                                      status:&status
                                    database:db];
            
            if (TDStatusIsError(status)) {
                localError = TDStatusToNSError(status, nil);
                Warn(@"CDTDatastore+Conflicts -resolveConflictsForDocument: Failed"
                     @" to delete non-winning revision (%@) for document %@",
                     theRev.revId, docId);
                return status;
            }
            
        }
        
        return kTDStatusOK;
    
        
    }];
    
    *error = localError;
    return retStatus == kTDStatusOK;
}

@end
