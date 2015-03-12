//
//  CDTQInvalidQuerySyntax.m
//  CloudantQueryObjc
//
//  Created by Rhys Short on 14/10/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import <CloudantSync.h>
#import <CDTQIndexManager.h>
#import <CDTQIndexUpdater.h>
#import <CDTQIndexCreator.h>
#import <CDTQResultSet.h>
#import <CDTQQueryExecutor.h>

SpecBegin(CDTQQueryExecutorInvalidSyntax) describe(@"cloudant query using invalid syntax", ^{

    __block NSString *factoryPath;
    __block CDTDatastoreManager *factory;

    beforeEach(^{
        // Create a new CDTDatastoreFactory at a temp path

        NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
            stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
        char *tempDirectoryNameCString = (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

        char *result = mkdtemp(tempDirectoryNameCString);
        expect(result).to.beTruthy();

        factoryPath = [[NSFileManager defaultManager]
            stringWithFileSystemRepresentation:tempDirectoryNameCString
                                        length:strlen(result)];
        free(tempDirectoryNameCString);

        NSError *error;
        factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
    });

    afterEach(^{
        // Delete the databases we used

        factory = nil;
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
    });

    describe(@"When using query ", ^{

        __block CDTDatastore *ds;
        __block CDTQIndexManager *im;

        beforeEach(^{
            ds = [factory datastoreNamed:@"test" error:nil];
            expect(ds).toNot.beNil();

            CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];

            rev.docId = @"mike12";
            rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"mike34";
            rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"mike72";
            rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"cat" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"fred34";
            rev.body = @{ @"name" : @"fred", @"age" : @34, @"pet" : @"cat" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"fred12";
            rev.body = @{ @"name" : @"fred", @"age" : @12 };
            [ds createDocumentFromRevision:rev error:nil];

            im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
            expect(im).toNot.beNil();

            expect([im ensureIndexed:@[ @"name", @"age" ] withName:@"basic"]).toNot.beNil();
            expect([im ensureIndexed:@[ @"name", @"pet" ] withName:@"pet"]).toNot.beNil();
        });

        it(@"returns nil when arugment to $or is a string", ^{
            NSDictionary *query = @{ @"$or" : @"I should be an array" };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when array passed to $or contains only a string", ^{
            NSDictionary *query = @{ @"$or" : @[ @"I should be an array" ] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when array passed to $or contains only one empty dict", ^{
            NSDictionary *query = @{ @"$or" : @[ @{} ] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when $or syntax is incorrect, using one correct dict and one empty "
           @"dict",
           ^{
            NSDictionary *query = @{ @"$or" : @[ @{@"name" : @"mike"}, @{} ] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when comparing attempting to use unsupported array comparison", ^{
            NSDictionary *query = @{ @"friends" : @[] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when $eq is top level element", ^{
            NSDictionary *query = @{ @"$eq" : @"$eq should not be top level thing" };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when array passed to $eq contains only a string", ^{
            NSDictionary *query = @{ @"name" : @[ @"I should be a dict" ] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when compareing field value to empty dict", ^{
            NSDictionary *query = @{ @"name" : @{} };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when using $or syntax for $eq", ^{
            NSDictionary *query = @{ @"name" : @[ @{@"$eq" : @"mike"} ] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when $eq syntax is incorrect, using an array of dictionaries", ^{
            NSDictionary *query = @{ @"name" : @[ @{@"$eq" : @"mike"}, @{} ] };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });

        it(@"returns nil when $exists has argument other than boolean", ^{
            NSDictionary *query = @{ @"name" : @{@"$exists" : @{}} };
            CDTQResultSet *result = [im find:query];
            expect(result).to.beNil();
        });
    });
});

SpecEnd
