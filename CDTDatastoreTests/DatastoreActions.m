//
//  DatastoreActions.m
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>

#import "CloudantSyncTests.h"
#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"
#import "FMDatabaseAdditions.h"
#import "CDTDocumentRevision.h"
#import "TDJSON.h"

@interface DatastoreActions : CloudantSyncTests

@end

@implementation DatastoreActions


- (void)testGetADatabase
{
    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    XCTAssertNotNil(tmp, @"Could not create test database");
    XCTAssertTrue([tmp isKindOfClass:[CDTDatastore class]], @"Returned database not CDTDatastore");
}

- (NSString*)createTemporaryFileAndReturnPath
{
    NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.tempfile.XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString =  (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(tempFileNameCString, tempFileTemplateCString);
    
    char *result = mktemp(tempFileNameCString);
    if (!result)
    {
        XCTFail(@"Couldn't create temporary file");
    }
    
    NSString *path = [[NSFileManager defaultManager]
                      stringWithFileSystemRepresentation:tempFileNameCString
                      length:strlen(result)];
    
    BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    
    XCTAssertTrue(fileCreated, @"File %@ not created in %s", path, __PRETTY_FUNCTION__);
    
    free(tempFileNameCString);
    
    return path;
}

- (void)testFailToCreateFactoryWithPreExistingFile
{
    NSError *error;
    NSString *localFilePath = [self createTemporaryFileAndReturnPath];
    
    CDTDatastoreManager *localFactory = [[CDTDatastoreManager alloc] initWithDirectory:localFilePath error:&error];
    XCTAssertNil(localFactory, @"CDTDatastoreManager should fail with a pre-existing file at path in %s", __PRETTY_FUNCTION__);

    error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&error];
    XCTAssertNil(error, @"Error deleting temporary directory.");
    
}

- (void)testCreateFactoryWithPreExistingDirectory
{
    NSError *error;
    NSString *localDirPath = [self createTemporaryDirectoryAndReturnPath];
    
    CDTDatastoreManager *localFactory = [[CDTDatastoreManager alloc] initWithDirectory:localDirPath error:&error];
    XCTAssertNotNil(localFactory, @"CDTDatastoreManager should not fail with a pre-existing directory at path in %s", __PRETTY_FUNCTION__);
    
    error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:localDirPath error:&error];
    XCTAssertNil(error, @"Error deleting temporary directory.");
    
}


//Note: TD_Database -compact is throughly tested in DatastoreCRUD
- (void)testCompact
{
    NSError *error;
    CDTDatastore *datastore = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"myDocId"];
    rev.body = [@{ @"hello" : @"world" } mutableCopy];

    CDTDocumentRevision *revision = [datastore createDocumentFromRevision:rev error:&error];
    rev = [revision copy];
    rev.body = [@{ @"hello" : @"world", @"test" : @"testy" } mutableCopy];
    revision = [datastore updateDocumentFromRevision:rev error:&error];
    
    XCTAssertTrue([datastore compactWithError:&error],@"Compaction failed");
    XCTAssertNil(error, @"Error compacting datastore, %@", error);
    
    NSArray *previsousRevs = [datastore getRevisionHistory:revision];

    int compacted = 0;

    for (CDTDocumentRevision *previous in previsousRevs) {
        // erm check that one out of two has their body compacted?
        CDTDocumentRevision *prevRev =
            [datastore getDocumentWithId:previous.docId rev:previous.revId error:nil];
        
        if([prevRev.body count] == 0){
            compacted++;
        } else {
            XCTAssertEqualObjects(rev.body, prevRev.body, @"Unexpected body, wrong revision compacted?");
        }
    }
    XCTAssertEqual(1, compacted, @"Wrong number of docs compacted");
}

@end
