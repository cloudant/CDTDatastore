//
//  CDTQLifecycleTests.m
//  CDTDatastore
//
//  Created by tomblench on 14/05/2018.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <CDTDatastore/CloudantSync.h>

@interface CDTQLifecycleTests : XCTestCase
@end

@implementation CDTQLifecycleTests

-(void)testDatastoreDeletesCorrectly
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
    NSError *__autoreleasing *error2;
    CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
    @autoreleasepool{
        
        // create datastore
        CDTDatastore *datastore = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        // create some docs
        int nDocs = 10;
        for (int i=0; i<nDocs;i++) {
            NSMutableDictionary *dict = [@{ @"hello" : @"world" } mutableCopy];
            CDTDocumentRevision *document = [CDTDocumentRevision revision];
            document.body = dict;
            [datastore createDocumentFromRevision:document
                                            error:&error];
            XCTAssertNil(error);
            // ensure indexed within loop
            [datastore ensureIndexed:@[@"hello"] withName:@"index"];
        }
        CDTQResultSet *rs = [datastore find:@{@"hello":@"world"}];
        XCTAssertEqual([[rs documentIds] count], nDocs);
    }
    // Now everything in the above autoreleasepool has had dealloc
    // called on it eventually (we assume) the datastore and the
    // result set would go out of scope but this forces them to have
    // dealloc called.  Without the autoreleasepools, the log message
    // "BUG IN CLIENT OF libsqlite3.dylib: database integrity
    // compromised by API violation: vnode unlinked while in use:
    // {filename}" will appear. Although on most platforms the on-disk
    // deletion will proceed once all filehandles are closed, so in
    // principle this should not be a problem, as long as dealloc is
    // called "eventually" (in the case of this test, it would get
    // called when this test method exits).
    @autoreleasepool{
        // delete datastore
        [factory deleteDatastoreNamed:@"test" error:error2];
        XCTAssertTrue(error2 == nil);
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:factoryPath error:error2];
        XCTAssertTrue(error2 == nil);
        XCTAssertEqual([contents count], 0);
    }
}

-(void)testManagersCloseAndReopen
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
    int nDocs = 10;
    @autoreleasepool{
        // get manager
        CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        // create datastore
        CDTDatastore *datastore = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        
        // create some docs
        for (int i=0; i<nDocs;i++) {
            NSMutableDictionary *dict = [@{ @"hello" : @"world" } mutableCopy];
            CDTDocumentRevision *document = [CDTDocumentRevision revision];
            document.body = dict;
            [datastore createDocumentFromRevision:document
                                            error:&error];
            XCTAssertNil(error);
            // ensure indexed within loop
            [datastore ensureIndexed:@[@"hello"] withName:@"index"];
        }
        CDTQResultSet *rs = [datastore find:@{@"hello":@"world"}];
        XCTAssertEqual([[rs documentIds] count], nDocs);
    }
    @autoreleasepool{
        // get manager
        CDTDatastoreManager *factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        // open existing datastore
        CDTDatastore *datastore = [factory datastoreNamed:@"test" error:&error];
        XCTAssertNil(error);
        // check index exists
        XCTAssertEqual([[datastore listIndexes] count], 1);
        // query
        CDTQResultSet *rs = [datastore find:@{@"hello":@"world"}];
        XCTAssertEqual([[rs documentIds] count], nDocs);
    }
}

@end
