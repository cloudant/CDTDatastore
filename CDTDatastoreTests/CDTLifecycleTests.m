//
//  CDTLifecycleTests.m
//  CDTDatastore
//
//  Created by tomblench on 27/06/2018.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <CDTDatastore/CloudantSync.h>
#import <objc/runtime.h>
#import <RSSwizzle/RSSwizzle.h>
#import "TD_Database.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

#include <sys/stat.h>

@protocol CDTEncryptionKeyProvider;

static int cdtDatastoreDeallocCount;
static int cdtqIndexManagerDeallocCount;

static int cdtDatastoreInitCount;
static int cdtqIndexManagerInitCount;

@interface CDTLifecycleTests : XCTestCase
@end

@implementation CDTLifecycleTests

-(void)setUp {
    cdtDatastoreDeallocCount = 0;
    cdtqIndexManagerDeallocCount = 0;

    cdtDatastoreInitCount = 0;
    cdtqIndexManagerInitCount = 0;
}

+(void)setUp
{
    // "swizzle" dealloc for these classes by incrementing our counter and then calling the original method:
    // - CDTDatastore
    // - CDTQIndexManager
    RSSwizzleInstanceMethod(CDTDatastore,
                            NSSelectorFromString(@"dealloc"),
                            RSSWReturnType(void),
                            RSSWArguments(),
                            RSSWReplacement({
        // increment
        cdtDatastoreDeallocCount++;
        RSSWCallOriginal();
    }), 0, NULL);
    RSSwizzleInstanceMethod(CDTQIndexManager,
                            NSSelectorFromString(@"dealloc"),
                            RSSWReturnType(void),
                            RSSWArguments(),
                            RSSWReplacement({
        // increment
        cdtqIndexManagerDeallocCount++;
        RSSWCallOriginal();
    }), 0, NULL);

    RSSwizzleInstanceMethod(CDTDatastore,
                            NSSelectorFromString(@"initWithManager:database:encryptionKeyProvider:"),
                            RSSWReturnType(id),
                            RSSWArguments(CDTDatastoreManager *manager, TD_Database *database, id<CDTEncryptionKeyProvider> provider),
                            RSSWReplacement({
        // increment
        cdtDatastoreInitCount++;
        return RSSWCallOriginal(manager, database, provider);
    }), 0, NULL);

    RSSwizzleInstanceMethod(CDTQIndexManager,
                            NSSelectorFromString(@"initUsingDatastore:error:"),
                            RSSWReturnType(id),
                            RSSWArguments(CDTDatastore *datastore, NSError *__autoreleasing __nullable *__nullable error),
                            RSSWReplacement({
        // increment
        cdtqIndexManagerInitCount++;
        return RSSWCallOriginal(datastore, error);
    }), 0, NULL);
}

