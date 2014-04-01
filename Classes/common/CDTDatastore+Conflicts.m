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
        TD_Revision *toPutRevision = nil;
        TDStatus status;
    
        NSArray *revsArray = [strongSelf activeRevisionsForDocumentId:docId database:db];
        
        if (revsArray.count <= 1) { //no conflicts for this doc
            return kTDStatusOK;
        }
        
        CDTDocumentRevision *resolvedRev = [resolver resolve:docId conflicts:revsArray];
        
        if (resolvedRev == nil) { //do nothing
            return kTDStatusOK;
        }
        
        //
        //get current winning revision
        //
        TD_Revision *currentWinningTDRev = [strongSelf.database getDocumentWithID:docId
                                                                       revisionID:nil
                                                                          options:0
                                                                           status:&status
                                                                         database:db];
        if (TDStatusIsError(status)) {
            localError = TDStatusToNSError(status, nil);
            return status;
        }
        
        //
        //create a new TD_Revision to insert into the database
        //
        // if the resolved revision is deleted, we need to use the TD*
        // methods to update this revision. If it is not deleted, use
        // the CDTDatastore -updateDocumentWithId since it propery handles attachments
        //
        if (resolvedRev.deleted) {
            toPutRevision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:resolvedRev.deleted];
            
            [strongSelf.database putRevision:toPutRevision
                              prevRevisionID:currentWinningTDRev.revID
                               allowConflict:NO
                                      status:&status
                                    database:db];
            
            if (TDStatusIsError(status)) {
                localError = TDStatusToNSError(status, nil);
                return status;
            }
            
        }
        else {
            CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:resolvedRev.td_rev.properties];
            BOOL rollback = NO;
            [self updateDocumentWithId:docId
                               prevRev:currentWinningTDRev.revID
                                  body:body
                         inTransaction:db
                              rollback:&rollback
                                 error:&localError];
            
            //at this point, localError.code will not be exactly the same as the TDStatus
            if (localError) {
                return localError.code;
            }
        }
        
        
        //
        //set all remaining conflicted revisions to deleted
        //
        for(CDTDocumentRevision *aRev in revsArray){
            if (![aRev.revId isEqualToString:currentWinningTDRev.revID] && ![aRev deleted]) {
                
                toPutRevision = [[TD_Revision alloc] initWithDocID:docId
                                                             revID:nil
                                                           deleted:YES];

                [strongSelf.database putRevision:toPutRevision
                                  prevRevisionID:aRev.revId
                                   allowConflict:NO
                                          status:&status
                                        database:db];
                
                if (TDStatusIsError(status)) {
                    localError = TDStatusToNSError(status, nil);
                    return status;
                }
                
            }
        }
        
        //we are done.
        return kTDStatusOK;
    }];
    
    *error = localError;
    return retStatus == kTDStatusOK ? YES : NO;
}

@end
