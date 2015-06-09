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

@interface CDTFetchChanges ()

@property (nonatomic, copy) void (^mDocumentChangedBlock)(CDTDocumentRevision *revision);

@property (nonatomic, copy) void (^mDocumentWithIDWasDeletedBlock)(NSString *docId);

@property (nonatomic, copy) void (^mFetchRecordChangesCompletionBlock)
    (NSString *newSequenceValue, NSString *startSequenceValue, NSError *fetchError);

@property (nonatomic, strong) CDTDatastore *mDatastore;

@property (nonatomic, copy) NSString *mStartSequenceValue;

@end

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
    // Ensure our settings are not changed during execution
    self.mDocumentChangedBlock = self.documentChangedBlock;
    self.mDocumentWithIDWasDeletedBlock = self.documentWithIDWasDeletedBlock;
    self.mFetchRecordChangesCompletionBlock = self.fetchRecordChangesCompletionBlock;
    self.mDatastore = self.datastore;
    self.mStartSequenceValue = self.startSequenceValue;

    TDChangesOptions options = {.limit = 500,
        .contentOptions = 0,                                
        .includeDocs = NO,  // we only need the docIDs and sequences, body is retrieved separately
        .includeConflicts = FALSE,
        .sortBySequence = TRUE};
    
    TD_RevisionList *changes;
    SequenceNumber lastSequence = [self.mStartSequenceValue longLongValue];

    do {
        if ([self isCancelled]) {
            return;  // Bail early, don't call completion block
        }

        changes = [[self.mDatastore database] changesSinceSequence:lastSequence
                                                           options:&options
                                                            filter:nil
                                                            params:nil];
        lastSequence = [self notifyChanges:changes startingSequence:lastSequence];
    } while (changes.count > 0);

    if (self.mFetchRecordChangesCompletionBlock) {
        // Try our best to avoid calling the completion block if cancelled is set:
        //  - after the check in the loop above 
        //  - where there are no remaining changes, so we fall through to here
        if (![self isCancelled]) {
            self.mFetchRecordChangesCompletionBlock(
                [[NSNumber numberWithLongLong:lastSequence] stringValue], self.mStartSequenceValue,
                nil);
        }
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
    if ([self isCancelled]) {
        return startingSequence;  // processed no changes
    }

    SequenceNumber lastSequence = startingSequence;
    
    // _changes provides the revs with highest rev ID, which might not be the
    // winning revision (e.g., tombstone on long doc branch). For all docs
    // that are updated rather than deleted, we need to be sure we index the
    // winning revision. This loop gets those revisions.
    NSMutableDictionary *updatedRevisions = [NSMutableDictionary dictionary];
    for (CDTDocumentRevision *rev in [self.mDatastore getDocumentsWithIds:[changes allDocIDs]]) {
        if (rev != nil && !rev.deleted) {
            updatedRevisions[rev.docId] = rev;
        }
    }
    
    for (TD_Revision *change in changes) {
        if ([self isCancelled]) {
            return lastSequence;  // We processed changes up to this sequence
        }

        CDTDocumentRevision *updatedRevision;
        if ((updatedRevision = updatedRevisions[change.docID]) != nil) {
            if (self.mDocumentChangedBlock) {
                self.mDocumentChangedBlock(updatedRevision);
            }
        } else {
            if (self.mDocumentWithIDWasDeletedBlock) {
                self.mDocumentWithIDWasDeletedBlock(change.docID);
            }
        }
        
        lastSequence = change.sequence;
    }
    
    return lastSequence;
}


@end
