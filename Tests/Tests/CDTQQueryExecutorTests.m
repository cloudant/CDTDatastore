//
//  CloudantQueryObjcTests.m
//  CloudantQueryObjcTests
//
//  Created by Michael Rhodes on 09/27/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import "CDTQMatcherIndexManager.h"
#import "CDTQSQLOnlyIndexManager.h"

#import <CloudantSync.h>
#import <CDTQIndexManager.h>
#import <CDTQIndexUpdater.h>
#import <CDTQIndexCreator.h>
#import <CDTQResultSet.h>
#import <CDTQQueryExecutor.h>
#import "Matchers/CDTQContainsAllElementsMatcher.h"
#import "Matchers/CDTQEitherMatcher.h"

SharedExamplesBegin(QueryExecution)

    // The aim is to make sure that the post hoc matcher class behaves the
    // same as the SQL query engine.
    //
    // For this, we test the entire pipeline using the usual CDTQQueryExectutor class. This does
    // both SQL and post hoc matching. Then we have a sub-class of CDTQQueryExecutor which skips
    // the SQL querying and just runs all documents through the CDTQUnindexedMatcher.
    sharedExamplesFor(@"queries with covering indexes", ^(NSDictionary* data) {
        // Pull the class to test out of the data object
        Class imClass = data[@"index_manager_class"];

        __block NSString* factoryPath;
        __block CDTDatastoreManager* factory;

        beforeEach(^{
            // Create a new CDTDatastoreFactory at a temp path

            NSString* tempDirectoryTemplate = [NSTemporaryDirectory()
                stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
            const char* tempDirectoryTemplateCString =
                [tempDirectoryTemplate fileSystemRepresentation];
            char* tempDirectoryNameCString =
                (char*)malloc(strlen(tempDirectoryTemplateCString) + 1);
            strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

            char* result = mkdtemp(tempDirectoryNameCString);
            expect(result).to.beTruthy();

            factoryPath = [[NSFileManager defaultManager]
                stringWithFileSystemRepresentation:tempDirectoryNameCString
                                            length:strlen(result)];
            free(tempDirectoryNameCString);

            NSError* error;
            factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
        });

        afterEach(^{
            // Delete the databases we used

            factory = nil;
            NSError* error;
            [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
        });

        describe(@"when executing queries", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

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

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"name", @"age" ] withName:@"basic"]).toNot.beNil();
                expect([im ensureIndexed:@[ @"name", @"pet" ] withName:@"pet"]).toNot.beNil();
            });

            it(@"returns nil for no query", ^{
                CDTQResultSet* result = [im find:nil];
                expect(result).to.beNil();
            });

            it(@"returns all docs for empty query", ^{
                NSDictionary* query = @{};
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(5);
            });

            it(@"can query over one string field", ^{
                NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
            });

            it(@"can query over one number field", ^{
                NSDictionary* query = @{ @"age" : @{@"$eq" : @12} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(2);
            });

            it(@"can query over two string fields", ^{
                NSDictionary* query = @{
                    @"name" : @{@"$eq" : @"mike"},
                    @"pet" : @{@"$eq" : @"cat"}
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(2);
            });

            it(@"can query over two mixed fields", ^{
                NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"}, @"age" : @{@"$eq" : @12} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });

            it(@"returns no results when query is for one predicate without match", ^{
                NSDictionary* query = @{ @"name" : @{@"$eq" : @"bill"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });

            it(@"returns no results when query is for two predicates, one without matches", ^{
                NSDictionary* query = @{ @"name" : @{@"$eq" : @"bill"}, @"age" : @{@"$eq" : @12} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });

            it(@"returns no results when query is for two predicates, both without matches", ^{
                NSDictionary* query = @{ @"name" : @{@"$eq" : @"bill"}, @"age" : @{@"$eq" : @17} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });

            context(@"when limiting and offsetting results", ^{

                it(@"returns all for skip = limit = 0", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results = [im find:query skip:0 limit:0 fields:nil sort:nil];
                    expect(results.documentIds.count).to.equal(3);
                });

                it(@"limits query results", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results = [im find:query skip:0 limit:1 fields:nil sort:nil];
                    expect(results.documentIds.count).to.equal(1);
                });

                it(@"limits query and offsets starting point", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* offsetResults =
                        [im find:query skip:1 limit:1 fields:nil sort:nil];
                    CDTQResultSet* results = [im find:query skip:0 limit:2 fields:nil sort:nil];

                    expect(results.documentIds.count).to.equal(2);
                    expect(results.documentIds[1]).to.equal(offsetResults.documentIds[0]);
                });

                it(@"disables limit for 0", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results = [im find:query skip:1 limit:0 fields:nil sort:nil];

                    expect([results.documentIds count]).to.equal(2);
                });

                it(@"returns an array with results when limit is over array bounds", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results = [im find:query skip:0 limit:4 fields:nil sort:nil];

                    expect([results.documentIds count]).to.equal(3);
                });

                it(@"returns all results with very large limit", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results = [im find:query skip:0 limit:1000 fields:nil sort:nil];

                    expect([results.documentIds count]).to.equal(3);
                });

                it(@"returns an array with no results when range is out of bounds", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results = [im find:query skip:4 limit:4 fields:nil sort:nil];

                    expect([results.documentIds count]).to.equal(0);

                });

                it(@"returns appropriate results skip and large limit used", ^{
                    NSDictionary* query = @{ @"name" : @{@"$eq" : @"mike"} };
                    CDTQResultSet* results =
                        [im find:query skip:1000 limit:1000 fields:nil sort:nil];

                    expect([results.documentIds count]).to.equal(0);
                });
            });

            // TODO fill in when separate validation class written
            xdescribe(@"when using unsupported operator", ^{
                it(@"fails", ^{
                    NSDictionary* query = @{ @"age" : @{@"$blah" : @12} };
                    CDTQResultSet* result = [im find:query];
                    expect(result).to.beNil();
                });
            });

            describe(@"when using $gt operator", ^{
                it(@"works used alone", ^{
                    NSDictionary* query = @{ @"age" : @{@"$gt" : @12} };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(3);
                });

                it(@"works used with other predicates", ^{
                    NSDictionary* query = @{
                        @"name" : @{@"$eq" : @"mike"},
                        @"age" : @{@"$gt" : @12}
                    };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(2);
                });

                it(@"can compare string values", ^{
                    NSDictionary* query = @{ @"name" : @{@"$gt" : @"fred"} };
                    CDTQResultSet* result = [im find:query];
                    expect(result).toNot.beNil();

                    [result enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i,
                                                         BOOL* s) {
                        expect([rev.body count]).to.beInTheRangeOf(@2, @3);
                        expect(rev.body[@"name"]).to.equal(@"mike");
                    }];
                });

                it(@"can compare string values as part of an $and query", ^{
                    NSDictionary* query = @{ @"name" : @{@"$gt" : @"fred"}, @"age" : @34 };
                    CDTQResultSet* result = [im find:query];
                    expect(result).toNot.beNil();

                    [result enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i,
                                                         BOOL* s) {
                        expect([rev.body count]).to.beInTheRangeOf(@2, @3);
                        expect(rev.body[@"name"]).to.equal(@"mike");
                        expect(rev.body[@"age"]).to.equal(34);
                    }];
                });
            });

            describe(@"when using $gte operator", ^{
                it(@"works used alone", ^{
                    NSDictionary* query = @{ @"age" : @{@"$gte" : @12} };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(5);
                });

                it(@"works used with other predicates", ^{
                    NSDictionary* query = @{
                        @"name" : @{@"$eq" : @"mike"},
                        @"age" : @{@"$gte" : @12}
                    };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(3);
                });
            });

            describe(@"when using $lt operator", ^{
                it(@"works used alone", ^{
                    NSDictionary* query = @{ @"age" : @{@"$lt" : @12} };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(0);
                });

                it(@"works used with other predicates", ^{
                    NSDictionary* query = @{
                        @"name" : @{@"$eq" : @"mike"},
                        @"age" : @{@"$lt" : @12}
                    };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(0);
                });

                it(@"can compare string values", ^{
                    NSDictionary* query = @{ @"name" : @{@"$lt" : @"mike"} };
                    CDTQResultSet* result = [im find:query];
                    expect(result).toNot.beNil();

                    [result enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i,
                                                         BOOL* s) {
                        expect([rev.body count]).to.beInTheRangeOf(@2, @3);
                        expect(rev.body[@"name"]).to.equal(@"fred");
                    }];
                });

                it(@"can compare string values as part of an $and query", ^{
                    NSDictionary* query = @{ @"name" : @{@"$lt" : @"mike"}, @"age" : @12 };
                    CDTQResultSet* result = [im find:query];
                    expect(result).toNot.beNil();

                    [result enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i,
                                                         BOOL* s) {
                        expect([rev.body count]).to.beInTheRangeOf(@2, @3);
                        expect(rev.body[@"name"]).to.equal(@"fred");
                        expect(rev.body[@"age"]).to.equal(12);
                    }];
                });
            });

            describe(@"when using $lte operator", ^{
                it(@"works used alone", ^{
                    NSDictionary* query = @{ @"age" : @{@"$lte" : @12} };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(2);
                });

                it(@"works used with other predicates", ^{
                    NSDictionary* query = @{
                        @"name" : @{@"$eq" : @"mike"},
                        @"age" : @{@"$lte" : @12}
                    };
                    CDTQResultSet* result = [im find:query];
                    expect(result.documentIds.count).to.equal(1);
                });
            });
        });

        describe(@"when using dotted notation", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @12,
                    @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
                };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike23";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @23,
                    @"pet" : @{@"species" : @"cat", @"name" : @{@"first" : @"mike"}}
                };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @34,
                    @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
                };
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

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"age", @"pet.name", @"pet.species" ] withName:@"pet"])
                    .toNot.beNil();
                expect([im ensureIndexed:@[ @"age", @"pet.name.first" ] withName:@"firstname"])
                    .toNot.beNil();
            });

            it(@"query with two level dotted no results", ^{
                NSDictionary* query = @{
                    @"pet.name" : @{@"$eq" : @"fred"},
                    @"age" : @{@"$eq" : @12}
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds).to.equal(@[]);
            });

            it(@"query with two level dotted one result", ^{
                NSDictionary* query = @{
                    @"pet.name" : @{@"$eq" : @"mike"},
                    @"age" : @{@"$eq" : @12}
                };
                CDTQResultSet* result = [im find:query];
                expect(result.documentIds).to.equal(@[ @"mike12" ]);
            });

            it(@"query with two level dotted multiple results", ^{
                NSDictionary* query = @{ @"pet.species" : @{@"$eq" : @"cat"} };
                CDTQResultSet* result = [im find:query];
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.beSupersetOf(@[ @"mike12", @"mike23", @"mike34" ]);
            });

            it(@"query with three level dotted", ^{
                NSDictionary* query = @{ @"pet.name.first" : @{@"$eq" : @"mike"} };
                CDTQResultSet* result = [im find:query];
                expect(result.documentIds).to.equal(@[ @"mike23" ]);
            });
        });

        describe(@"when using non-ascii text", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike72";
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"اسم34";
                rev.body = @{ @"name" : @"اسم", @"age" : @34, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred12";
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fredarabic";
                rev.body = @{ @"اسم" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"freddatatype";
                rev.body = @{ @"@datatype" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();
            });

            it(@"can query for values non-ascii", ^{
                expect([im ensureIndexed:@[ @"name" ] withName:@"nonascii"]).toNot.beNil();

                NSDictionary* query = @{ @"name" : @{@"$eq" : @"اسم"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });

            it(@"can use fields with odd names", ^{
                expect([im ensureIndexed:@[ @"اسم", @"@datatype", @"age" ] withName:@"nonascii"])
                    .toNot.beNil();

                NSDictionary* query = @{ @"اسم" : @{@"$eq" : @"fred"}, @"age" : @{@"$eq" : @12} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);

                query = @{ @"@datatype" : @{@"$eq" : @"fred"}, @"age" : @{@"$eq" : @12} };
                result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });
        });

        describe(@"when using OR queries", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @12,
                    @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
                };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike23";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @23,
                    @"pet" : @{@"species" : @"cat", @"name" : @{@"first" : @"mike"}}
                };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @34,
                    @"pet" : @{@"species" : @"cat", @"name" : @"mike"}
                };
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

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"age", @"pet", @"name" ] withName:@"basic"])
                    .toNot.beNil();
                expect([im ensureIndexed:@[ @"age", @"pet.name", @"pet.species" ] withName:@"pet"])
                    .toNot.beNil();
                expect([im ensureIndexed:@[ @"age", @"pet.name.first" ] withName:@"firstname"])
                    .toNot.beNil();
            });

            it(@"supports using OR", ^{
                NSDictionary* query = @{ @"$or" : @[ @{@"name" : @"mike"}, @{@"pet" : @"cat"} ] };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(5);
            });

            it(@"supports using OR with specified operator", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"name" : @"mike"},        // 4
                        @{@"age" : @{@"$gt" : @30}}  // 1
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(5);
            });

            it(@"supports using OR in sub trees", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"name" : @"fred"},
                        @{@"$or" : @[ @{@"age" : @12}, @{@"pet" : @"cat"} ]}
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(4);
            });

            it(@"supports using OR with a single operand", ^{
                NSDictionary* query = @{ @"$or" : @[ @{@"name" : @"mike"} ] };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect([result.documentIds count]).to.equal(4);
            });
        });

        describe(@"when using nested queries", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike23";
                rev.body = @{ @"name" : @"mike", @"age" : @23, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"john72";
                rev.body = @{ @"name" : @"john", @"age" : @34, @"pet" : @"fish" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred34";
                rev.body = @{ @"name" : @"fred", @"age" : @43, @"pet" : @"snake" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred12";
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"age", @"pet", @"name" ] withName:@"basic"])
                    .toNot.beNil();
            });

            it(@"query with two levels", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"name" : @"mike"},  // 3
                        @{@"age" : @34},       // 1
                        @{
                           @"$and" : @[
                               @{@"name" : @"fred"},  // 1
                               @{@"pet" : @"snake"}
                           ]
                        }
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(5);
            });

            it(@"OR with sub OR", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"name" : @"mike"},  // 3
                        @{@"age" : @34},       // 1
                        @{
                           @"$or" : @[
                               @{@"name" : @"fred"},   // 2
                               @{@"pet" : @"hamster"}  // 0
                           ]
                        }
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(6);
            });

            it(@"AND with sub AND", ^{
                // No doc matches all these
                NSDictionary* query = @{
                    @"$and" : @[
                        @{@"name" : @"mike"},
                        @{@"age" : @34},
                        @{@"$and" : @[ @{@"name" : @"fred"}, @{@"pet" : @"snake"} ]}
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });

            it(@"OR with sub AND", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"name" : @"mike"},  // 3
                        @{@"age" : @34},       // 1
                        @{
                           @"$and" : @[
                               @{@"name" : @"fred"},  // 0
                               @{@"pet" : @"cat"}
                           ]
                        }
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(4);
            });

            it(@"AND with sub OR", ^{
                NSDictionary* query = @{
                    @"$and" : @[
                        @{@"name" : @"mike"},
                        @{@"age" : @34},
                        @{@"$or" : @[ @{@"name" : @"fred"}, @{@"pet" : @"dog"} ]}
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });

            it(@"AND with sub AND with a sub AND", ^{
                NSDictionary* query = @{
                    @"$and" : @[
                        @{@"name" : @"mike"},
                        @{@"age" : @{@"$gt" : @10}},
                        @{@"age" : @{@"$lt" : @30}},
                        @{
                           @"$and" : @[
                               @{@"$and" : @[ @{@"pet" : @"cat"} ]},
                               @{@"pet" : @{@"$gt" : @"ant"}}
                           ]
                        }
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });

            it(@"AND with sub AND with a sub AND", ^{
                NSDictionary* query = @{
                    @"$and" : @[
                        @{@"name" : @"mike"},
                        @{@"age" : @{@"$gt" : @10}},
                        @{@"age" : @{@"$lt" : @12}},
                        @{
                           @"$and" : @[
                               @{@"$and" : @[ @{@"pet" : @"cat"} ]},
                               @{@"pet" : @{@"$gt" : @"ant"}}
                           ]
                        }
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });

            it(@"AND with sub OR and sub AND", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"name" : @"mike"},  // 3
                        @{@"pet" : @"cat"},    // 1, but named mike
                        @{
                           @"$or" : @[
                               @{@"name" : @"mike"},  // 3
                               @{@"pet" : @"snake"}   // 1
                           ]
                        },
                        @{
                           @"$and" : @[
                               @{@"name" : @"mike"},  // 0
                               @{@"pet" : @"snake"}
                           ]
                        }
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(4);
            });
        });

        describe(@"_id is queryable", ^{
            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike23";
                rev.body = @{ @"name" : @"mike", @"age" : @23, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"age", @"pet", @"name" ] withName:@"basic"])
                    .toNot.beNil();
            });

            it(@"works as single clause", ^{
                NSDictionary* query = @{ @"_id" : @"mike12" };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });

            it(@"works with other clauses", ^{
                NSDictionary* query = @{ @"_id" : @"mike23", @"name" : @"mike" };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });
        });

        describe(@"_rev is queryable", ^{
            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;
            __block NSString* docRev;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike23";
                rev.body = @{ @"name" : @"mike", @"age" : @23, @"pet" : @"parrot" };
                CDTDocumentRevision* toRetrieve = [ds createDocumentFromRevision:rev error:nil];
                docRev = toRetrieve.revId;

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"age", @"pet", @"name" ] withName:@"basic"])
                    .toNot.beNil();
            });

            it(@"works as single clause", ^{
                NSDictionary* query = @{ @"_rev" : docRev };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });

            it(@"works with other clauses", ^{
                NSDictionary* query = @{ @"_rev" : docRev, @"name" : @"mike" };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
            });
        });

        describe(@"when using $not", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike72";
                rev.body = @{ @"name" : @"mike", @"age" : @67, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred34";
                rev.body = @{ @"name" : @"fred", @"age" : @34, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred12";
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"name", @"pet", @"age" ] withName:@"pet"])
                    .toNot.beNil();
            });

            it(@"can query over one string field", ^{
                NSDictionary* query = @{ @"name" : @{@"$not" : @{@"$eq" : @"mike"}} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(2);
            });

            it(@"can query over one int field", ^{
                NSDictionary* query = @{ @"age" : @{@"$not" : @{@"$gt" : @34}} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(4);
            });

            it(@"includes documents without field indexed", ^{
                NSDictionary* query = @{ @"pet" : @{@"$not" : @{@"$eq" : @"cat"}} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
            });

            it(@"works with AND compound operator", ^{
                NSDictionary* query = @{
                    @"$and" : @[
                        @{@"pet" : @{@"$not" : @{@"$eq" : @"cat"}}},
                        @{@"pet" : @{@"$not" : @{@"$eq" : @"dog"}}}
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(2);
            });

            it(@"works with AND compound operator, no results", ^{
                NSDictionary* query = @{
                    @"$and" : @[
                        @{@"pet" : @{@"$not" : @{@"$eq" : @"cat"}}},
                        @{@"pet" : @{@"$eq" : @"cat"}}
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });

            it(@"works with OR compond operator", ^{
                NSDictionary* query = @{
                    @"$or" : @[
                        @{@"pet" : @{@"$not" : @{@"$eq" : @"cat"}}},
                        @{@"pet" : @{@"$not" : @{@"$eq" : @"dog"}}}
                    ]
                };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(5);
            });
        });

        describe(@"when indexing array fields", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @[ @"cat", @"dog" ] };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred34";
                rev.body = @{ @"name" : @"fred", @"age" : @34, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike",
                              @"age" : @34,
                              @"pet" : @[ @"cat", @"dog", @"fish" ] };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"fred12";
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"john44";
                rev.body = @{ @"name" : @"john", @"age" : @44, @"pet" : @[ @"hamster", @"snake" ] };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"john22";
                rev.body = @{ @"name" : @"john", @"age" : @22, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"name", @"pet", @"age" ] withName:@"pet"])
                    .toNot.beNil();
            });

            it(@"finds documents with array", ^{
                NSDictionary* query = @{ @"pet" : @{@"$eq" : @"dog"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(2);
                expect(result.documentIds).to.containAllElements(@[ @"mike12", @"mike34" ]);
            });

            it(@"finds document without array", ^{
                NSDictionary* query = @{ @"pet" : @{@"$eq" : @"parrot"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
                expect(result.documentIds).to.containAllElements(@[ @"fred34" ]);
            });
            
            // Queries like { "pet" : "$eq" : "cat" } }
            //     and      { "pet" : { "$not" : { "$ne" : "cat" } } }
            // Should yield the same result set.  Evidenced in the next two tests.
            
            it(@"finds documents with and without array", ^{
                NSDictionary* query = @{ @"pet" : @{@"$eq" : @"cat"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"mike12",
                                                                    @"mike34",
                                                                    @"john22" ]);
            });
            
            it(@"finds documents with and without array while using $not..$ne", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$not" : @{@"$ne" : @"cat"} } };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"mike12",
                                                                    @"mike34",
                                                                    @"john22" ]);
            });
            
            // Queries like { "pet" : { "$not" : { "$eq" : "dog" } } }
            //     and      { "pet" : { "$ne" : "dog" } } }
            // Should yield the same result set.  Evidenced in the next two tests.

            it(@"works with $not", ^{
                NSDictionary* query = @{ @"pet" : @{@"$not" : @{@"$eq" : @"dog"}} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(4);
                expect(result.documentIds).to.containAllElements(@[ @"fred34",
                                                                    @"john44",
                                                                    @"john22",
                                                                    @"fred12" ]);
            });
            
            it(@"works with $ne", ^{
                NSDictionary* query = @{ @"pet" : @{@"$ne" : @"dog"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(4);
                expect(result.documentIds).to.containAllElements(@[ @"fred34",
                                                                    @"john44",
                                                                    @"john22",
                                                                    @"fred12" ]);
            });
            
            // The $gt and $lte operators are logically opposite.  Consequently querying
            // with those operators and for that matter $gte/$lt will yield result sets
            // that are logically opposite.  Whereas using $not..$gt will yield a result
            // set that consists of documents that do NOT satisfy the "greater than"
            // condition.  This can be a result set that differs from the logical
            // opposite as is evidenced in the following three tests.
            
            it(@"works with $gt", ^{
                NSDictionary* query = @{ @"pet" : @{@"$gt" : @"dog"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"fred34",
                                                                    @"john44",
                                                                    @"mike34" ]);
            });
            
            it(@"works with $lte", ^{
                NSDictionary* query = @{ @"pet" : @{@"$lte" : @"dog"} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"mike12",
                                                                    @"john22",
                                                                    @"mike34" ]);
            });
            
            it(@"works with $not..$gt", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$not" : @{@"$gt" : @"dog"} } };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"fred12",
                                                                    @"john22",
                                                                    @"mike12" ]);
            });
            
            it(@"can find documents with and without arrays using $not multiple times", ^{
                NSDictionary* query = @{ @"$and" :
                                             @[ @{ @"pet" : @{ @"$not" : @{@"$eq" : @"cat"} } },
                                                @{ @"pet" : @{ @"$not" : @{@"$eq" : @"dog"} } }
                                              ]
                                       };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"fred34",
                                                                    @"fred12",
                                                                    @"john44" ]);
            });
            
            // Arrays as part of the query is not yet supported.
            
            it(@"returns nil when using array in query", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$not" : @{@"$eq" : @[ @"dog" ] } } };
                CDTQResultSet* result = [im find:query];
                expect(result).to.beNil();
            });
            
        });

        describe(@"when using the $exists operator", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike72";
                rev.body = @{ @"name" : @"mike", @"age" : @67, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred34";
                rev.body = @{ @"name" : @"fred", @"age" : @34, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"fred12";
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                expect([im ensureIndexed:@[ @"name", @"pet", @"age" ] withName:@"pet"])
                    .toNot.beNil();
            });

            it(@"returns records where the field does not exist", ^{
                NSDictionary* query = @{ @"pet" : @{@"$exists" : @NO} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect([result.documentIds count]).to.equal(1);
            });

            it(@"returns records where the field does exist", ^{
                NSDictionary* query = @{ @"pet" : @{@"$exists" : @YES} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect([result.documentIds count]).to.equal(4);
            });

            it(@"returns record where the field exists using $not clause", ^{
                NSDictionary* query = @{ @"pet" : @{@"$not" : @{@"$exists" : @NO}} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect([result.documentIds count]).to.equal(4);
            });

            it(@"returns record where the field exists using $not clause", ^{
                NSDictionary* query = @{ @"pet" : @{@"$not" : @{@"$exists" : @YES}} };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect([result.documentIds count]).to.equal(1);
            });
        });
        
        describe(@"when using the $in operator", ^{
            
            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;
            
            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();
                
                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];
                
                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @[ @"cat", @"dog" ] };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"fred34";
                rev.body = @{ @"name" : @"fred", @"age" : @34, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike",
                              @"age" : @34,
                              @"pet" : @[ @"cat", @"dog", @"fish" ] };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"fred12";
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"john44";
                rev.body = @{ @"name" : @"john", @"age" : @44, @"pet" : @[ @"hamster", @"snake" ] };
                [ds createDocumentFromRevision:rev error:nil];
                
                rev.docId = @"john22";
                rev.body = @{ @"name" : @"john", @"age" : @22, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];
                
                im = [imClass managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();
                
                expect([im ensureIndexed:@[ @"name", @"pet", @"age" ] withName:@"pet"])
                .toNot.beNil();
            });
            
            it(@"can find documents with arrays using $in", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$in" : @[ @"fish", @"hamster" ] } };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(2);
                expect(result.documentIds).to.containAllElements(@[ @"mike34", @"john44" ]);
            });
            
            it(@"can find documents without arrays using $in", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$in" : @[ @"parrot", @"turtle" ] } };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(1);
                expect(result.documentIds).to.containAllElements(@[ @"fred34" ]);
            });
            
            it(@"can find documents with and without arrays using $in", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$in" : @[ @"cat", @"dog" ] } };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"mike12",
                                                                    @"mike34",
                                                                    @"john22" ]);
            });
            
            it(@"returns an empty result set when no matches found using $in", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$in" : @[ @"turtle", @"pig" ] } };
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(0);
            });
            
            it(@"can find documents using $not $in", ^{
                NSDictionary* query = @{ @"pet" : @{ @"$not" : @{ @"$in" : @[ @"cat", @"dog" ] }}};
                CDTQResultSet* result = [im find:query];
                expect(result).toNot.beNil();
                expect(result.documentIds.count).to.equal(3);
                expect(result.documentIds).to.containAllElements(@[ @"fred12",
                                                                    @"fred34",
                                                                    @"john44" ]);
            });
        });

        describe(@"stopping enumeration", ^{

            __block CDTDatastore* ds;
            __block CDTQIndexManager* im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

                rev.docId = @"mike12";
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike34";
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
                [ds createDocumentFromRevision:rev error:nil];

                rev.docId = @"mike72";
                rev.body = @{ @"name" : @"mike", @"age" : @67, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                [im ensureIndexed:@[ @"_id" ] withName:@"id"];
            });

            it(@"enumerates all results when stop not set", ^{
                NSDictionary* query = @{};
                CDTQResultSet* result = [im find:query];
                __block NSUInteger count = 0;

                [result enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i,
                                                     BOOL* s) { count++; }];

                expect(count).to.equal(3);
            });

            it(@"enumerates all results when set set to NO", ^{
                NSDictionary* query = @{};
                CDTQResultSet* result = [im find:query];
                __block NSUInteger count = 0;

                [result
                    enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i, BOOL* s) {
                        count++;
                        *s = NO;
                    }];

                expect(count).to.equal(3);
            });

            it(@"stops when stop is set to YES", ^{
                NSDictionary* query = @{};
                CDTQResultSet* result = [im find:query];
                __block NSUInteger count = 0;

                [result
                    enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i, BOOL* s) {
                        count++;
                        if (count == 2) {
                            *s = NO;
                        }
                    }];

                expect(count).to.equal(3);
            });

            it(@"stops when querying lots of docs", ^{

                CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];
                [im ensureIndexed:@[ @"large_field" ] withName:@"large"];

                for (int i = 0; i < 100; i++) {
                    rev.body = @{ @"large_field" : @"cat" };
                    [ds createDocumentFromRevision:rev error:nil];
                }

                NSDictionary* query = @{ @"large_field" : @{@"$eq" : @"cat"} };
                CDTQResultSet* result = [im find:query skip:0 limit:0 fields:nil sort:nil];
                __block NSUInteger count = 0;

                [result
                    enumerateObjectsUsingBlock:^(CDTDocumentRevision* rev, NSUInteger i, BOOL* s) {
                        count++;
                        if (count == 20) {
                            *s = YES;
                        }
                    }];

                expect(count).to.equal(20);
            });

            describe(@"large result set", ^{

                it(@"limits correctly", ^{
                    CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];
                    [im ensureIndexed:@[ @"large_field", @"idx" ] withName:@"large"];

                    for (int i = 0; i < 100; i++) {
                        rev.docId = [NSString stringWithFormat:@"d%d", i];
                        rev.body = @{ @"large_field" : @"cat", @"idx" : @(i) };
                        [ds createDocumentFromRevision:rev error:nil];
                    }
                    NSDictionary* query = @{ @"large_field" : @"cat" };
                    CDTQResultSet* results = [im find:query skip:0 limit:20 fields:nil sort:nil];
                    expect([results.documentIds count]).to.equal(20);
                });

                it(@"skips and limits across batch border", ^{
                    CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];
                    [im ensureIndexed:@[ @"large_field", @"idx" ] withName:@"large"];

                    for (int i = 0; i < 150; i++) {
                        rev.docId = [NSString stringWithFormat:@"d%d", i];
                        rev.body = @{ @"large_field" : @"cat", @"idx" : @(i) };
                        [ds createDocumentFromRevision:rev error:nil];
                    }

                    NSDictionary* query = @{ @"large_field" : @"cat" };
                    CDTQResultSet* results =
                        [im find:query skip:90 limit:20 fields:nil sort:@[
                            @{ @"idx" : @"asc" }
                        ]];
                    expect([results.documentIds count]).to.equal(20);
                    expect(results.documentIds)
                        .to.containAllElements(@[
                            @"d90",
                            @"d91",
                            @"d92",
                            @"d93",
                            @"d94",
                            @"d95",
                            @"d96",
                            @"d97",
                            @"d98",
                            @"d99",
                            @"d100",
                            @"d101",
                            @"d102",
                            @"d103",
                            @"d104",
                            @"d105",
                            @"d106",
                            @"d107",
                            @"d108",
                            @"d109"
                        ]);
                });
            });

        });
    });

