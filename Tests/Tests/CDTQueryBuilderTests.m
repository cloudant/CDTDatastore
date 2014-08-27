//
//  CDTQueryBuilderTests.m
//
//
//  Created by Tony Leung on 27/08/2014.
//  Copyright (c) 2014 IBM. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <Foundation/Foundation.h>
#import "CloudantSyncTests.h"
#import "CloudantSync.h"
#import "CDTQueryBuilder.h"


@interface CDTQueryBuilderTests : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;

@end



@implementation CDTQueryBuilderTests

- (void)setUp
{
    [super setUp];
    NSError *error = nil;
    
    // start from scratch
    [self.factory deleteDatastoreNamed:@"test" error:&error];
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    
    STAssertNotNil(self.datastore, @"datastore is nil");
}


- (void)tearDown
{
    [super tearDown];
}

- (void) testBasicPredicates
{
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a > 5"]
                 options: nil
                     sql: @"select a.docid  from _t_cloudant_sync_index_a as a where (a.value > ?)"
             queryValues: @[@5]
         indexReferences: [NSSet setWithObjects:@"a",nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a < 5"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a "
                                "where (a.value < ?)"
                  queryValues: @[@5]
              indexReferences:[NSSet setWithObjects:@"a",nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a <= 5"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a "
                                "where (a.value <= ?)"
                  queryValues: @[@5]
              indexReferences: [NSSet setWithObjects:@"a",nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a >= 5"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a "
                                "where (a.value >= ?)"
                  queryValues: @[@5]
              indexReferences: [NSSet setWithObjects:@"a",nil]];
    
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a = 5"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a "
                                "where (a.value = ?)"
                  queryValues: @[@5]
              indexReferences: [NSSet setWithObjects:@"a",nil]];
    
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a != 5"]
                                                              options: nil
                                                                  sql: @"select a.docid  from "
                                                                        "_t_cloudant_sync_index_a "
                                                                        "as a where (a.value != ?)"
                                                          queryValues: @[@5]
                                                      indexReferences: [NSSet setWithObjects:@"a",
                                                                        nil]];
    // reverse should work too
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"5 != a"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a "
                                "where (a.value != ?)"
                  queryValues: @[@5]
              indexReferences: [NSSet setWithObjects:@"a",nil]];
    
}

