//
//  DatastoreActions.m
//  CloudantSync
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantSyncTests.h"

#import "CDTDatastore.h"
#import "CDTDatastoreManager.h"

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
    NSString *tempFileTemplate =
    [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.tempfile.XXXXXX"];
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


@end
