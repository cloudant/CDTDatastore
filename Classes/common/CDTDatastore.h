//
//  CDTDatastore.h
//  CloudantSync
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

@class CDTDocumentRevision;
@class CDTDocumentBody;

/** NSNotification posted when a document is updated.
 UserInfo keys: 
  - @"rev": the new CDTDocumentRevision, 
  - @"source": NSURL of remote db pulled from,
  - @"winner": new winning CDTDocumentRevision, _if_ it changed (often same as rev). 
 */
extern NSString* const CDTDatastoreChangeNotification;

@class TD_Database;

/**
 * A datastore containing heterogeneous JSON documents.
 */
@interface CDTDatastore : NSObject

@property (nonatomic,strong,readonly) TD_Database *database;

+(NSString*)versionString;

-(id)initWithDatabase:(TD_Database*)database;

/**
 * The number of document in the datastore.
 */
@property (readonly) NSUInteger documentCount;

/**
 * The name of the datastore.
 */
@property (readonly) NSString *name;

/**
 * The name of the datastore.
 */
@property (readonly) NSString *extensionsDir;

/**
 * Create a new document with the given document id and JSON body
 *
 * @param documentId id for the document
 * @param body      JSON body for the document
 * @return revision of the newly created document
 */
-(CDTDocumentRevision *) createDocumentWithId:(NSString*)docId
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error;


/**
 * Create a new document with the given body, and id is generated implicitly for the document.
 *
 * @param body JSON body for the document
 * @return revision of the newly created document
 */
-(CDTDocumentRevision *) createDocumentWithBody:(CDTDocumentBody*)body
                                          error:(NSError * __autoreleasing *)error;


/**
 * @param documentId id of the specified document
 * @return current revision as CDTDocumentRevision of given document
 */
-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                     error:(NSError * __autoreleasing *)error;


/**
 * @param documentId id of the specified document
 * @param revisionId id of the specified revision
 * @return specified CDTDocumentRevision of the document for given 
 *     document id or nil if it doesn't exist
 */
-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                       rev:(NSString*)rev
                                     error:(NSError * __autoreleasing *)error;


/**
 * Pagination read of all documents. Logically, it lists all the documents
 * in descending order if descending option is true, otherwise in 
 * ascending order. Then start from offset (included) position, and 
 * return up to maxItem items.
 *
 * Only the current revision of each document is returned.
 *
 * @param offset    start position
 * @param maxResults Maximum number of documents to return
 * @param descending ordered descending if true, otherwise ascendingly
 * @return list of CSDatastoreObjects
 */
-(NSArray*) getAllDocumentsOffset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                       descending:(BOOL)descending;


/**
 * Return a list of the documents for the given list of documentIds, 
 * only current revision of each document returned
 *
 * @param documentIds list of document id
 * @param descending  if true, the list is in descending order
 * @return list of the documents
 */
-(NSArray*) getDocumentsWithIds:(NSArray*)docIds;


/**
 * Stores a new (or initial) revision of a document.
 * <p/>
 * The previous revision id must be supplied when necessary and the 
 * call will fail if it doesn't match.
 *
 * @param prevRevisionId id of the revision to replace , or null if this 
 *         is a new document.
 * @param allowConflict  if false, an ConflictException is thrown out 
           if the insertion would create a conflict,
 *         i.e. if the previous revision already has a child.
 * @param body          document body of the new revision
 * @return new DBObject with the documentId, revisionId
 */
-(CDTDocumentRevision *) updateDocumentWithId:(NSString*)docId
                                   prevRev:(NSString*)prevRev
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error;

/**
 * Delete the specified document.
 *
 * @param documentId documentId of the document to be deleted
 * @param revisionId revision id if of the document to be deleted
 * Returns NO if the document couldn't be deleted.
 */
-(BOOL) deleteDocumentWithId:(NSString*)docId
                         rev:(NSString*)rev
                       error:(NSError * __autoreleasing *)error;

-(NSString*) extensionDataFolder:(NSString*)extensionName;

@end

