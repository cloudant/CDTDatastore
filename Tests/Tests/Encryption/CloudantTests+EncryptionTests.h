//
//  CloudantTests+EncryptionTests.h
//  EncryptionTests
//
//  Created by Enrique de la Torre Fernandez on 10/03/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CloudantTests.h"

@class CDTDatastore;

#define kCDTIndexFolder @"com.cloudant.indexing"  // in CDTIndexManager.m. Move it into .h?
#define kCDTIndexFilename @"indexes.sqlite"

#define kCDTQueryIndexFolder @"com.cloudant.sync.query"  // in CDTQIndexManager.m. Move it into .h?
#define kCDTQueryIndexFilename @"indexes.sqlite"

#define kCDTSQLiteStandardHeader @"SQLite format 3"

@interface CloudantTests (EncryptionTests)

/**
 * Returns the path to the database in the index manager for the provided datastore.
 * It does not check if the index manager was created before and it does not create it if it does
 * not exist
 *
 * @param datastore a datastore (not nil)
 *
 * @return Path to a SQLite database
 */
+ (NSString *)pathForIndexInDatastore:(CDTDatastore *)datastore;

/**
 * Returns the path to the database in the query index manager for the provided datastore.
 * It does not check if the query index manager was created before and it does not create it if
 * it does not exist
 *
 * @param datastore a datastore (not nil)
 *
 * @return Path to a SQLite database
 */
+ (NSString *)pathForQueryIndexInDatastore:(CDTDatastore *)datastore;

@end
