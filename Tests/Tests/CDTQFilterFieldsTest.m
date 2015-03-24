//
//  CDTQFilterFieldsTest.m
//  CloudantQueryObjc
//
//  Created by Rhys Short on 16/10/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Specta.h"
#import "Expecta.h"
#import <CloudantSync.h>
#import <CDTQIndexManager.h>
#import <CDTQIndexUpdater.h>
#import <CDTQIndexCreator.h>
#import <CDTQResultSet.h>
#import <CDTQQueryExecutor.h>

SpecBegin(CDTQFilterFieldsTest)

    describe(@"When filtering fields on find ", ^{

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

        afterEach(^{
            // Delete the databases we used
            factory = nil;
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
        });

        it(@"returns only field specified in fields param in the document body", ^{
            NSDictionary *query = @{ @"name" : @"mike" };
            CDTQResultSet *result =
                [im find:query skip:0 limit:NSUIntegerMax fields:@[ @"name" ] sort:nil];
            expect(result).toNot.beNil();

            [result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                expect([rev.body count]).to.equal(1);
                expect([rev.body objectForKey:@"name"]).to.equal(@"mike");
            }];
        });

        it(@"returns all fields when fields array is empty", ^{
            NSDictionary *query = @{ @"name" : @"mike" };
            CDTQResultSet *result = [im find:query skip:0 limit:NSUIntegerMax fields:@[] sort:nil];
            expect(result).toNot.beNil();

            [result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                expect([rev.body count]).to.equal(3);
                expect([rev.body objectForKey:@"name"]).toNot.beNil();
                expect([rev.body objectForKey:@"pet"]).toNot.beNil();
                expect([rev.body objectForKey:@"age"]).toNot.beNil();
            }];
        });

        it(@"returns all fields when fields array is nil", ^{
            NSDictionary *query = @{ @"name" : @"mike" };
            CDTQResultSet *result = [im find:query skip:0 limit:NSUIntegerMax fields:@[] sort:nil];
            expect(result).toNot.beNil();

            [result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                expect([rev.body count]).to.equal(3);
                expect([rev.body objectForKey:@"name"]).toNot.beNil();
                expect([rev.body objectForKey:@"pet"]).toNot.beNil();
                expect([rev.body objectForKey:@"age"]).toNot.beNil();
            }];
        });

        it(@"returns nil when fields array contains a type other than NSString", ^{
            NSDictionary *query = @{ @"name" : @"mike" };
            CDTQResultSet *result =
                [im find:query skip:0 limit:NSUIntegerMax fields:@[ @{} ] sort:nil];
            expect(result).to.beNil();
        });

        it(@"returns nil when using dotted notation", ^{
            NSDictionary *query = @{ @"name" : @"mike" };
            CDTQResultSet *result =
                [im find:query skip:0 limit:NSUIntegerMax fields:@[ @"name.blah" ] sort:nil];
            expect(result).to.beNil();
        });

        it(@"returns only pet and name fields in a document revision, when they are specfied in "
           @"fields",
           ^{
            NSDictionary *query = @{ @"name" : @"mike" };
            CDTQResultSet *result =
                [im find:query skip:0 limit:NSUIntegerMax fields:@[ @"name", @"pet" ] sort:nil];
            expect(result).toNot.beNil();

            [result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                expect([rev.body count]).to.equal(2);
                expect([rev.body objectForKey:@"name"]).toNot.beNil();
                expect([rev.body objectForKey:@"pet"]).toNot.beNil();
            }];
        });

        context(@"mutableCopy of projected doc", ^{

            it(@"returns full doc", ^{
                NSDictionary *query = @{ @"name" : @"mike", @"age" : @12 };
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:@[ @"name" ] sort:nil];
                expect(result.documentIds.count).to.equal(1);

                [result
                    enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                        expect(rev.body.count).to.equal(1);
                        expect(rev.body[@"name"]).to.equal(@"mike");

                        CDTMutableDocumentRevision *mutable = [rev mutableCopy];
                        expect(mutable.body.count).to.equal(3);
                        expect(mutable.body[@"name"]).to.equal(@"mike");
                        expect(mutable.body[@"age"]).to.equal(@12);
                        expect(mutable.body[@"pet"]).to.equal(@"cat");
                    }];
            });

            it(@"returns nil when doc updated", ^{
                NSDictionary *query = @{ @"name" : @"mike", @"age" : @12 };
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:@[ @"name" ] sort:nil];
                expect(result.documentIds.count).to.equal(1);

                [result
                    enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                        expect(rev.body.count).to.equal(1);
                        expect(rev.body[@"name"]).to.equal(@"mike");

                        CDTDocumentRevision *original = [ds getDocumentWithId:rev.docId error:nil];
                        CDTMutableDocumentRevision *update = [original mutableCopy];
                        update.body[@"name"] = @"charles";
                        expect([ds updateDocumentFromRevision:update error:nil]).toNot.beNil();

                        CDTMutableDocumentRevision *mutable = [rev mutableCopy];
                        expect(mutable).to.beNil();
                    }];
            });

            it(@"returns nil when doc deleted", ^{
                NSDictionary *query = @{ @"name" : @"mike", @"age" : @12 };
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:@[ @"name" ] sort:nil];
                expect(result.documentIds.count).to.equal(1);

                [result
                    enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger i, BOOL *s) {
                        expect(rev.body.count).to.equal(1);
                        expect(rev.body[@"name"]).to.equal(@"mike");

                        expect([ds deleteDocumentFromRevision:rev error:nil]).toNot.beNil();

                        CDTMutableDocumentRevision *mutable = [rev mutableCopy];
                        expect(mutable).to.beNil();
                    }];
            });

        });

    });

SpecEnd