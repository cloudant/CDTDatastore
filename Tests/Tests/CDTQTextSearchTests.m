//
//  CDTQTextSearchTests.m
//  CloudantSync
//
//  Created by Al Finkelstein on 05/08/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <CloudantSync.h>
#import <Specta.h>
#import <Expecta.h>
#import "Matchers/CDTQContainsAllElementsMatcher.h"

SpecBegin(CDTQQueryExecutorTextSearch) describe(@"cdtq", ^{

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

    describe(@"when executing a text search", ^{

        __block CDTDatastore *ds;
        __block CDTQIndexManager *im;

        beforeEach(^{
            ds = [factory datastoreNamed:@"test" error:nil];
            expect(ds).toNot.beNil();
            
            CDTMutableDocumentRevision* rev = [CDTMutableDocumentRevision revision];
            
            rev.docId = @"mike12";
            rev.body = @{ @"name" : @"mike",
                          @"age" : @12,
                          @"pet" : @"cat",
                          @"comment" : @"He lives in Bristol, UK and his best friend is Fred."};
            [ds createDocumentFromRevision:rev error:nil];
            
            rev.docId = @"mike34";
            rev.body = @{ @"name" : @"mike",
                          @"age" : @34,
                          @"pet" : @"dog",
                          @"comment" : @"He lives in a van down by the river in Bristol."};
            [ds createDocumentFromRevision:rev error:nil];
            
            rev.docId = @"mike72";
            rev.body = @{ @"name" : @"mike",
                          @"age" : @72,
                          @"pet" : @"cat",
                          @"comment" : @"He's retired and has memories of spending time "
                                       @"with his cat Remus."};
            [ds createDocumentFromRevision:rev error:nil];
            
            rev.docId = @"fred34";
            rev.body = @{ @"name" : @"fred",
                          @"age" : @34,
                          @"pet" : @"cat",
                          @"comment" : @"He lives next door to Mike and his cat Romulus "
                                       @"is brother to Remus."};
            [ds createDocumentFromRevision:rev error:nil];
            
            rev.docId = @"fred12";
            rev.body = @{ @"name" : @"fred",
                          @"age" : @12,
                          @"pet" : @"cat",
                          @"comment" : @"He lives in Bristol, UK and his best friend is Mike."};
            [ds createDocumentFromRevision:rev error:nil];
            
            rev.docId = @"john34";
            rev.body =
                @{ @"name" : @"john",
                   @"age" : @34,
                   @"pet" : @"cat",
                   @"comment" : @"وهو يعيش في بريستول، المملكة المتحدة، وأفضل صديق له هو مايك."};
            [ds createDocumentFromRevision:rev error:nil];
            
            im = [CDTQIndexManager managerUsingDatastore:ds error:nil];
            expect(im).toNot.beNil();
        });

        it(@"can perform a search consisting of a single text clause", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"lives in Bristol"} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"mike34", @"fred12" ]);
        });
        
        it(@"can perform a phrase search", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"\"lives in Bristol\""} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"fred12" ]);
        });
        
        it(@"can perform a search containing an apostrophe", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"he's retired"} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike72" ]);
        });
        
        it(@"can perform a search consisting of a single text clause with a sort", ^{
            expect([im ensureIndexed:@[ @"name", @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"best friend"} };
            NSArray *order = @[ @{ @"name" : @"asc" } ];
            CDTQResultSet* result = [im find:query skip:0 limit:0 fields:nil sort: order];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"fred12" ]);
            expect(result.documentIds[0]).to.equal(@"fred12");
            expect(result.documentIds[1]).to.equal(@"mike12");
        });
        
        it(@"can perform a compound AND query search containing a text clause", ^{
            expect([im ensureIndexed:@[ @"name" ] withName:@"basic"]).toNot.beNil();
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"name" : @"mike",
                                     @"$text" : @{@"$search" : @"best friend"} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12" ]);
        });
        
        it(@"can perform a compound OR query search containing a text clause", ^{
            expect([im ensureIndexed:@[ @"name" ] withName:@"basic"]).toNot.beNil();
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$or" : @[ @{ @"name" : @"mike" },
                                                 @{ @"$text" : @{@"$search" : @"best friend"} } ] };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12",
                                                                @"mike34",
                                                                @"mike72",
                                                                @"fred12" ]);
        });
        
        it(@"returns nil for a text search without a text index", ^{
            expect([im ensureIndexed:@[ @"name" ] withName:@"basic"]).toNot.beNil();
            
            NSDictionary* query = @{ @"name" : @"mike",
                                     @"$text" : @{@"$search" : @"best friend"} };
            expect([im find:query]).to.beNil();
        });
        
        it(@"returns nil for query containing text clause when a needed json index is missing", ^{
            // All fields in a TEXT index only apply to the text search portion of any query.
            // So even though "name" exists in the text index, the clause that { "name" : "mike" }
            // expects a JSON index that contains the "name" field.  Since, this query includes a
            // text search clause then all clauses of the query must be satisfied by existing
            // indexes.
            expect([im ensureIndexed:@[ @"name", @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$or" : @[ @{ @"name" : @"mike" },
                                                 @{ @"$text" : @{@"$search" : @"best friend"} } ] };
            expect([im find:query]).to.beNil();
        });
        
        it(@"can perform a text search containing non-ascii values", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"\"صديق له هو\""} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"john34" ]);
        });
        
        it(@"returns empty result set for unmatched phrase search", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"\"remus romulus\""} };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(0);
        });
        
        it(@"returns correct result set for non-contiguous word search", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // The search predicate "Remus Romulus" normalizes to "Remus AND Romulus" in SQLite
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"remus romulus"} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"fred34" ]);
        });
        
        it(@"can perform text search using enhanced query syntax OR operator", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // Enhanced Query Syntax - logical operators must be uppercase otherwise they will
            // be treated as a search token
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"Remus OR Romulus"} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"fred34", @"mike72" ]);
        });
        
        it(@"can perform text search using enhanced query syntax NOT operator", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // Enhanced Query Syntax - logical operators must be uppercase otherwise they will
            // be treated as a search token
            // - NOT operator only works between tokens as in (token1 NOT token2)
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"Remus NOT Romulus"} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike72" ]);
        });
        
        it(@"can perform text search using enhanced query syntax with parentheses", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // Parentheses are used to override SQLite enhanced query syntax operator precedence
            // - Operator precedence is NOT -> AND -> OR
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"(Remus OR Romulus) "
                                                               @"AND \"lives next door\""} };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"fred34" ]);
        });
        
        it(@"can perform text search using NEAR operator", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // NEAR provides the ability to search for terms/phrases in proximity to each other
            // - By specifying a value for NEAR as in NEAR/2 you can define the range of proximity.
            //   If left out it defaults to 10
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"\"he lives\" NEAR/2 Bristol" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"fred12" ]);
        });
        
        it(@"is case insensitive when using the default tokenizer", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // Search is generally case-insensitive unless a custom tokenizer is provided
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"rEmUs RoMuLuS" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"fred34" ]);
        });
        
        it(@"treats non-string field as a string when performing a text search", ^{
            expect([im ensureIndexed:@[ @"age" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"12" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"fred12" ]);
        });
        
        it(@"returns nil when text search criteria is not a string", ^{
            expect([im ensureIndexed:@[ @"age" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @12 } };
            expect([im find:query]).to.beNil();
        });
        
        it(@"can perform a text search across multiple fields", ^{
            expect([im ensureIndexed:@[ @"name", @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // Will find fred12 and fred34 as well as mike12 since Fred is also mentioned
            // in mike12's comment
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"Fred" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"fred12", @"fred34" ]);
        });
        
        it(@"can perform a text search targeting specific fields", ^{
            expect([im ensureIndexed:@[ @"name", @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            // Will only find fred12 since he is the only named fred who's comment
            // states that he "lives in Bristol"
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"name:fred "
                                                               @"comment:lives in Bristol" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"fred12" ]);
        });
        
        it(@"can perform a text search using prefix searches", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"liv* riv*" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike34" ]);
        });
        
        it(@"retuns empty result set when missing wildcards in prefix searches", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"liv riv" } };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(0);
        });
        
        it(@"can perform a text search using ID", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"_id:mike*" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike12", @"mike34", @"mike72" ]);
        });
        
        it(@"can perform a text search using the Porter tokenizer stemmer", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"
                            settings:@{ @"tokenize" : @"porter" }]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"retire memory" } };
            CDTQResultSet* result = [im find:query];
            expect(result.documentIds).to.containAllElements(@[ @"mike72" ]);
        });
        
        it(@"returns empty result set when using default tokenizer stemmer", ^{
            expect([im ensureIndexed:@[ @"comment" ]
                            withName:@"basic_text"
                                type:@"text"]).toNot.beNil();
            
            NSDictionary* query = @{ @"$text" : @{@"$search" : @"retire memory" } };
            CDTQResultSet* result = [im find:query];
            expect(result).toNot.beNil();
            expect(result.documentIds.count).to.equal(0);
        });

    });
    
});

SpecEnd
