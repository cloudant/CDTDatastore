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

SpecBegin(CDTQIndexCreator)

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

        describe(@"when creating indexes", ^{

            __block CDTDatastore *ds;
            __block CDTQIndexManager *im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();
                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();
            });

            it(@"doesn't create an index on no fields", ^{
                NSString *name = [im ensureIndexed:@[] withName:@"basic"];
                expect(name).to.equal(nil);

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(0);
            });

            it(@"doesn't create an index if duplicate fields", ^{
                NSString *name = [im ensureIndexed:@[ @"age", @"pet", @"age" ] withName:@"basic"];
                expect(name).to.equal(nil);

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(0);
            });

            it(@"doesn't create an index on nil fields", ^{
                NSString *name = [im ensureIndexed:nil withName:@"basic"];
                expect(name).to.equal(nil);

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(0);
            });

            it(@"doesn't create an index without a name", ^{
                NSString *name = [im ensureIndexed:@[ @"name" ] withName:nil];
                expect(name).to.equal(nil);

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(0);
            });

            it(@"can create an index over one fields", ^{
                NSString *name = [im ensureIndexed:@[ @"name" ] withName:@"basic"];
                expect(name).to.equal(@"basic");

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(1);
                expect(indexes.allKeys).to.contain(@"basic");

                expect([indexes[@"basic"][@"fields"] count]).to.equal(3);
                expect(indexes[@"basic"][@"fields"]).to.equal(@[ @"_id", @"_rev", @"name" ]);
            });

            it(@"can create an index over two fields", ^{
                NSString *name = [im ensureIndexed:@[ @"name", @"age" ] withName:@"basic"];
                expect(name).to.equal(@"basic");

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(1);
                expect(indexes.allKeys).to.contain(@"basic");

                expect([indexes[@"basic"][@"fields"] count]).to.equal(4);
                expect(indexes[@"basic"][@"fields"])
                    .to.beSupersetOf(@[ @"_id", @"_rev", @"name", @"age" ]);
            });

            it(@"can create an index using dotted notation", ^{
                NSString *name =
                    [im ensureIndexed:@[ @"name.first", @"age.years" ] withName:@"basic"];
                expect(name).to.equal(@"basic");

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys).to.equal(@[ @"basic" ]);
                expect(indexes[@"basic"][@"fields"])
                    .to.equal(@[ @"_id", @"_rev", @"name.first", @"age.years" ]);
            });

            it(@"can create more than one index", ^{
                [im ensureIndexed:@[ @"name", @"age" ] withName:@"basic"];
                [im ensureIndexed:@[ @"name", @"age" ] withName:@"another"];
                [im ensureIndexed:@[ @"cat" ] withName:@"petname"];

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(3);
                expect(indexes.allKeys).to.beSupersetOf(@[ @"basic", @"another", @"petname" ]);

                expect([indexes[@"basic"][@"fields"] count]).to.equal(4);
                expect(indexes[@"basic"][@"fields"])
                    .to.beSupersetOf(@[ @"_id", @"_rev", @"name", @"age" ]);

                expect([indexes[@"another"][@"fields"] count]).to.equal(4);
                expect(indexes[@"another"][@"fields"])
                    .to.beSupersetOf(@[ @"_id", @"_rev", @"name", @"age" ]);

                expect([indexes[@"petname"][@"fields"] count]).to.equal(3);
                expect(indexes[@"petname"][@"fields"])
                    .to.beSupersetOf(@[ @"_id", @"_rev", @"cat" ]);
            });

            it(@"can create indexes specified with asc/desc", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"];
                expect(name).to.equal(@"basic");

                NSDictionary *indexes = [im listIndexes];
                expect(indexes.allKeys.count).to.equal(1);
                expect(indexes.allKeys).to.contain(@"basic");

                expect([indexes[@"basic"][@"fields"] count]).to.equal(4);
                expect(indexes[@"basic"][@"fields"])
                    .to.beSupersetOf(@[ @"_id", @"_rev", @"name", @"age" ]);
            });

        });

        describe(@"when calling ensureIndexed on an index name that already exists", ^{

            __block CDTQIndexManager *im;

            beforeEach(^{
                CDTDatastore *ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();
                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();

                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"];
                expect(name).to.equal(@"basic");
            });

            it(@"succeeds when the index definition is the same", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"];
                expect(name).to.equal(@"basic");
            });

            it(@"fails when the index definition is different", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"pet" : @"desc"
                    } ] withName:@"basic"];
                expect(name).to.beNil();
            });

        });

        describe(@"when creating indexes with a type", ^{

            __block CDTQIndexManager *im;

            beforeEach(^{
                CDTDatastore *ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();
                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();
            });

            it(@"supports using the json type", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"
                                 type:@"json"];
                expect(name).to.equal(@"basic");
            });

            it(@"doesn't support using the text type", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"
                                 type:@"text"];
                expect(name).to.beNil();
            });

            it(@"doesn't support using the geo type", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"
                                 type:@"geo"];
                expect(name).to.beNil();
            });

            it(@"doesn't support using the unplanned type", ^{
                NSString *name =
                    [im ensureIndexed:@[ @{ @"name" : @"asc" }, @{
                        @"age" : @"desc"
                    } ] withName:@"basic"
                                 type:@"frog"];
                expect(name).to.beNil();
            });

        });

        describe(@"when using non-ascii text", ^{

            __block CDTDatastore *ds;
            __block CDTQIndexManager *im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();
            });

            it(@"can create indexes successfully", ^{
                expect(
                    [im ensureIndexed:@[ @"اسم", @"@datatype", @"ages" ] withName:@"nonascii"])
                    .toNot.beNil();
            });
        });

        describe(@"when normalising index fields", ^{

            it(@"removes directions from the field specifiers", ^{
                NSArray *fields = [CDTQIndexCreator
                    removeDirectionsFromFields:
                        @[ @{ @"name" : @"asc" }, @{ @"pet" : @"asc" }, @"age" ]];
                expect(fields).to.equal(@[ @"name", @"pet", @"age" ]);
            });

        });

        describe(@"when validating field names", ^{

            __block CDTDatastore *ds;
            __block CDTQIndexManager *im;

            beforeEach(^{
                ds = [factory datastoreNamed:@"test" error:nil];
                expect(ds).toNot.beNil();

                im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
                expect(im).toNot.beNil();
            });

            it(@"rejects indexes with $ at start", ^{
                expect([im ensureIndexed:@[ @"$name", @"@datatype" ] withName:@"nonascii"])
                    .to.beNil();
            });

            it(@"rejects indexes with $ in but not at start", ^{
                expect([im ensureIndexed:@[ @"na$me", @"@datatype$" ] withName:@"nonascii"])
                    .toNot.beNil();
            });

            it(@"allows single fields",
               ^{ expect([CDTQIndexCreator validFieldName:@"name"]).to.beTruthy(); });

            it(@"allows dotted notation fields", ^{
                expect([CDTQIndexCreator validFieldName:@"name.first"]).to.beTruthy();
                expect([CDTQIndexCreator validFieldName:@"name.first.prefix"]).to.beTruthy();
            });

            it(@"allows dollars in positions other than first letter of a part", ^{
                expect([CDTQIndexCreator validFieldName:@"na$me"]).to.beTruthy();
                expect([CDTQIndexCreator validFieldName:@"name.fir$t"]).to.beTruthy();
                expect([CDTQIndexCreator validFieldName:@"name.fir$t.pref$x"]).to.beTruthy();
                expect([CDTQIndexCreator validFieldName:@"name.fir$t.pref$x"]).to.beTruthy();
            });

            it(@"rejects dollars in first letter of a part", ^{
                expect([CDTQIndexCreator validFieldName:@"$name"]).to.beFalsy();
                expect([CDTQIndexCreator validFieldName:@"name.$first"]).to.beFalsy();
                expect([CDTQIndexCreator validFieldName:@"name.$first.$prefix"]).to.beFalsy();
                expect([CDTQIndexCreator validFieldName:@"name.first.$prefix"]).to.beFalsy();
                expect([CDTQIndexCreator validFieldName:@"name.first.$pr$efix"]).to.beFalsy();
                expect([CDTQIndexCreator validFieldName:@"name.$$$$.prefix"]).to.beFalsy();
            });

        });

        describe(@"when SQL statements to create indexes", ^{

            // INSERT INTO metdata table

            it(@"doesn't create insert statements when there are no fields", ^{
                NSArray *fieldNames = @[];
                NSArray *parts = [CDTQIndexCreator insertMetadataStatementsForIndexName:@"anIndex"
                                                                                   type:@"json"
                                                                             fieldNames:fieldNames];
                expect(parts).to.beNil();
            });

            it(@"can create insert statements for an index with one field", ^{
                NSArray *fieldNames = @[ @"_id", @"name" ];
                NSArray *parts = [CDTQIndexCreator insertMetadataStatementsForIndexName:@"anIndex"
                                                                                   type:@"json"
                                                                             fieldNames:fieldNames];

                CDTQSqlParts *part;

                part = parts[0];
                expect(part.sqlWithPlaceholders)
                    .to.equal(@"INSERT INTO _t_cloudant_sync_query_metadata"
                               " (index_name, index_type, field_name, last_sequence) "
                               "VALUES (?, ?, ?, 0);");
                expect(part.placeholderValues).to.equal(@[ @"anIndex", @"json", @"_id" ]);

                part = parts[1];
                expect(part.sqlWithPlaceholders)
                    .to.equal(@"INSERT INTO _t_cloudant_sync_query_metadata"
                               " (index_name, index_type, field_name, last_sequence) "
                               "VALUES (?, ?, ?, 0);");
                expect(part.placeholderValues).to.equal(@[ @"anIndex", @"json", @"name" ]);
            });

            it(@"can create insert statements for an index with many fields", ^{
                NSArray *fieldNames = @[ @"_id", @"name", @"age", @"pet" ];
                NSArray *parts = [CDTQIndexCreator insertMetadataStatementsForIndexName:@"anIndex"
                                                                                   type:@"json"
                                                                             fieldNames:fieldNames];

                CDTQSqlParts *part;

                part = parts[0];
                expect(part.sqlWithPlaceholders)
                    .to.equal(@"INSERT INTO _t_cloudant_sync_query_metadata"
                               " (index_name, index_type, field_name, last_sequence) "
                               "VALUES (?, ?, ?, 0);");
                expect(part.placeholderValues).to.equal(@[ @"anIndex", @"json", @"_id" ]);

                part = parts[1];
                expect(part.sqlWithPlaceholders)
                    .to.equal(@"INSERT INTO _t_cloudant_sync_query_metadata"
                               " (index_name, index_type, field_name, last_sequence) "
                               "VALUES (?, ?, ?, 0);");
                expect(part.placeholderValues).to.equal(@[ @"anIndex", @"json", @"name" ]);

                part = parts[2];
                expect(part.sqlWithPlaceholders)
                    .to.equal(@"INSERT INTO _t_cloudant_sync_query_metadata"
                               " (index_name, index_type, field_name, last_sequence) "
                               "VALUES (?, ?, ?, 0);");
                expect(part.placeholderValues).to.equal(@[ @"anIndex", @"json", @"age" ]);

                part = parts[3];
                expect(part.sqlWithPlaceholders)
                    .to.equal(@"INSERT INTO _t_cloudant_sync_query_metadata"
                               " (index_name, index_type, field_name, last_sequence) "
                               "VALUES (?, ?, ?, 0);");
                expect(part.placeholderValues).to.equal(@[ @"anIndex", @"json", @"pet" ]);
            });

            // CREATE TABLE for Cloudant Query index

            it(@"doesn't create table statements when there are no fields", ^{
                NSArray *fieldNames = @[];
                CDTQSqlParts *parts =
                    [CDTQIndexCreator createIndexTableStatementForIndexName:@"anIndex"
                                                                 fieldNames:fieldNames];
                expect(parts).to.beNil();
            });

            it(@"can create table statements for an index with many fields", ^{
                NSArray *fieldNames = @[ @"_id", @"name" ];
                CDTQSqlParts *parts =
                    [CDTQIndexCreator createIndexTableStatementForIndexName:@"anIndex"
                                                                 fieldNames:fieldNames];
                expect(parts.sqlWithPlaceholders)
                    .to.equal(@"CREATE TABLE _t_cloudant_sync_query_index_anIndex"
                               " ( \"_id\" NONE, \"name\" NONE );");
                expect(parts.placeholderValues).to.equal(@[]);
            });

            it(@"can create table statements for an index with many fields", ^{
                NSArray *fieldNames = @[ @"_id", @"name", @"age", @"pet" ];
                CDTQSqlParts *parts =
                    [CDTQIndexCreator createIndexTableStatementForIndexName:@"anIndex"
                                                                 fieldNames:fieldNames];
                expect(parts.sqlWithPlaceholders)
                    .to.equal(@"CREATE TABLE _t_cloudant_sync_query_index_anIndex"
                               " ( \"_id\" NONE, \"name\" NONE, \"age\" NONE, \"pet\" NONE );");
                expect(parts.placeholderValues).to.equal(@[]);
            });

            // CREATE INDEX for Cloudant Query index

            it(@"doesn't create table index statements when there are no fields", ^{
                NSArray *fieldNames = @[];
                CDTQSqlParts *parts =
                    [CDTQIndexCreator createIndexIndexStatementForIndexName:@"anIndex"
                                                                 fieldNames:fieldNames];
                expect(parts).to.beNil();
            });

            it(@"can create table index statements for an index with many fields", ^{
                NSArray *fieldNames = @[ @"_id", @"name" ];
                CDTQSqlParts *parts =
                    [CDTQIndexCreator createIndexIndexStatementForIndexName:@"anIndex"
                                                                 fieldNames:fieldNames];
                expect(parts.sqlWithPlaceholders)
                    .to.equal(@"CREATE INDEX _t_cloudant_sync_query_index_anIndex_index "
                               "ON _t_cloudant_sync_query_index_anIndex"
                               " ( \"_id\", \"name\" );");
                expect(parts.placeholderValues).to.equal(@[]);
            });

            it(@"can create table index statements for an index with many fields", ^{
                NSArray *fieldNames = @[ @"_id", @"name", @"age", @"pet" ];
                CDTQSqlParts *parts =
                    [CDTQIndexCreator createIndexIndexStatementForIndexName:@"anIndex"
                                                                 fieldNames:fieldNames];
                expect(parts.sqlWithPlaceholders)
                    .to.equal(@"CREATE INDEX _t_cloudant_sync_query_index_anIndex_index "
                               "ON _t_cloudant_sync_query_index_anIndex"
                               " ( \"_id\", \"name\", \"age\", \"pet\" );");
                expect(parts.placeholderValues).to.equal(@[]);
            });
        });
    });

SpecEnd
