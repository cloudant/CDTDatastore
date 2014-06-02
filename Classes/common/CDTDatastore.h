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
@class FMDatabase;

/** NSNotification posted when a document is updated.
 UserInfo keys:
  - @"rev": the new CDTDocumentRevision,
  - @"source": NSURL of remote db pulled from,
  - @"winner": new winning CDTDocumentRevision, _if_ it changed (often same as rev).
 */
extern NSString* const CDTDatastoreChangeNotification;

@class TD_Database;

/**
 * The CDTDatastore is the core interaction point for create, delete and update
 * operations (CRUD) for within Cloudant Sync.
 *
 * The Datastore can be viewed as a pool of heterogeneous JSON documents. One
 * datastore can hold many different types of document, unlike tables within a
 * relational model. The datastore provides hooks, which allow for various querying models
 * to be built on top of its simpler key-value model.
 *
 * Each document consists of a set of revisions, hence most methods within
 * this class operating on CDTDocumentRevision objects, which carry both a
 * document ID and a revision ID. This forms the basis of the MVCC data model,
 * used to ensure safe peer-to-peer replication is possible.
 *
 * Each document is formed of a tree of revisions. Replication can create
 * branches in this tree when changes have been made in two or more places to
 * the same document in-between replications. MVCC exposes these branches as
 * conflicted documents. These conflicts should be resolved by user-code, by
 * marking all but one of the leaf nodes of the branches as "deleted", using
 * the [CDTDatastore deleteDocumentWithId:rev:error:] method. When the
 * datastore is next replicated with a remote datastore, this fix will be
 * propagated, thereby resolving the conflicted document across the set of
 * peers.
 *
 * **WARNING:** conflict resolution is coming in the next
 * release, where we'll be adding methods to:
 *
 * - Get the IDs of all conflicted documents within the datastore.</li>
 * - Get a list of all current revisions for a given document, so they
 *     can be merged to resolve the conflict.</li>
 *
 * @see CDTDocumentRevision
 *
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
 * Add a new document with the given ID and body.
 *
 * @param docId id for the document
 * @param body  JSON body for the document
 * @param error will point to an NSError object in case of error.
 *
 * @return revision of the newly created document
 */
-(CDTDocumentRevision *) createDocumentWithId:(NSString*)docId
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error;


/**
 * Add a new document with an auto-generated ID.
 *
 * The generated ID can be found from the returned CDTDocumentRevision.
 *
 * @param body JSON body for the document
 * @param error will point to an NSError object in case of error.
 *
 * @return revision of the newly created document
 */
-(CDTDocumentRevision *) createDocumentWithBody:(CDTDocumentBody*)body
                                          error:(NSError * __autoreleasing *)error;


/**
 * Returns a document's current winning revision.
 *
 * @param docId id of the specified document
 * @param error will point to an NSError object in case of error.
 *
 * @return current revision as CDTDocumentRevision of given document
 */
-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                     error:(NSError * __autoreleasing *)error;


/**
 * Return a specific revision of a document.
 *
 * This method gets the revision of a document with a given ID. As the
 * datastore prunes the content of old revisions to conserve space, this
 * revision may contain the metadata but not content of the revision.
 *
 * @param docId id of the specified document
 * @param rev id of the specified revision
 * @param error will point to an NSError object in case of error.
 *
 * @return specified CDTDocumentRevision of the document for given
 *     document id or nil if it doesn't exist
 */
-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                       rev:(NSString*)rev
                                     error:(NSError * __autoreleasing *)error;

/**
 * Unpaginated read of all documents.
 *
 * All documents are read into memory before being returned.
 *
 * Only the current winning revision of each document is returned.
 *
 * @return NSArray of CDTDocumentRevisions
 */
-(NSArray*) getAllDocuments;


/**
 * Enumerate the current winning revisions for all documents in the
 * datastore.
 *
 * Logically, this method takes all the documents in either ascending
 * or descending order, skips all documents up to `offset` then
 * returns up to `limit` document revisions, stopping either
 * at `limit` or when the list of document is exhausted.
 *
 * Note that if the datastore changes between calls using offset/limit,
 * documents may be missed out.
 *
 * @param offset    start position
 * @param limit maximum number of documents to return
 * @param descending ordered descending if true, otherwise ascendingly
 * @return NSArray containing CDTDocumentRevision objects
 */
-(NSArray*) getAllDocumentsOffset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                       descending:(BOOL)descending;


/**
 * Return the winning revisions for a set of document IDs.
 *
 * @param docIds list of document id
 *
 * @return NSArray containing CDTDocumentRevision objects
 */
-(NSArray*) getDocumentsWithIds:(NSArray*)docIds;


/**
 * Returns the history of revisions for the passed revision.
 *
 * This is each revision on the branch that `revision` is on,
 * from `revision` to the root of the tree.
 *
 * Older revisions will not contain the document data as it will have
 * been compacted away.
 */
-(NSArray*) getRevisionHistory:(CDTDocumentRevision*)revision;


/**
 * Updates a document that exists in the datastore with a new revision.
 *
 * The `prevRev` parameter must contain the revision ID of the current
 * winning revision, otherwise a conflict error will be returned.
 *
 * @param docId ID of document
 * @param prevRev revision ID of revision to replace
 * @param body          document body of the new revision
 * @param error will point to an NSError object in case of error.
 *
 * @return CDTDocumentRevsion of the updated document, or `nil` if there was an error.
 */
-(CDTDocumentRevision *) updateDocumentWithId:(NSString*)docId
                                   prevRev:(NSString*)prevRev
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error;

/*
 Allow for updateDocumentWithId to partake in a transaction. Useful for
 internal code, particularly attachments. It's public because otherwise
 the Attachments category couldn't access it.
 
 This method modifies multiple tables, so must be called in a transaction.
 
 @return New revision, or nil if the update failed.
 */
-(CDTDocumentRevision *) updateDocumentWithId:(NSString*)docId
                                      prevRev:(NSString*)prevRev
                                         body:(CDTDocumentBody*)body
                                inTransaction:(FMDatabase*)db
                                     rollback:(BOOL*)rollback
                                        error:(NSError * __autoreleasing *)error;

/**
 * Delete a document.
 *
 * Any non-deleted leaf revision of a document may be deleted using this method,
 * to allow for conflicts to be cleaned up.
 *
 * @param docId documentId of the document to be deleted
 * @param rev revision ID of a leaf revision of the document
 * @param error will point to an NSError object in case of error.
 *
 * @return CDTDocumentRevsion of the deleted document, or `nil` if there was an error.
 */
-(CDTDocumentRevision*) deleteDocumentWithId:(NSString*)docId
                                         rev:(NSString*)rev
                                       error:(NSError * __autoreleasing *)error;

/**
 * Return a directory for an extension to store its data for this CDTDatastore.
 *
 * @param extensionName name of the extension
 *
 * @return the directory for specified extensionName
 */
-(NSString*) extensionDataFolder:(NSString*)extensionName;

@end

