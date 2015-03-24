//
//  CloudantQueryObjcTests.m
//  CloudantQueryObjcTests
//
//  Created by Michael Rhodes on 09/27/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import <CloudantSync.h>
#import <CDTQIndexManager.h>
#import <CDTQIndexUpdater.h>
#import <CDTQIndexCreator.h>
#import <CDTQResultSet.h>
#import <CDTQQueryExecutor.h>

SpecBegin(CDTQIndexManager)

    describe(@"deletes", ^{

        __block NSString *factoryPath;
        __block CDTDatastoreManager *factory;
        __block CDTDatastore *ds;
        __block CDTQIndexManager *im;

        beforeEach(^{
            // Create a new CDTDatastoreFactory at a temp path

            NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
                stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
            const char *tempDirectoryTemplateCString =
                [tempDirectoryTemplate fileSystemRepresentation];
            char *tempDirectoryNameCString =
                (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
            strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

            char *result = mkdtemp(tempDirectoryNameCString);
            expect(result).to.beTruthy();

            factoryPath = [[NSFileManager defaultManager]
                stringWithFileSystemRepresentation:tempDirectoryNameCString
                                            length:strlen(result)];
            free(tempDirectoryNameCString);

            NSError *error;
            factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];

            ds = [factory datastoreNamed:@"test" error:nil];
            expect(ds).toNot.beNil();
            im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
            expect(im).toNot.beNil();
        });

        afterEach(^{
            // Delete the databases we used

            factory = nil;
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
        });

        it(@"empty index", ^{

            [im ensureIndexed:@[ @"name", @"address" ] withName:@"basic"];
            expect([im listIndexes][@"basic"]).toNot.beNil();

            [im deleteIndexNamed:@"basic"];
            expect([im listIndexes][@"basic"]).to.beNil();

        });

        it(@"the right empty index", ^{

            [im ensureIndexed:@[ @"name", @"address" ] withName:@"basic"];
            [im ensureIndexed:@[ @"name", @"age" ] withName:@"basic2"];
            [im ensureIndexed:@[ @"name" ] withName:@"basic3"];
            expect([im listIndexes][@"basic"]).toNot.beNil();

            [im deleteIndexNamed:@"basic2"];
            expect([im listIndexes][@"basic"]).toNot.beNil();
            expect([im listIndexes][@"basic2"]).to.beNil();
            expect([im listIndexes][@"basic3"]).toNot.beNil();

        });

        it(@"non-empty index", ^{

            CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            [im ensureIndexed:@[ @"name", @"address" ] withName:@"basic"];
            expect([im listIndexes][@"basic"]).toNot.beNil();

            [im deleteIndexNamed:@"basic"];
            expect([im listIndexes][@"basic"]).to.beNil();

        });

        it(@"the right non-empty index", ^{

            CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            rev.body = @{
                @"name" : @"mike",
                @"age" : @12,
                @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
            };
            [ds createDocumentFromRevision:rev error:nil];

            [im ensureIndexed:@[ @"name", @"address" ] withName:@"basic"];
            [im ensureIndexed:@[ @"name", @"age" ] withName:@"basic2"];
            [im ensureIndexed:@[ @"name" ] withName:@"basic3"];
            expect([im listIndexes][@"basic"]).toNot.beNil();

            [im deleteIndexNamed:@"basic2"];
            expect([im listIndexes][@"basic"]).toNot.beNil();
            expect([im listIndexes][@"basic2"]).to.beNil();
            expect([im listIndexes][@"basic3"]).toNot.beNil();

        });

    });

SpecEnd
