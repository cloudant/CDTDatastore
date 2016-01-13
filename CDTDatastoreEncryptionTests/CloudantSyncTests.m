//
//  CloudantSyncTests.m
//  CloudantSyncTests
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

#import "CloudantSyncTests.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"

#import <FMDB/FMDatabaseAdditions.h>
#import <FMDB/FMDatabaseQueue.h>
#import <FMDB/FMResultSet.h>

#import "CDTLogging.h"
#import <CocoaLumberjack/DDTTYLogger.h>
@implementation CloudantSyncTests

- (NSString *)createTemporaryDirectoryAndReturnPath
{
    NSString *tempDirectoryTemplate =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
    const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString = (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

    char *result = mkdtemp(tempDirectoryNameCString);
    if (!result) {
        XCTFail(@"Couldn't create temporary directory");
    }

    NSString *path =
        [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempDirectoryNameCString
                                                                    length:strlen(result)];
    free(tempDirectoryNameCString);

    return path;
}

- (NSString *)pathForDBName:(NSString *)name
{
    return [self.factoryPath
        stringByAppendingPathComponent:[name stringByAppendingPathExtension:kDBExtension]];
}

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.

    self.factoryPath = [self createTemporaryDirectoryAndReturnPath];

    NSError *error;
    self.factory = [[CDTDatastoreManager alloc] initWithDirectory:self.factoryPath error:&error];

    XCTAssertNil(error, @"CDTDatastoreManager had error");
    XCTAssertNotNil(self.factory, @"Factory is nil");
}

- (void)tearDown
{
    self.factory = nil;

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:self.factoryPath error:&error];
    XCTAssertNil(error, @"Error deleting temporary directory.");

    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

@end