// The aim is to make sure that the post hoc matcher class behaves the
// same as the full version with SQL querying too.
//
// For this, we test the entire pipeline using the usual CDTQQueryExectutor class. This does
// both SQL and post hoc matching. Then we have a sub-class of CDTQQueryExecutor which skips
// the SQL querying and just runs all documents through the CDTQUnindexedMatcher.
sharedExamplesFor(@"queries without covering indexes", ^(NSDictionary* data) {
    // Pull the class to test out of the data object
    Class imClass = data[@"index_manager_class"];

    __block NSString* factoryPath;
    __block CDTDatastoreManager* factory;

    beforeEach(^{
        // Create a new CDTDatastoreFactory at a temp path

        NSString* tempDirectoryTemplate = [NSTemporaryDirectory()
            stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char* tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
        char* tempDirectoryNameCString = (char*)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

        char* result = mkdtemp(tempDirectoryNameCString);
        expect(result).to.beTruthy();

        factoryPath = [[NSFileManager defaultManager]
            stringWithFileSystemRepresentation:tempDirectoryNameCString
                                        length:strlen(result)];
        free(tempDirectoryNameCString);

        NSError* error;
        factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];
    });

    afterEach(^{
        // Delete the databases we used

        factory = nil;
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
    });

    describe(@"when executing queries", ^{

        __block CDTDatastore* ds;
        __block CDTQIndexManager* im;

        beforeEach(^{
            ds = [factory datastoreNamed:@"test" error:nil];
            expect(ds).toNot.beNil();

            CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];

            rev.docId = @"mike12";
            rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"mike34";
            rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"mike72";
            rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"cat", @"town" : @"bristol" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"fred34";
            rev.body = @{ @"name" : @"fred", @"age" : @34, @"pet" : @"cat" };
            [ds createDocumentFromRevision:rev error:nil];

            rev.docId = @"fred12";
            rev.body = @{ @"name" : @"fred", @"age" : @12, @"town" : @"bristol" };
            [ds createDocumentFromRevision:rev error:nil];

            im = [imClass managerUsingDatastore:ds error:nil];
            expect(im).toNot.beNil();

            expect([im ensureIndexed:@[ @"name", @"age" ] withName:@"basic"]).toNot.beNil();
            expect([im ensureIndexed:@[ @"name", @"pet" ] withName:@"pet"]).toNot.beNil();
        });

        it(@"query without index", ^{
            NSDictionary* query = @{ @"pet" : @{@"$eq" : @"cat"}, @"age" : @{@"$eq" : @12} };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(1);
        });

        it(@"query without index", ^{
            NSDictionary* query = @{ @"town" : @"bristol" };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(2);
            expect(result.documentIds).to.beSupersetOf(@[ @"mike72", @"fred12" ]);
        });
        
        it(@"query using OR while missing a covering index", ^{
            NSDictionary* query = @{ @"$or" : @[ @{ @"pet" : @{@"$eq" : @"cat"} },
                                                 @{ @"town" : @{@"$eq" : @"bristol"} }
                                               ]
                                   };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(4);
            expect(result.documentIds).to.beSupersetOf(@[ @"mike12",
                                                          @"mike72",
                                                          @"fred34",
                                                          @"fred12" ]);
        });
        
        it(@"query using OR without any covering indexes", ^{
            expect([im deleteIndexNamed:@"pet"]).toNot.beNil();
            NSDictionary *indexes = [im listIndexes];
            expect(indexes.count).to.equal(1);
            expect(indexes.allKeys).to.beSupersetOf(@[ @"basic" ]);
            
            NSDictionary* query = @{ @"$or" : @[ @{ @"pet" : @{@"$eq" : @"cat"} },
                                                 @{ @"town" : @{@"$eq" : @"bristol"} }
                                               ]
                                   };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(4);
            expect(result.documentIds).to.beSupersetOf(@[ @"mike12",
                                                          @"mike72",
                                                          @"fred34",
                                                          @"fred12" ]);
        });

        it(@"post-hoc matches when projecting over non-queried fields", ^{
            NSDictionary* query = @{ @"town" : @"bristol" };
            CDTQResultSet* result = [im find:query skip:0 limit:0 fields:@[ @"name" ] sort:nil];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(2);
            expect(result.documentIds).to.beSupersetOf(@[ @"mike72", @"fred12" ]);
        });
    });
});

