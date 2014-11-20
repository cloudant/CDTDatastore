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

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantSyncTests.h"
#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"
#import "FMDatabaseAdditions.h"
#import "CDTMutableDocumentRevision.h"
#import "CDTDocumentRevision.h"
#import "TDJSON.h"

@interface DatastoreActions : CloudantSyncTests

@end

@implementation DatastoreActions


- (void)testGetADatabase
{
    NSError *error;
    CDTDatastore *tmp = [self.factory datastoreNamed:@"test_database" error:&error];
    STAssertNotNil(tmp, @"Could not create test database");
    STAssertTrue([tmp isKindOfClass:[CDTDatastore class]], @"Returned database not CDTDatastore");
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
        STFail(@"Couldn't create temporary file");
    }
    
    NSString *path = [[NSFileManager defaultManager]
                      stringWithFileSystemRepresentation:tempFileNameCString
                      length:strlen(result)];
    
    BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    
    STAssertTrue(fileCreated, @"File %@ not created in %s", path, __PRETTY_FUNCTION__);
    
    free(tempFileNameCString);
    
    return path;
}

- (void)testFailToCreateFactoryWithPreExistingFile
{
    NSError *error;
    NSString *localFilePath = [self createTemporaryFileAndReturnPath];
    
    CDTDatastoreManager *localFactory = [[CDTDatastoreManager alloc] initWithDirectory:localFilePath error:&error];
    STAssertNil(localFactory, @"CDTDatastoreManager should fail with a pre-existing file at path in %s", __PRETTY_FUNCTION__);

    error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&error];
    STAssertNil(error, @"Error deleting temporary directory.");
    
}

- (void)testCreateFactoryWithPreExistingDirectory
{
    NSError *error;
    NSString *localDirPath = [self createTemporaryDirectoryAndReturnPath];
    
    CDTDatastoreManager *localFactory = [[CDTDatastoreManager alloc] initWithDirectory:localDirPath error:&error];
    STAssertNotNil(localFactory, @"CDTDatastoreManager should not fail with a pre-existing directory at path in %s", __PRETTY_FUNCTION__);
    
    error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:localDirPath error:&error];
    STAssertNil(error, @"Error deleting temporary directory.");
    
}


//Note: TD_Database -compact is throughly tested in DatastoreCRUD
- (void)testCompact
{
    NSError *error;
    CDTDatastore *datastore = [self.factory datastoreNamed:@"test_database" error:&error];
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.body = @{ @"hello" : @"world" };
    rev.docId = @"myDocId";
    
    CDTDocumentRevision *revision = [datastore createDocumentFromRevision:rev error:&error];
    rev = [revision mutableCopy];
    rev.body = @{ @"hello" : @"world", @"test" : @"testy" };
    revision = [datastore updateDocumentFromRevision:rev error:&error];
    
    STAssertTrue([datastore compactWithError:&error],@"Compaction failed");
    STAssertNil(error, @"Error compacting datastore, %@", error);
    
    NSArray *previsousRevs = [datastore getRevisionHistory:revision];

    int compacted = 0;

    for (CDTDocumentRevision *previous in previsousRevs) {
        // erm check that one out of two has their body compacted?
        CDTDocumentRevision *prevRev =
            [datastore getDocumentWithId:previous.docId rev:previous.revId error:nil];
        
        if([prevRev.body count] == 0){
            compacted++;
        } else {
            STAssertEqualObjects(rev.body, prevRev.body, @"Unexpected body, wrong revision compacted?");
        }
    }
    STAssertEquals(1, compacted, @"Wrong number of docs compacted");
}

@end
