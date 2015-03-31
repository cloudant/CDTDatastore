//
//  CDTFetchChanges.m
//  CloudantSync
//
//  Created by Michael Rhodes on 31/03/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTFetchChanges.h"

#import "CDTDatastore.h"
#import "CDTDocumentRevision.h"

#import "TD_Database.h"

@implementation CDTFetchChanges

#pragma mark Initialisers

- (instancetype)initWithDatastore:(CDTDatastore *)datastore
               startSequenceValue:(NSString *)startSequenceValue
{
    self = [super init];
    if (self) {
        _datastore = datastore;
        _startSequenceValue = [startSequenceValue copy];
    }
    return self;
}

#pragma mark Instance methods

- (void)main
{
    TDChangesOptions options = {.limit = 500,
        .contentOptions = 0,                                
        .includeDocs = NO,  // we only need the docIDs and sequences, body is retrieved separately
        .includeConflicts = FALSE,
        .sortBySequence = TRUE};
    
    TD_RevisionList *changes;
    SequenceNumber lastSequence = [_startSequenceValue longLongValue];

    do {
        changes = [[_datastore database] changesSinceSequence:lastSequence
                                                      options:&options
                                                       filter:nil
                                                       params:nil];
        lastSequence = [self notifyChanges:changes startingSequence:lastSequence];
    } while (changes.count > 0);

    void (^f)(NSString *nsv, NSString *ssv, NSError *fe) = self.fetchRecordChangesCompletionBlock;
    if (f) {
        f([[NSNumber numberWithLongLong:lastSequence] stringValue], _startSequenceValue, nil);
    }
}

/*
 Process a batch of changes and return the last sequence value in the changes.
 
 This method works out whether each change is an update/create or a delete, and calls
 the user-provided callback for each.
 
 @param changes changes come from the from the -changesSinceSequence:options:filter:params: call
 @param startingSequence the sequence value used for the list passed in `changes`.
            This is returned if no changes are processed.
 
 @return Last sequence number in the changes processed, used for the next _changes call.
 */
- (SequenceNumber)notifyChanges:(TD_RevisionList *)changes
               startingSequence:(SequenceNumber)startingSequence
{
    SequenceNumber lastSequence = startingSequence;
    
    // _changes provides the revs with highest rev ID, which might not be the
    // winning revision (e.g., tombstone on long doc branch). For all docs
    // that are updated rather than deleted, we need to be sure we index the
    // winning revision. This loop gets those revisions.
    NSMutableDictionary *updatedRevisions = [NSMutableDictionary dictionary];
    for (CDTDocumentRevision *rev in [_datastore getDocumentsWithIds:[changes allDocIDs]]) {
        if (rev != nil && !rev.deleted) {
            updatedRevisions[rev.docId] = rev;
        }
    }
    
    for (TD_Revision *change in changes) {
        
        CDTDocumentRevision *updatedRevision;
        if ((updatedRevision = updatedRevisions[change.docID]) != nil) {
            void (^dcb)(CDTDocumentRevision *r) = self.documentChangedBlock;
            if (dcb) {
                dcb(updatedRevision);
            }
        } else {
            void (^ddb)(NSString *docId) = self.documentWithIDWasDeletedBlock;
            if (ddb) {
                ddb(change.docID);
            }
        }
        
        lastSequence = change.sequence;
    }
    
    return lastSequence;
}


@end
