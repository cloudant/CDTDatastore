//
//  CloudantSyncIOSTests.m
//  CloudantSyncIOSTests
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CloudantSyncIOSTests.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"

@interface CloudantSyncIOSTests ()

@end

@implementation CloudantSyncIOSTests

- (void)setUp
{
    [super setUp];
    
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
    
    self.factoryPath = [[NSFileManager defaultManager]
                        stringWithFileSystemRepresentation:tempDirectoryNameCString
                        length:strlen(result)];
    free(tempDirectoryNameCString);
    
    NSError *error;
    self.factory = [[CDTDatastoreManager alloc] initWithDirectory:self.factoryPath error:&error];
    
    STAssertNil(error, @"CDTDatastoreManager had error");
    STAssertNotNil(self.factory, @"Factory is nil");
}

- (void)tearDown
{
    // Tear-down code here.
    self.factory = nil;
    
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:self.factoryPath error:&error];
    
    [super tearDown];
}

@end