SharedExamplesEnd

    // This spec pushes the standard CDTQQueryExecutor through the shared behaviour tests.
    SpecBegin(CDTQQueryExecutor) describe(@"full with covering", ^{
        NSDictionary* data = @{ @"index_manager_class" : [CDTQIndexManager class] };
        itShouldBehaveLike(@"queries with covering indexes", data);
    });

describe(@"full without covering", ^{
    NSDictionary* data = @{ @"index_manager_class" : [CDTQIndexManager class] };
    itShouldBehaveLike(@"queries without covering indexes", data);
});

SpecEnd

    // This class skips the matcher to check that SQL only returns the same
    SpecBegin(CDTQSQLOnlyQueryExecutor) describe(@"sql with covering", ^{
        NSDictionary* data = @{ @"index_manager_class" : [CDTQSQLOnlyIndexManager class] };
        itShouldBehaveLike(@"queries with covering indexes", data);
    });

// Don't run "queries without covering indexes" as they'll obviously not work

SpecEnd

    // This class skips SQL and just uses the matcher to ensure the matcher class returns
    // the same as the SQL version.
    SpecBegin(CDTQMatcherQueryExecutor) describe(@"matcher with covering", ^{
        NSDictionary* data = @{ @"index_manager_class" : [CDTQMatcherIndexManager class] };
        itShouldBehaveLike(@"queries with covering indexes", data);
    });

describe(@"matcher without covering", ^{
    NSDictionary* data = @{ @"index_manager_class" : [CDTQMatcherIndexManager class] };
    itShouldBehaveLike(@"queries without covering indexes", data);
});

SpecEnd