// check that the same datastore instance is obtained each time
-(void)testSameDatastoreInstance
{
    @autoreleasepool {
        NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                                           stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char *tempDirectoryTemplateCString =
        [tempDirectoryTemplate fileSystemRepresentation];
        char *tempDirectoryNameCString =
        (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
        
        char *result = mkdtemp(tempDirectoryNameCString);
        
        NSString *factoryPath = [[NSFileManager defaultManager]
                                 stringWithFileSystemRepresentation:tempDirectoryNameCString
                                 length:strlen(result)];
        free(tempDirectoryNameCString);
        
        NSError *error;
        CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        CDTDatastore *ds1 = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        CDTDatastore *ds2 = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        XCTAssertEqual(ds1, ds2);
    }
}

// check that the same index manager instance is obtained each time
-(void)testSameIndexManagerInstance
{
    @autoreleasepool {
        NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                                           stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char *tempDirectoryTemplateCString =
        [tempDirectoryTemplate fileSystemRepresentation];
        char *tempDirectoryNameCString =
        (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
        
        char *result = mkdtemp(tempDirectoryNameCString);
        
        NSString *factoryPath = [[NSFileManager defaultManager]
                                 stringWithFileSystemRepresentation:tempDirectoryNameCString
                                 length:strlen(result)];
        free(tempDirectoryNameCString);
        
        NSError *error;
        
        
        CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        [[factory datastoreNamed:@"test" error:&error] updateAllIndexes];
        [[factory datastoreNamed:@"test" error:&error] updateAllIndexes];
    }
    // only one index manager was inited, proving that the instance was reused
    XCTAssertEqual(cdtqIndexManagerInitCount, 1);
}

// check that index manager was deallocated when datastore was deallocated
-(void)testIndexManagerDeallocsWhenDatastoreDeallocs
{
    @autoreleasepool {
        NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                                           stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char *tempDirectoryTemplateCString =
        [tempDirectoryTemplate fileSystemRepresentation];
        char *tempDirectoryNameCString =
        (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
        
        char *result = mkdtemp(tempDirectoryNameCString);
        
        NSString *factoryPath = [[NSFileManager defaultManager]
                                 stringWithFileSystemRepresentation:tempDirectoryNameCString
                                 length:strlen(result)];
        free(tempDirectoryNameCString);
        
        NSError *error;
        CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        CDTDatastore *ds1 = [factory datastoreNamed:@"test" error:&error];
        [ds1 updateAllIndexes];
        XCTAssertNil(error);
    }
    // index manager was deallocated when datastore was deallocated
    XCTAssertEqual(cdtqIndexManagerDeallocCount, 1);
}

// check that datastore was deallocated when manager was deallocated
-(void)testDatastoreDeallocsWhenManagerDeallocs
{
    @autoreleasepool {
        NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                                           stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char *tempDirectoryTemplateCString =
        [tempDirectoryTemplate fileSystemRepresentation];
        char *tempDirectoryNameCString =
        (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
        
        char *result = mkdtemp(tempDirectoryNameCString);
        
        NSString *factoryPath = [[NSFileManager defaultManager]
                                 stringWithFileSystemRepresentation:tempDirectoryNameCString
                                 length:strlen(result)];
        free(tempDirectoryNameCString);
        
        NSError *error;
        CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        CDTDatastore *ds1 = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
    }
    // datastore was deallocated when manager was deallocated
    XCTAssertEqual(cdtDatastoreDeallocCount, 1);
}

// check that explicitly closing datastore deallocates it, despite still holding a pointer to manager
-(void)testExplicitCloseDeallocs
{
    NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                                       stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
    const char *tempDirectoryTemplateCString =
    [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString =
    (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
    
    char *result = mkdtemp(tempDirectoryNameCString);
    
    NSString *factoryPath = [[NSFileManager defaultManager]
                             stringWithFileSystemRepresentation:tempDirectoryNameCString
                             length:strlen(result)];
    free(tempDirectoryNameCString);
    
    NSError *error;
    CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
    // assign to ds1 inside an autoreleasepool so our pointer doesn't hang on to it
    @autoreleasepool {
        CDTDatastore *ds1 = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        [factory closeDatastoreNamed:@"test"];
    }
    XCTAssertEqual(cdtDatastoreInitCount, 1);
    XCTAssertEqual(cdtDatastoreDeallocCount, 1);
}

// ensure that we don't have the filehandle open to the index manager before trying to delete it
-(void)testDeletingDatastoreDeletesIndexManagerAfterClosingFilehandle
{
    NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                                       stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
    const char *tempDirectoryTemplateCString =
    [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString =
    (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
    
    char *result = mkdtemp(tempDirectoryNameCString);

    // duplicate stderr fd so we can re-use it later
    int stderr_orig = dup(2);
    // redirect stderr to temporary file
    char *stderr_redir_filename;
    asprintf(&stderr_redir_filename, "%s/%s", tempDirectoryNameCString, "stderr.redirect.txt");
    FILE *stderr_redir = freopen(stderr_redir_filename, "w", stderr);

    NSString *factoryPath = [[NSFileManager defaultManager]
                             stringWithFileSystemRepresentation:tempDirectoryNameCString
                             length:strlen(result)];
    free(tempDirectoryNameCString);
    
    NSError *error;
    CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
    // assign to ds1 inside an autoreleasepool so our pointer doesn't hang on to it
    @autoreleasepool {
        CDTDatastore *ds1 = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        [ds1 updateAllIndexes];
    }
    [factory deleteDatastoreNamed:@"test" error:&error];
    // assert that the following message is not output:
    // "BUG IN CLIENT OF libsqlite3.dylib: database integrity compromised by API violation: vnode unlinked while in use"
    // close redirected file
    fclose (stderr_redir);
    // reassign stderr to correct fd for subsequent tests
    stderr = fdopen(stderr_orig, "a");
    // mmap the redirected file to search for string
    struct stat st;
    stat(stderr_redir_filename, &st);
    int fd = open(stderr_redir_filename, O_RDONLY, 0);
    void *stderr_redirect_buf = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    XCTAssert(strstr(stderr_redirect_buf,
                     "BUG IN CLIENT OF libsqlite3.dylib: database integrity compromised by API violation: vnode unlinked while in use") == NULL,
              "The redirected stderr log file should not contain the \"BUG IN CLIENT\" error string");
    // free resources
    free(stderr_redir_filename);
    munmap(stderr_redirect_buf, st.st_size);
    close(fd);
}

@end