- (void) testDoubleCompoundPredicates
{
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"(a > 5) and (c > 6)"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
                                "_t_cloudant_sync_index_c as c where a.docid = c.docid "
                                "and ((a.value > ?) and (c.value > ?))"
                  queryValues: @[@5, @6]
              indexReferences: [NSSet setWithObjects:@"a", @"c", nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"(a > 15) or (c > 16)"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
                                "_t_cloudant_sync_index_c as c where a.docid = c.docid "
                                "and ((a.value > ?) or (c.value > ?))"
                  queryValues: @[@15, @16]
              indexReferences: [NSSet setWithObjects:@"a", @"c", nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"((a > 5) and (c > 6))"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
                                "_t_cloudant_sync_index_c as c where a.docid = c.docid "
                                "and ((a.value > ?) and (c.value > ?))"
                  queryValues: @[@5, @6]
              indexReferences: [NSSet setWithObjects:@"a", @"c", nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"not ((a > 5) and (c > 6))"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
                                "_t_cloudant_sync_index_c as c where a.docid = c.docid "
                                "and ( not  ((a.value > ?) and (c.value > ?)))"
                  queryValues: @[@5, @6]
              indexReferences: [NSSet setWithObjects:@"a", @"c", nil]];
    
}

- (void) testTripleCompoundPredicates
{
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a > 5 and c > 6 and d > 5"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
     "_t_cloudant_sync_index_c as c, _t_cloudant_sync_index_d as d "
     "where a.docid = c.docid and a.docid = d.docid "
     "and ((a.value > ?) and (c.value > ?) and (d.value > ?))"
                  queryValues: @[@5, @6, @5]
              indexReferences: [NSSet setWithObjects:@"a", @"c", @"d", nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"a > 5 and c > 6 or d > 5"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
     "_t_cloudant_sync_index_c as c, _t_cloudant_sync_index_d as d "
     "where a.docid = c.docid and a.docid = d.docid "
     "and (((a.value > ?) and (c.value > ?)) or (d.value > ?))"
                  queryValues: @[@5, @6, @5]
              indexReferences: [NSSet setWithObjects:@"a", @"c", @"d", nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"not (a > 5 and c > 6 and d > 20)"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
     "_t_cloudant_sync_index_c as c, _t_cloudant_sync_index_d as d "
     "where a.docid = c.docid and a.docid = d.docid "
     "and ( not  ((a.value > ?) and (c.value > ?) and (d.value > ?)))"
                  queryValues: @[@5, @6, @20]
              indexReferences: [NSSet setWithObjects:@"a", @"c", @"d", nil]];
    
    [self buildAndVerifyQuery:[NSPredicate predicateWithFormat:@"not ((a > 5) and (c > 6)) or (d > 5)"]
                      options: nil
                          sql: @"select a.docid  from _t_cloudant_sync_index_a as a, "
     "_t_cloudant_sync_index_c as c, _t_cloudant_sync_index_d as d "
     "where a.docid = c.docid and a.docid = d.docid "
     "and (( not  ((a.value > ?) and (c.value > ?))) or (d.value > ?))"
                  queryValues: @[@5, @6, @5]
              indexReferences: [NSSet setWithObjects:@"a", @"c", @"d", nil]];
    
}


- (void) testInvalidPredicates
{
    
//    These are the predicates we currently do not support
     
//    NSMatchesPredicateOperatorType,
//    NSLikePredicateOperatorType,
//    NSBeginsWithPredicateOperatorType,
//    NSEndsWithPredicateOperatorType,
//    NSInPredicateOperatorType,
//    NSCustomSelectorPredicateOperatorType,
//    NSContainsPredicateOperatorType,
//    NSBetweenPredicateOperatorType

    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a matches '.*(CAT){3,}"
                                                                         "(?!CA).*'"]
                               options: nil
                             errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a like 'C' "]
                      options: nil
                     errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a beginsWith 'C' "]
                               options: nil
                             errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a endsWith 'C' "]
                               options: nil
                             errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a in %@ ", @[@1, @2, @3]]
                               options: nil
                             errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"C isKindOfClass:%@",
                                        [NSString class]]
                               options: nil
                             errorCode: CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a contains 'C' "]
                               options: nil
                             errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@"a between %@ ",
                                            @[@1, @10]]
                               options: nil
                             errorCode:CDTQueryBuilderErrorUnknownComparisonPredicateType];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@" c < d "]
                               options: nil
                             errorCode:CDTQueryBuilderErrorMultipleKeyInComparisonPredicate];
    
    [self buildAndVerifyPredicateError:[NSPredicate predicateWithFormat:@" 5 < 6 "]
                               options: nil
                             errorCode:CDTQueryBuilderErrorNoKeyInComparisonPredicate];
    
}


- (void) buildAndVerifyQuery: (NSPredicate*) predicate
                     options: (NSDictionary*) options
                         sql: (NSString*) sqlToVerify
                 queryValues: (NSArray*) valuesToVerify
             indexReferences: (NSSet*) indexReferencesToVerify
{
    NSError* error;
    CDTQueryBuilderResult* query = [CDTQueryBuilder buildWithPredicate: predicate
                                                               options: options
                                                                 error: &error];
    
    STAssertEqualObjects(query.sql, sqlToVerify, nil);
    STAssertEquals([query.values count], [valuesToVerify count], nil);
    STAssertEqualObjects(query.values, valuesToVerify, nil);
    STAssertEquals([query.usedIndexes count], [indexReferencesToVerify count], nil);
    STAssertEqualObjects(query.usedIndexes, indexReferencesToVerify, nil);
    
}

- (void) buildAndVerifyPredicateError:(NSPredicate*) predicate
                              options: (NSDictionary*) options
                            errorCode: (NSInteger) codeToVerify
{
    NSError* error;
    CDTQueryBuilderResult* query = [CDTQueryBuilder
                                    buildWithPredicate: predicate
                                    options: options
                                    error: &error];
    
    STAssertTrue(query.sql == nil, nil);
    STAssertTrue([error code] == codeToVerify, nil);
    
}

