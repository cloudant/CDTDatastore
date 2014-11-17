//
//  CDTIndexer.h
//
//
//  Created by Thomas Blench on 29/01/2014.
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
#import "CDTIndex.h"

@class CDTDocumentRevision;

/**
 Protocol adopted by classes which supply values to index for a given document.

 Implementing this protocol allows developers to control when
 values are indexed for each document that is indexed by a
 particular named index. The class should be supplied as an
 argument to [CDTIndexManager ensureIndexedWithIndexName:type:indexer:error:].

 For each document added or updated to a datastore, the -valuesForRevision:indexName:
 will be called. It returns an array of values, which this document is indexed
 against. Later, the index can be queried for these values, and documents found
 which were indexed against those values.

 An example index might be returning an array of the items from a document's
 `firstName`, `middleNames`, `lastName` and `nickname` fields when creating
 an all-encompassing `name` index.

 See CDTFieldIndexer for a concrete implementation of an indexer that
 returns the value of a single document field.

 @see CDTFieldIndexer
 */
@protocol CDTIndexer

/**
 * This method is used to map between a document and
 * indexed value(s) by the CDTIndexManager.
 *
 * This method is called for every document as it is
 * either inserted into the index for the first time, or its
 * value changes and it needs to be updated.
 *
 * @param revision the document revision to be indexed.
 * @param indexName name of the index the values are destined for.
 *
 * @return an array of one or more values to be inserted/updated,
 *         or nil if this revision should not be indexed.
 *         The types of the objects in the array should match
 *         the index's type passed to [CDTIndexManager
 *ensureIndexedWithIndexName:type:indexer:error:].
 */
- (NSArray *)valuesForRevision:(CDTDocumentRevision *)revision indexName:(NSString *)indexName;

@end
