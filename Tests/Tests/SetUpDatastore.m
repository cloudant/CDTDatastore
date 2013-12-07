//
//  SetUpDatastore.m
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "SetUpDatastore.h"
#import "CDTDatastoreManager.h"

@implementation SetUpDatastore

- (void)testSetupAndTeardownDatastore
{
    // Set-up code here.
    NSString *tempDirectoryTemplate =
    [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
    const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString =  (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
    
    char *result = mkdtemp(tempDirectoryNameCString);
    if (!result)
    {
        STFail(@"Couldn't create temporary directory");
    }
    
    NSString *factoryPath = [[NSFileManager defaultManager]
                        stringWithFileSystemRepresentation:tempDirectoryNameCString
                        length:strlen(result)];
    free(tempDirectoryNameCString);
    
    NSError *error;
    CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
    
    STAssertNotNil(factory, @"Factory was nil");
    
    // Tear-down code here.
    factory = nil;
    
    [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
}

@end
