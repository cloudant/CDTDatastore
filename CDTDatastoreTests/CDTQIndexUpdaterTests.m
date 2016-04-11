//
//  CloudantQueryObjcTests.m
//  CloudantQueryObjcTests
//
//  Created by Michael Rhodes on 09/27/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//
#import <CDTDatastore/CDTQIndexCreator.h>
#import <CDTDatastore/CDTQIndexManager.h>
#import <CDTDatastore/CDTQIndexUpdater.h>
#import <CDTDatastore/CDTQQueryExecutor.h>
#import <CDTDatastore/CDTQResultSet.h>
#import <CDTDatastore/CloudantSync.h>
#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

SpecBegin(CDTQIndexUpdater)

    describe(@"cloudant query", ^{

        __block NSString *factoryPath;
        __block CDTDatastoreManager *factory;
        __block CDTDatastore *ds;

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
        });

        afterEach(^{
            // Delete the databases we used

            factory = nil;
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
        });

        describe(@"when generating DELETE index entries statements", ^{

            it(@"returns nil for no _id", ^{
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToDeleteIndexEntriesForDocId:nil fromIndex:@"anIndex"];
                expect(parts).to.beNil();
            });

            it(@"returns nil for no index name", ^{
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToDeleteIndexEntriesForDocId:@"123" fromIndex:nil];
                expect(parts).to.beNil();
            });

            it(@"returns correctly for document", ^{
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToDeleteIndexEntriesForDocId:@"123"
                                                              fromIndex:@"anIndex"];
                NSString *sql = @"DELETE FROM _t_cloudant_sync_query_index_anIndex WHERE _id = ?;";
                expect(parts.sqlWithPlaceholders).to.equal(sql);
                expect(parts.placeholderValues).to.equal(@[ @"123" ]);
            });

        });

        describe(@"when generating INSERT statements", ^{

            it(@"returns correctly for single field", ^{
                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                rev.body = @{ @"name" : @"mike" };
                CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                CDTQSqlParts *parts = [CDTQIndexUpdater partsToIndexRevision:saved
                                                                     inIndex:@"anIndex"
                                                              withFieldNames:@[ @"name" ]][0];

                NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                 "( \"_id\", \"_rev\", \"name\" ) VALUES ( ?, ?, ? );";
                expect(parts.sqlWithPlaceholders).to.equal(sql);
                expect(parts.placeholderValues).to.equal(@[ @"id123", saved.revId, @"mike" ]);
            });

            it(@"returns correctly for two fields", ^{
                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                rev.body = @{ @"name" : @"mike", @"age" : @12 };
                CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToIndexRevision:saved
                                                   inIndex:@"anIndex"
                                            withFieldNames:@[ @"age", @"name" ]][0];

                NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                 "( \"_id\", \"_rev\", \"age\", \"name\" ) VALUES ( ?, ?, ?, ? );";
                expect(parts.sqlWithPlaceholders).to.equal(sql);
                expect(parts.placeholderValues).to.equal(@[ @"id123", saved.revId, @12, @"mike" ]);
            });

            it(@"returns correctly for multiple fields", ^{
                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                rev.body = @{
                    @"name" : @"mike",
                    @"age" : @12,
                    @"pet" : @"cat",
                    @"car" : @"mini",
                    @"ignored" : @"something"
                };
                CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToIndexRevision:saved
                                                   inIndex:@"anIndex"
                                            withFieldNames:@[ @"age", @"name", @"pet", @"car" ]][0];

                NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                 "( \"_id\", \"_rev\", \"age\", \"name\", \"pet\", \"car\" ) "
                                 "VALUES ( ?, ?, ?, ?, ?, ? );";
                expect(parts.sqlWithPlaceholders).to.equal(sql);
                expect(parts.placeholderValues)
                    .to.equal(@[ @"id123", saved.revId, @12, @"mike", @"cat", @"mini" ]);
            });

            it(@"returns correctly for missing fields", ^{
                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                rev.body = @{ @"name" : @"mike", @"pet" : @"cat", @"ignored" : @"something" };
                CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToIndexRevision:saved
                                                   inIndex:@"anIndex"
                                            withFieldNames:@[ @"age", @"name", @"pet", @"car" ]][0];

                NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                 "( \"_id\", \"_rev\", \"name\", \"pet\" ) VALUES ( ?, ?, ?, ? );";
                expect(parts.sqlWithPlaceholders).to.equal(sql);
                expect(parts.placeholderValues)
                    .to.equal(@[ @"id123", saved.revId, @"mike", @"cat" ]);
            });

            it(@"still indexes a blank row if no fields", ^{
                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                rev.body = @{ @"name" : @"mike", @"pet" : @"cat", @"ignored" : @"something" };
                CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                CDTQSqlParts *parts =
                    [CDTQIndexUpdater partsToIndexRevision:saved
                                                   inIndex:@"anIndex"
                                            withFieldNames:@[ @"car", @"van" ]][0];
                NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                 "( \"_id\", \"_rev\" ) VALUES ( ?, ? );";
                expect(parts.sqlWithPlaceholders).to.equal(sql);
                expect(parts.placeholderValues).to.equal(@[ @"id123", saved.revId ]);
            });

            context(@"when indexing arrays", ^{

                it(@"indexes a single array field", ^{
                    CDTDocumentRevision *rev;
                    rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                    rev.body = @{ @"name" : @"mike", @"pet" : @[ @"cat", @"dog", @"parrot" ] };
                    CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                    NSArray *statements =
                        [CDTQIndexUpdater partsToIndexRevision:saved
                                                       inIndex:@"anIndex"
                                                withFieldNames:@[ @"name", @"pet" ]];
                    expect(statements.count).to.equal(3);

                    CDTQSqlParts *parts;
                    NSString *sql;

                    parts = statements[0];
                    sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                           "( \"_id\", \"_rev\", \"pet\", \"name\" ) VALUES ( ?, ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues)
                        .to.equal(@[ @"id123", saved.revId, @"cat", @"mike" ]);

                    parts = statements[1];
                    sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                           "( \"_id\", \"_rev\", \"pet\", \"name\" ) VALUES ( ?, ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues)
                        .to.equal(@[ @"id123", saved.revId, @"dog", @"mike" ]);

                    parts = statements[2];
                    sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                           "( \"_id\", \"_rev\", \"pet\", \"name\" ) VALUES ( ?, ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues)
                        .to.equal(@[ @"id123", saved.revId, @"parrot", @"mike" ]);
                });

                it(@"indexes a single array field in subdoc", ^{
                    CDTDocumentRevision *rev;
                    rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                    rev.body = @{ @"name" : @"mike", @"pet" : @{@"species" : @[ @"cat", @"dog" ]} };
                    CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                    NSArray *statements =
                        [CDTQIndexUpdater partsToIndexRevision:saved
                                                       inIndex:@"anIndex"
                                                withFieldNames:@[ @"name", @"pet.species" ]];
                    expect(statements.count).to.equal(2);

                    CDTQSqlParts *parts;
                    NSString *sql;

                    parts = statements[0];
                    sql =
                        @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                         "( \"_id\", \"_rev\", \"pet.species\", \"name\" ) VALUES ( ?, ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues)
                        .to.equal(@[ @"id123", saved.revId, @"cat", @"mike" ]);

                    parts = statements[1];
                    sql =
                        @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                         "( \"_id\", \"_rev\", \"pet.species\", \"name\" ) VALUES ( ?, ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues)
                        .to.equal(@[ @"id123", saved.revId, @"dog", @"mike" ]);
                });

                it(@"rejects multiple array fields", ^{
                    CDTDocumentRevision *rev;
                    rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                    rev.body = @{
                        @"name" : @"mike",
                        @"pet" : @[ @"cat", @"dog", @"parrot" ],
                        @"pet2" : @[ @"cat", @"dog", @"parrot" ]
                    };
                    CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                    NSArray *statements =
                        [CDTQIndexUpdater partsToIndexRevision:saved
                                                       inIndex:@"anIndex"
                                                withFieldNames:@[ @"name", @"pet", @"pet2" ]];
                    expect(statements).to.beNil();
                });
                
                it(@"returns correctly for empty array field", ^{
                    // Treat an empty array field the same as a missing field.
                    // Only the "name" field should be included as a result of this test.
                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                    rev.body = @{ @"name" : @"mike", @"pet" : @[] };
                    CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                    NSArray *statements = [CDTQIndexUpdater partsToIndexRevision:saved
                                                                         inIndex:@"anIndex"
                                                                  withFieldNames:@[ @"age",
                                                                                    @"name",
                                                                                    @"pet" ] ];
                    expect(statements.count).to.equal(1);
                    CDTQSqlParts *parts = statements[0];
                    
                    NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                     "( \"_id\", \"_rev\", \"name\" ) VALUES ( ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues).to.equal(@[ @"id123", saved.revId, @"mike" ]);
                });

                it(@"returns correctly for empty array in a subdoc", ^{
                    CDTDocumentRevision *rev;
                    rev = [CDTDocumentRevision revisionWithDocId:@"id123"];
                    rev.body = @{ @"name" : @"mike", @"pet" : @{@"species" : @[] } };
                    CDTDocumentRevision *saved = [ds createDocumentFromRevision:rev error:nil];
                    NSArray *statements = [CDTQIndexUpdater partsToIndexRevision:saved
                                                                         inIndex:@"anIndex"
                                                                  withFieldNames:@[@"age",
                                                                                   @"name",
                                                                                   @"pet.species"]];
                    expect(statements.count).to.equal(1);
                    CDTQSqlParts *parts = statements[0];
                    
                    NSString *sql = @"INSERT INTO _t_cloudant_sync_query_index_anIndex "
                                     "( \"_id\", \"_rev\", \"name\" ) VALUES ( ?, ?, ? );";
                    expect(parts.sqlWithPlaceholders).to.equal(sql);
                    expect(parts.placeholderValues).to.equal(@[ @"id123", saved.revId, @"mike" ]);
                });

            });

        });

        describe(@"when setting sequence numbers", ^{

            __block CDTDatastore *ds;
            __block CDTQIndexManager *im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                CDTDocumentRevision *rev;

                rev = [CDTDocumentRevision revisionWithDocId:@"mike12"];
                rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
                [ds createDocumentFromRevision:rev error:nil];

                rev = [CDTDocumentRevision revisionWithDocId:@"mike23"];
                rev.body = @{ @"name" : @"mike", @"age" : @23, @"pet" : @"parrot" };
                [ds createDocumentFromRevision:rev error:nil];

                rev = [CDTDocumentRevision revisionWithDocId:@"mike34"];
                rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
                [ds createDocumentFromRevision:rev error:nil];

                rev = [CDTDocumentRevision revisionWithDocId:@"john72"];
                rev.body = @{ @"name" : @"john", @"age" : @34, @"pet" : @"fish" };
                [ds createDocumentFromRevision:rev error:nil];

                rev = [CDTDocumentRevision revisionWithDocId:@"fred34"];
                rev.body = @{ @"name" : @"fred", @"age" : @43, @"pet" : @"snake" };
                [ds createDocumentFromRevision:rev error:nil];

                rev = [CDTDocumentRevision revisionWithDocId:@"fred12"];
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

            });

            it(@"sets correct sequence number", ^{

                expect([im ensureIndexed:@[ @"age", @"pet", @"name" ] withName:@"basic"])
                    .toNot.beNil();

                FMDatabaseQueue *queue =
                    (FMDatabaseQueue *)[im performSelector:@selector(database)];

                CDTQIndexUpdater *updater =
                    [[CDTQIndexUpdater alloc] initWithDatabase:queue datastore:ds];
                expect([updater sequenceNumberForIndex:@"basic"]).to.equal(6);

                expect([updater updateAllIndexes:[im listIndexes]]).to.beTruthy();

                expect([updater sequenceNumberForIndex:@"basic"]).to.equal(6);

            });

            it(@"sets correct sequence number after update", ^{
                expect([im ensureIndexed:@[ @"age", @"pet", @"name" ] withName:@"basic"])
                    .toNot.beNil();
                FMDatabaseQueue *queue =
                    (FMDatabaseQueue *)[im performSelector:@selector(database)];
                CDTQIndexUpdater *updater =
                    [[CDTQIndexUpdater alloc] initWithDatabase:queue datastore:ds];

                CDTDocumentRevision *rev;
                rev = [CDTDocumentRevision revisionWithDocId:@"newdoc"];
                rev.body = @{ @"name" : @"fred", @"age" : @12 };
                [ds createDocumentFromRevision:rev error:nil];

                expect([updater updateAllIndexes:[im listIndexes]]).to.beTruthy();

                expect([updater sequenceNumberForIndex:@"basic"]).to.equal(7);

            });
            
            describe(@"when using a text index", ^{
                it(@"sets correct sequence number", ^{
                    
                    expect([im ensureIndexed:@[ @"pet", @"name" ]
                                    withName:@"basic"
                                        type:@"text"]).toNot.beNil();
                    
                    FMDatabaseQueue *queue =
                        (FMDatabaseQueue *)[im performSelector:@selector(database)];
                    
                    CDTQIndexUpdater *updater =
                    [[CDTQIndexUpdater alloc] initWithDatabase:queue datastore:ds];
                    expect([updater sequenceNumberForIndex:@"basic"]).to.equal(6);
                    
                    expect([updater updateAllIndexes:[im listIndexes]]).to.beTruthy();
                    
                    expect([updater sequenceNumberForIndex:@"basic"]).to.equal(6);
                    
                });
                
                it(@"sets correct sequence number after update", ^{
                    expect([im ensureIndexed:@[ @"pet", @"name" ]
                                    withName:@"basic"
                                        type:@"text"]).toNot.beNil();
                    FMDatabaseQueue *queue =
                        (FMDatabaseQueue *)[im performSelector:@selector(database)];
                    CDTQIndexUpdater *updater =
                        [[CDTQIndexUpdater alloc] initWithDatabase:queue datastore:ds];

                    CDTDocumentRevision *rev;
                    rev = [CDTDocumentRevision revisionWithDocId:@"newdoc"];
                    rev.body = @{ @"name" : @"fred", @"age" : @12 };
                    [ds createDocumentFromRevision:rev error:nil];
                    
                    expect([updater updateAllIndexes:[im listIndexes]]).to.beTruthy();
                    
                    expect([updater sequenceNumberForIndex:@"basic"]).to.equal(7);
                    
                });
            });

        });
    });

SpecEnd