- (void)testQuerySomeDocuments
{
    NSError *error = nil;
    
    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];
    
    // create some docs
    int nDocs = 1000;
    while(nDocs--) {
        NSNumber* value = [NSNumber numberWithInteger: nDocs];
        CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
        rev.body = @{
                     @"name": @"tom",
                     @"field": value
                    };
        [self.datastore createDocumentFromRevision:rev error:&error];
    }
    nDocs = 1000;
    while(nDocs--) {
        NSNumber* value = [NSNumber numberWithInteger: nDocs];
        CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
        rev.body = @{
                     @"name": @"mary",
                     @"field": value
                    };
        [self.datastore createDocumentFromRevision:rev  error:&error];
    }
    
    BOOL ok = [im ensureIndexedWithIndexName:@"name" fieldName:@"name" error:&error];
    STAssertTrue(ok, @"ensureIndexedWithIndexName did not return true");
    
    ok = [im ensureIndexedWithIndexName: @"field"
                              fieldName: @"field"
                                   type: CDTIndexTypeInteger error:&error];
    STAssertTrue(ok, @"ensureIndexedWithIndexName did not return true");
  
    CDTQueryResult* result = [im
                              queryWithPredicate: [NSPredicate predicateWithFormat:@"name = 'tom'"]
                                         options: nil error:&error];
    STAssertTrue(result != nil, @"Result shouldn't be nil");
    STAssertTrue([[result documentIds] count] == 1000,
                 @"Should have 1000 records with name = 'tom'");
  
    result = [im queryWithPredicate: [NSPredicate predicateWithFormat:@"field = 5" ]
                            options: nil
                              error: &error];
    STAssertTrue([[result documentIds] count]==2, @"Should have two records with field value 5");
    
    result = [im
              queryWithPredicate:
                [NSPredicate predicateWithFormat:@"(field = 5) and (name = 'tom')" ]
                           error: &error];
    STAssertTrue([[result documentIds] count]==1,
                 @"Should have one record with field value 5 and name = 'tom'");
    
    // use the convenience method without providing an options
    result = [im
              queryWithPredicate: [NSPredicate predicateWithFormat:@"(field = 5) or (name = 'tom')"]
                         options: nil
                           error: &error];
    STAssertTrue([[result documentIds] count]==1001,
                 @"Should have 1001 records with field value 5 or name = 'tom' "
                  "(all tom plus one mary)");
    
    NSMutableDictionary* options = [@{kCDTQueryOptionSortBy: @"field",
                                      kCDTQueryOptionAscending: @"asc"} mutableCopy];
    result = [im queryWithPredicate:
              [NSPredicate predicateWithFormat:@"(field < 50) and (name = 'tom')" ]
                            options: options
                              error: &error];
    STAssertTrue([[result documentIds] count]==50,
                 @"Should have 50 (0 to 49) records with field value <50 and name = 'tom'");
    
    // I set offset without a limit first since the SQL Lite syntax requires a limit setting
    // for offset
    // only specification as well. Testing that.
    [options setObject: [[NSNumber alloc]initWithInteger:10] forKey:kCDTQueryOptionOffset];
    result = [im queryWithPredicate:
              [NSPredicate predicateWithFormat:@"(field < 50) and (name = 'tom')" ]
                            options: options
                              error: &error];
    STAssertTrue([[result documentIds] count]==40,
                 @"Should have 40 (skip 1st 10) records with field value <50 and name = 'tom'");
    
    // Now put the limit in as well
    [options setObject: [[NSNumber alloc]initWithInteger:10] forKey:kCDTQueryOptionLimit];
    result = [im
              queryWithPredicate:
                [NSPredicate predicateWithFormat:@"(field < 50) and (name = 'tom')" ]
                                         options: options
                                           error: &error];
    STAssertTrue([[result documentIds] count]==10,
                 @"Should have 10 (limit to 10) records with field value <50 and name = 'tom'");
    
    // check sort results
    NSMutableArray *queryResults = [NSMutableArray array];
    for(CDTDocumentRevision *revision in result) {
        NSDictionary *object = [revision body];
        [queryResults addObject:object];
    }
    STAssertTrue(([[[queryResults firstObject] objectForKey:@"field"] integerValue] == 10),
                 @"1st obj should be 10");
    
    STAssertTrue(([[[queryResults lastObject] objectForKey:@"field"] integerValue] == 19),
                 @"last obj should be 19");
    
}

- (void) testInvalidIndexes
{
    NSError *error = nil;
    
    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&error];
    
    // try it with an index that does not exist
    CDTQueryResult* result = [im
                              queryWithPredicate: [NSPredicate predicateWithFormat:@"foo = 'tom'"]
                                         options: nil
                                           error: &error];
    STAssertNil(result, @"Result should be nil since the index does not exist");
    STAssertNotNil(error, @"Error should be populated with the right message");
    STAssertTrue([error code] == CDTIndexErrorIndexDoesNotExist, @"Error should be Index does not "
                 "exist");
    
    // try it with an index name that isn't valid
    result = [im
                queryWithPredicate: [NSPredicate predicateWithFormat:@"_foo = 'tom'"]
                           options: nil
                             error: &error];
    STAssertNil(result, @"Result should be nil since the index does not exist");
    STAssertNotNil(error, @"Error should be populated with the right message");
    STAssertTrue([error code] == CDTIndexErrorInvalidIndexName, @"Error should be Index name is "
                 "invalid");
    
}

@end