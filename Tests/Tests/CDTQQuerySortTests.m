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

SpecBegin(CDTQQueryExecutorSorting)

    describe(@"cloudant query", ^{

        __block NSString *factoryPath;
        __block CDTDatastoreManager *factory;

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
        });

        afterEach(^{
            // Delete the databases we used

            factory = nil;
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
        });

        describe(@"when sorting", ^{

            __block CDTDatastore *ds;
            __block CDTQIndexManager *im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @12,
                    @"pet" : @[ @"cat", @"dog" ],
                    @"same" : @"all"
                };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred34";
                rev.body = @{
                    @"name" : @"fred",
                    @"age" : @34,
                    @"pet" : @"parrot",
                    @"same" : @"all"
                };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred11";
                rev.body = @{ @"name" : @"fred", @"age" : @11, @"pet" : @"fish", @"same" : @"all" };
                [ds createDocumentFromRevision:rev error:nil];

                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"name", @"pet", @"age", @"same" ] withName:@"pet"])
                    .toNot.beNil();
            });

            it(@"sorts on name", ^{
                NSDictionary *query = @{ @"same" : @"all" };
                NSArray *order = @[ @{ @"name" : @"asc" } ];
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:nil sort:order];
                expect(result.documentIds).to.equal(@[ @"fred11", @"fred34", @"mike12" ]);
            });

            it(@"sorts on name, age", ^{
                NSDictionary *query = @{ @"same" : @"all" };
                NSArray *order = @[ @{ @"name" : @"asc" }, @{ @"age" : @"desc" } ];
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:nil sort:order];
                expect(result.documentIds).to.equal(@[ @"fred34", @"fred11", @"mike12" ]);
            });

            it(@"sorts on array field", ^{
                NSDictionary *query = @{ @"same" : @"all" };
                NSArray *order = @[ @{ @"pet" : @"asc" } ];
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:nil sort:order];
                expect(result.documentIds).to.equal(@[ @"mike12", @"fred11", @"fred34" ]);
            });

            it(@"returns nil using not asc/desc", ^{
                NSDictionary *query = @{ @"same" : @"all" };
                NSArray *order = @[ @{ @"name" : @"blah" }, @{ @"age" : @"desc" } ];
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:nil sort:order];
                expect(result).to.beNil();
            });

            it(@"returns nil using too many clauses", ^{
                NSDictionary *query = @{ @"same" : @"all" };
                NSArray *order = @[ @{ @"name" : @"asc", @"age" : @"desc" } ];
                CDTQResultSet *result =
                    [im find:query skip:0 limit:NSUIntegerMax fields:nil sort:order];
                expect(result).to.beNil();
            });

        });

        describe(@"when generating ordering SQL", ^{

            __block NSDictionary *indexes = @{
                @"a" :
                    @{@"name" : @"a", @"type" : @"json", @"fields" : @[ @"name", @"age", @"pet" ]},
                @"b" : @{@"name" : @"b", @"type" : @"json", @"fields" : @[ @"x", @"y", @"z" ]},
            };

            __block NSSet *smallDocIdSet = [NSSet setWithArray:@[ @"mike", @"john" ]];
            __block NSMutableSet *largeDocIdSet;

            beforeAll(^{
                largeDocIdSet = [NSMutableSet set];
                for (int i = 0; i < 501; i++) {  // 500 max id set for placeholders
                    [largeDocIdSet addObject:[NSString stringWithFormat:@"doc-%d", i]];
                }
            });

            context(@"two doc IDs", ^{

                context(@"for single field", ^{

                    it(@"asc", ^{
                        NSArray *order = @[ @{ @"name" : @"asc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_a "
                                        @"WHERE _id IN (?, ?) ORDER BY \"name\" ASC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal([smallDocIdSet allObjects]);
                    });

                    it(@"desc", ^{
                        NSArray *order = @[ @{ @"y" : @"desc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b "
                                        @"WHERE _id IN (?, ?) ORDER BY \"y\" DESC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal([smallDocIdSet allObjects]);
                    });

                });

                context(@"for multiple fields", ^{

                    it(@"asc", ^{
                        NSArray *order = @[ @{ @"y" : @"asc" }, @{ @"x" : @"asc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b "
                                        @"WHERE _id IN (?, ?) ORDER BY \"y\" ASC, \"x\" ASC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal([smallDocIdSet allObjects]);
                    });

                    it(@"desc", ^{
                        NSArray *order = @[ @{ @"y" : @"desc" }, @{ @"x" : @"desc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b "
                                        @"WHERE _id IN (?, ?) ORDER BY \"y\" DESC, \"x\" DESC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal([smallDocIdSet allObjects]);
                    });

                    it(@"mixed", ^{
                        NSArray *order = @[ @{ @"y" : @"desc" }, @{ @"x" : @"asc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b "
                                        @"WHERE _id IN (?, ?) ORDER BY \"y\" DESC, \"x\" ASC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal([smallDocIdSet allObjects]);
                    });

                });

            });

            context(@"501 doc IDs", ^{

                context(@"for single field", ^{

                    it(@"asc", ^{
                        NSArray *order = @[ @{ @"name" : @"asc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:largeDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_a  "
                                        @"ORDER BY \"name\" ASC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal(@[]);
                    });

                    it(@"desc", ^{
                        NSArray *order = @[ @{ @"y" : @"desc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:largeDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b  "
                                        @"ORDER BY \"y\" DESC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal(@[]);
                    });

                });

                context(@"for multiple fields", ^{

                    it(@"asc", ^{
                        NSArray *order = @[ @{ @"y" : @"asc" }, @{ @"x" : @"asc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:largeDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b  "
                                        @"ORDER BY \"y\" ASC, \"x\" ASC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal(@[]);
                    });

                    it(@"desc", ^{
                        NSArray *order = @[ @{ @"y" : @"desc" }, @{ @"x" : @"desc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:largeDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b  "
                                        @"ORDER BY \"y\" DESC, \"x\" DESC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal(@[]);
                    });

                    it(@"mixed", ^{
                        NSArray *order = @[ @{ @"y" : @"desc" }, @{ @"x" : @"asc" } ];
                        CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:largeDocIdSet
                                                                   usingOrder:order
                                                                      indexes:indexes];

                        NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b  "
                                        @"ORDER BY \"y\" DESC, \"x\" ASC;";
                        expect(parts.sqlWithPlaceholders).to.equal(sql);
                        expect(parts.placeholderValues).to.equal(@[]);
                    });

                });

            });

            it(@"fails when unindexed field", ^{
                NSArray *order = @[ @{ @"apples" : @"asc" } ];
                CDTQSqlParts *parts =
                    [CDTQQueryExecutor sqlToSortIds:smallDocIdSet usingOrder:order indexes:indexes];
                expect(parts).to.beNil();
            });

            it(@"fails when fields not in single index", ^{
                NSArray *order = @[ @{ @"x" : @"asc" }, @{ @"age" : @"asc" } ];
                CDTQSqlParts *parts =
                    [CDTQQueryExecutor sqlToSortIds:smallDocIdSet usingOrder:order indexes:indexes];
                expect(parts).to.beNil();
            });

            it(@"returns nil when no order", ^{
                CDTQSqlParts *parts;
                parts =
                    [CDTQQueryExecutor sqlToSortIds:smallDocIdSet usingOrder:@[] indexes:indexes];
                expect(parts).to.beNil();
                parts =
                    [CDTQQueryExecutor sqlToSortIds:smallDocIdSet usingOrder:nil indexes:indexes];
                expect(parts).to.beNil();
            });

            it(@"returns nil when no indexes", ^{
                CDTQSqlParts *parts;
                NSArray *order = @[ @{ @"y" : @"desc" } ];
                parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet usingOrder:order indexes:@{}];
                expect(parts).to.beNil();
                parts = [CDTQQueryExecutor sqlToSortIds:smallDocIdSet usingOrder:order indexes:nil];
                expect(parts).to.beNil();
            });

        });

        /*
         xdescribe(@"when generating ordering SQL for doc id set", ^{

         __block NSDictionary *indexes = @{@"a": @{@"name": @"a",
         @"type": @"json",
         @"fields": @[@"name", @"age", @"pet"]},
         @"b": @{@"name": @"b",
         @"type": @"json",
         @"fields": @[@"x", @"y", @"z"]},
         };
         __block NSArray *ids = @[@"a", @"b", @"c", @"d"];

         context(@"for single field", ^{

         it (@"asc", ^{
         NSArray *order = @[ @{ @"name": @"asc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];

         NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_a ORDER BY \"name\"
         ASC;";
         expect(parts.sqlWithPlaceholders).to.equal(sql);
         expect(parts.placeholderValues).to.equal(@[]);
         });

         it (@"desc", ^{
         NSArray *order = @[ @{ @"y": @"desc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];

         NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b ORDER BY \"y\"
         DESC;";
         expect(parts.sqlWithPlaceholders).to.equal(sql);
         expect(parts.placeholderValues).to.equal(@[]);
         });

         });

         context(@"for multiple fields", ^{


         it (@"asc", ^{
         NSArray *order = @[ @{ @"y": @"asc" }, @{ @"x": @"asc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];

         NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b ORDER BY \"y\"
         ASC, \"x\" ASC;";
         expect(parts.sqlWithPlaceholders).to.equal(sql);
         expect(parts.placeholderValues).to.equal(@[]);
         });

         it (@"desc", ^{
         NSArray *order = @[ @{ @"y": @"desc" }, @{ @"x": @"desc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];

         NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b ORDER BY \"y\"
         DESC, \"x\" DESC;";
         expect(parts.sqlWithPlaceholders).to.equal(sql);
         expect(parts.placeholderValues).to.equal(@[]);
         });

         it (@"mixed", ^{
         NSArray *order = @[ @{ @"y": @"desc" }, @{ @"x": @"asc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];

         NSString *sql = @"SELECT DISTINCT _id FROM _t_cloudant_sync_query_index_b ORDER BY \"y\"
         DESC, \"x\" ASC;";
         expect(parts.sqlWithPlaceholders).to.equal(sql);
         expect(parts.placeholderValues).to.equal(@[]);
         });

         });

         it(@"fails for invalid direction", ^{
         NSArray *order = @[ @{ @"name": @"blah" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];
         expect(parts).to.beNil();

         });

         it(@"fails when unindexed field", ^{
         NSArray *order = @[ @{ @"apples": @"asc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];
         expect(parts).to.beNil();
         });

         it(@"fails when fields not in single index", ^{
         NSArray *order = @[ @{ @"x": @"asc" }, @{ @"age": @"asc" } ];
         CDTQSqlParts *parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:indexes];
         expect(parts).to.beNil();
         });

         it(@"returns nil when no doc ids", ^{
         CDTQSqlParts *parts;
         NSArray *order = @[ @{ @"y": @"desc" } ];
         parts = [CDTQQueryExecutor sqlToSortIds:@[]
         usingOrder:order
         usingIndexes:indexes];
         expect(parts).to.beNil();
         parts = [CDTQQueryExecutor sqlToSortIds:nil
         usingOrder:order
         usingIndexes:indexes];
         expect(parts).to.beNil();
         });

         it(@"returns nil when no order", ^{
         CDTQSqlParts *parts;
         parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:@[]
         usingIndexes:indexes];
         expect(parts).to.beNil();
         parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:nil
         usingIndexes:indexes];
         expect(parts).to.beNil();
         });

         it(@"returns nil when no indexes", ^{
         CDTQSqlParts *parts;
         NSArray *order = @[ @{ @"y": @"desc" } ];
         parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:@{}];
         expect(parts).to.beNil();
         parts = [CDTQQueryExecutor sqlToSortIds:ids
         usingOrder:order
         usingIndexes:nil];
         expect(parts).to.beNil();
         });

         });
         */
    });

SpecEnd
