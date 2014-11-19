//
//  CDTQueryBuilder.m
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

#import "CDTQueryBuilder.h"
#import "CDTIndexManager.h"

@implementation CDTQueryBuilderResult
// empty as it's a pure property based object for the results of buildWithPredicate:options:error:
@end

/**
 A class to process NSPredicate expressions into SQL for use in CDTDatastore's indexing
 implementation.

 An NSPredicate can be of either NSCompoundPredicate or NSComparisonPredicate.

 ## NSCompoundPredicate

 NSCompoundPredicate is used to create an AND or OR evaluative relationship between a group of
 sub-predicates. It can also be used to negate a single sub-predicate.

 An AND or OR NSCompoundPredicate needs to be translated into a bracketed set of WHERE clauses
 in SQL, joined with AND or OR as needed.

 A NOT NSCompoundPredicate needs to prepend NOT to its sub-predicated SQL representation.

 ## NSComparisonPredicate

 NSComparisonPredicate is used to compare the results of two expressions, returning YES/NO based
 on the comparison result.

 ## NSExpression

 An expression evaluates to a value.

 */
@implementation CDTQueryBuilder

static NSString* const kCDTIndexTablePrefix = @"_t_cloudant_sync_index_";
NSString* const CDTQueryBuilderErrorDomain = @"CDTQueryBuilderErrorDomain";

#pragma mark - SQL Building

/**
 Builds a sql and parameter values for querying the local Cloudant Database

 @param predicate NSPredicate to bulid the query
 @param options   Query options
 @param error     Error object to hold any errors
 @return a dictionary object with two keys: @"sql" and @"queryValues"
 @"sql" stores the generated SQL for querying the sqlite database.
 @"queryValues" stores the values for the parameters in sql
 @"indexReferences" stores an array of index references
 nil if an error is encountered. The error object will be populated
 */
+ (CDTQueryBuilderResult*)buildWithPredicate:(NSPredicate*)predicate
                                     options:(NSDictionary*)options
                                       error:(NSError* __autoreleasing*)error
{
    NSMutableString* sqlQuery = [NSMutableString string];

    NSString* selectClause = [self buildSelectClauseFromPredicate:predicate error:error];
    if (selectClause == nil) {
        return nil;
    } else {
        [sqlQuery appendString:selectClause];
    }

    NSString* sortColumn = [options objectForKey:kCDTQueryOptionSortBy];
    NSMutableSet* indexReferences = [NSMutableSet set];
    NSString* fromClause = [self buildFromClauseFromPredicate:predicate
                                       extractIndexReferences:indexReferences
                                                   sortColumn:sortColumn
                                                        error:error];

    if (fromClause == nil) {
        return nil;
    } else {
        [sqlQuery appendString:fromClause];
    }

    NSMutableArray* queryValues = [NSMutableArray array];
    NSString* whereClause = [self buildWhereClauseFromPredicate:predicate
                                             extractQueryValues:queryValues
                                                     sortColumn:sortColumn
                                                          error:error];
    if (whereClause == nil) {
        return nil;
    } else {
        [sqlQuery appendString:whereClause];
    }

    [sqlQuery appendString:[self buildOrderByClauseFromOptions:options]];

    if ([options objectForKey:kCDTQueryOptionLimit]) {
        int limitCount = [[options objectForKey:kCDTQueryOptionLimit] intValue];
        [sqlQuery appendString:[NSString stringWithFormat:@(" limit %d "), limitCount]];
    }

    if ([options objectForKey:kCDTQueryOptionOffset]) {
        int offset = [[options objectForKey:kCDTQueryOptionOffset] intValue];
        if ([options objectForKey:kCDTQueryOptionLimit] == nil) {  // if limit is not specified
                                                                   // but offset is,
            // need to put a limit there as -1
            [sqlQuery appendString:[NSString stringWithFormat:@" limit -1 "]];
        }
        [sqlQuery appendString:[NSString stringWithFormat:@(" offset %d "), offset]];
    }

    CDTQueryBuilderResult* result = [[CDTQueryBuilderResult alloc] init];
    result.sql = sqlQuery;
    result.values = queryValues;
    result.usedIndexes = indexReferences;
    return result;
}

/**
 Builds a select clause from the predicate.

 To be predicatable, we return the lexographicly first index from the set of index names for
 use in the select clause; any would do, however.

 @param predicate NSPredicate to build the select clause
 @param error error object ptr to hold the error obj created if an error occurs
 @return the select clause or nil if an error is encountered
 */

+ (NSString*)buildSelectClauseFromPredicate:(NSPredicate*)predicate
                                      error:(NSError* __autoreleasing*)error
{
    NSMutableSet* keySet = [NSMutableSet set];
    bool success = [self accumulateKeysIntoSet:keySet fromPredicate:predicate error:error];
    if (!success) {
        return nil;
    }
    return [NSString stringWithFormat:@"select %@.docid ", [self firstKeyFromSet:keySet]];
}

+ (NSString*)firstKeyFromSet:(NSSet*)keySet
{
    NSArray* allKeys = [keySet allObjects];
    allKeys = [allKeys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        return [((NSString*)a)caseInsensitiveCompare:(NSString*)b];
    }];
    return (NSString*)allKeys[0];
}

/**
 Builds a From clause from the predicate

 @param predicate           NSPredicate to build the from clause
 @param extractIndexRefrences         Output parameter to hold all Index references
 @param sortColumn          sort column will be added to the From clause if not nil
 @param error               error object pointer to hold the error returned
 @return from clause or nil if an error is encountered
 */
+ (NSString*)buildFromClauseFromPredicate:(NSPredicate*)predicate
                   extractIndexReferences:indexReferences
                               sortColumn:(NSString*)sortColumn
                                    error:(NSError* __autoreleasing*)error
{
    NSMutableSet* keySet = [NSMutableSet set];
    bool success = [self accumulateKeysIntoSet:keySet fromPredicate:predicate error:error];
    if (!success) {
        return nil;
    }
    if (sortColumn != nil) {
        if (![keySet containsObject:sortColumn]) {
            [keySet addObject:sortColumn];
        }
    }

    NSMutableArray* subclauses = [NSMutableArray array];
    for (NSString* table in keySet) {
        NSString* subclause =
            [NSString stringWithFormat:@"%@%@ as %@", kCDTIndexTablePrefix, table, table];
        [subclauses addObject:subclause];
        // also add this table as a referenced index into the output parameter
        [indexReferences addObject:table];
    }

    NSMutableString* fromClause = [NSMutableString string];
    [fromClause appendString:@" from "];
    [fromClause appendString:[subclauses componentsJoinedByString:@", "]];
    return fromClause;
}

/**
 Builds a where clause from the predicate

 @param predicate           NSPredicate to build the from clause
 @param extractQueryValues  Output parameter to hold all the values for the parameter markers
 @param sortColumn          sort column will be added to the where clause if not nil
 @param error               error object pointer to hold the error returned
 @return where clase or nil if an error is encountered
 */
+ (NSString*)buildWhereClauseFromPredicate:(NSPredicate*)predicate
                        extractQueryValues:(NSMutableArray*)queryValues
                                sortColumn:(NSString*)sortColumn
                                     error:(NSError* __autoreleasing*)error
{
    // Find all the keys referened by the query predicates
    NSMutableSet* keySet = [NSMutableSet set];
    bool success = [self accumulateKeysIntoSet:keySet fromPredicate:predicate error:error];
    if (!success) {
        return nil;
    }

    // If there is a sort column, make sure we reference that in the join
    if (sortColumn && ![keySet containsObject:sortColumn]) {
        [keySet addObject:sortColumn];
    }

    // Accumulate sub-where clauses for later joining
    NSMutableArray* subclauses = [NSMutableArray array];

    // Each index is its own table and have a docid column
    // First part of the where clause are all equi-joins to tie everyone to the same docid
    // This is the where clause which restricts doc ID equality to perform the intersection
    NSEnumerator* enumerator = [keySet objectEnumerator];
    NSString* firstTable = [enumerator nextObject];
    NSString* table;
    while ((table = [enumerator nextObject]) != nil) {
        NSString* subclause = [NSString stringWithFormat:@"%@.docid = %@.docid", firstTable, table];
        [subclauses addObject:subclause];
    }

    // Second part of the where clause are the predicates (e.g., a.value > ?)
    NSString* sqlFragment =
        [self toSQLFragmentWithPredicate:predicate extractQueryValues:queryValues error:error];
    if (sqlFragment == nil) {
        return nil;  // error occured in processing predicates
    }
    [subclauses addObject:sqlFragment];

    NSMutableString* whereClause = [NSMutableString string];
    [whereClause appendString:@" where "];
    [whereClause appendString:[subclauses componentsJoinedByString:@" and "]];
    return whereClause;
}

/**
 Builds an orderBy clause from the predicate

 @param predicate           NSPredicate to build the from clause
 @param extractQueryValues  Output parameter to hold all the values for the parameter markers
 @param sortColumn          sort column will be added to the where clause if not nil
 @param error               error object pointer to hold the error returned
 @return orderByClause or an empty string if not needed
 */
+ (NSString*)buildOrderByClauseFromOptions:(NSDictionary*)options
{
    NSString* orderByClause = @"";  // by default, no specific ordering

    if (options) {
        NSString* sortColumn = sortColumn = [options objectForKey:kCDTQueryOptionSortBy];
        if (sortColumn) {
            bool ascending = YES;
            if ([options objectForKey:kCDTQueryOptionAscending]) {
                ascending = YES;
            } else if ([options objectForKey:kCDTQueryOptionDescending]) {
                ascending = NO;
            }

            if (ascending) {
                orderByClause = [NSString stringWithFormat:@" order by %@.value asc ", sortColumn];
            } else {
                orderByClause = [NSString stringWithFormat:@" order by %@.value desc ", sortColumn];
            }
        }
    }

    return orderByClause;
}

#pragma mark - NSPredicate Handling

/**
 Generate a SQL fragment based on the NSPredicate
 @param predicate   NSPredicate to generate the SQL Fragment
 @param queryValues Output parameter holding the query values for the parameter markers
 @param error       Error output object
 @return sql fragment for the NSPredicate or nil if an error is encountered
 */
+ (NSString*)toSQLFragmentWithPredicate:(NSPredicate*)predicate
                     extractQueryValues:(NSMutableArray*)queryValues
                                  error:(NSError* __autoreleasing*)error
{
    if ([predicate isKindOfClass:([NSCompoundPredicate class])]) {
        return [self toSQLFragmentWithCompoundPredicate:(NSCompoundPredicate*)predicate
                                     extractQueryValues:queryValues
                                                  error:error];
    } else if ([predicate isKindOfClass:([NSComparisonPredicate class])]) {
        return [self toSQLFragmentWithKeyValuePredicate:(NSComparisonPredicate*)predicate
                                     extractQueryValues:queryValues
                                                  error:error];
    } else {
        NSDictionary* ui = @{
            NSLocalizedDescriptionKey : @"Unsupported Predicate class",
            NSLocalizedRecoverySuggestionErrorKey :
                @"Use NSCompound Predicate or NSComparisonPredicate",
            NSLocalizedFailureReasonErrorKey :
                [NSString stringWithFormat:@"Predicate class %@ is not supported",
                                           NSStringFromClass([predicate class])]
        };
        *error = [NSError errorWithDomain:CDTQueryBuilderErrorDomain
                                     code:CDTQueryBuilderErrorUnknownPredicateType
                                 userInfo:ui];
        return nil;
    }
}

/**
 Get all key references from NSPredicates
 @param keySet Output parameter to hold all the key references
 @param predicate NSPredicate to get the key references from
 @param error Error ptr to hold the error object
 @return bool true if success or false if failure
 */
+ (bool)accumulateKeysIntoSet:(NSMutableSet*)keySet
                fromPredicate:(NSPredicate*)predicate
                        error:(NSError* __autoreleasing*)error
{
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        return [self accumulateKeysIntoSet:keySet
                     fromCompoundPredicate:(NSCompoundPredicate*)predicate
                                     error:error];
    } else if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        return [self accumulateKeysIntoSet:keySet
                   fromComparisonPredicate:(NSComparisonPredicate*)predicate
                                     error:error];
    } else {
        NSDictionary* ui = @{
            NSLocalizedDescriptionKey : @"Unsupported Predicate class",
            NSLocalizedRecoverySuggestionErrorKey :
                @"Use NSCompound Predicate or NSComparisonPredicate",
            NSLocalizedFailureReasonErrorKey :
                [NSString stringWithFormat:@"Predicate class %@ is not supported",
                                           NSStringFromClass([predicate class])]
        };
        *error = [NSError errorWithDomain:CDTQueryBuilderErrorDomain
                                     code:CDTQueryBuilderErrorUnknownPredicateType
                                 userInfo:ui];

        return false;
    }
}

#pragma mark - NSComparisonPredicate Handling

/**
 Generate a SQL fragment based on the NSComparisonPredicate
 @param predicate   NSComparisonPredicate to generate the SQL Fragment
 @param queryValues Output parameter to hold the query values for the parameter markers
 @param error       Error output object
 @return sql fragment for the NSPredicate or nil if an error is encountered
 */
+ (NSString*)toSQLFragmentWithKeyValuePredicate:(NSComparisonPredicate*)comparisonPredicate
                             extractQueryValues:(NSMutableArray*)queryValues
                                          error:(NSError* __autoreleasing*)error
{
    NSDictionary* keyValue =
        [self getKeyValueFromComparisonPredicate:comparisonPredicate error:error];
    if (keyValue == nil) {
        return nil;  // error with processing the comparison predicate
    }

    NSString* operator= @"";
    switch ([comparisonPredicate predicateOperatorType]) {
        case NSLessThanPredicateOperatorType:
            operator= @"<";
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            operator= @"<=";
            break;
        case NSGreaterThanPredicateOperatorType:
            operator= @">";
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            operator= @">=";
            break;
        case NSEqualToPredicateOperatorType:
            operator= @"=";
            break;
        case NSNotEqualToPredicateOperatorType:
            operator= @"!=";
            break;
        default: {
            NSDictionary* ui = @{
                NSLocalizedDescriptionKey : @"Unsupported predicate operator type",
                NSLocalizedRecoverySuggestionErrorKey :
                    @"Use supported predicate operator: <, <=, >, >=, = or !=",
                NSLocalizedFailureReasonErrorKey : @"Predicate operator type is not supported"
            };
            *error = [NSError errorWithDomain:CDTQueryBuilderErrorDomain
                                         code:CDTQueryBuilderErrorUnknownComparisonPredicateType
                                     userInfo:ui];
        }
            return nil;
    }

    NSObject* value = [keyValue objectForKey:@"value"];
    NSObject* key = [keyValue objectForKey:@"key"];

    // string is in this form (indexA.value > ?)
    NSString* string = [NSString stringWithFormat: @"(%@.value %@ ?)",
                        key, operator];
    [queryValues addObject:value];
    return string;
}

/**
 Get all key/value information from NSComparisonPredicates
 @param predicate NSComparisonPredicate to get the key references from
 @param error Error ptr to hold the error object
 @return NSDictonary with two keys: @"key" and @"value" or nil if failure
 */
+ (NSDictionary*)getKeyValueFromComparisonPredicate:(NSComparisonPredicate*)comparisonPredicate
                                              error:(NSError* __autoreleasing*)error
{
    NSDictionary* keyValue = nil;

    NSExpression* lhs = [comparisonPredicate leftExpression];
    NSExpression* rhs = [comparisonPredicate rightExpression];

    if ([lhs expressionType] == NSKeyPathExpressionType) {
        if ([rhs expressionType] == NSKeyPathExpressionType) {
            *error = [NSError
                errorWithDomain:CDTQueryBuilderErrorDomain
                           code:CDTQueryBuilderErrorMultipleKeyInComparisonPredicate
                       userInfo:@{
                           NSLocalizedDescriptionKey :
                               @"Multiple keys specified in a NSComparisonPredicate",
                           NSLocalizedRecoverySuggestionErrorKey :
                               @"Use only one key in NSComparisonPredicate",
                           NSLocalizedFailureReasonErrorKey : [NSString
                               stringWithFormat:@"%@ %@ are both keys in an NSComparisonPredicate",
                                                lhs, rhs]
                       }];
            ;
        } else {
            keyValue = @{
                @"key" : [lhs keyPath],
                @"value" : [rhs expressionValueWithObject:nil context:nil]
            };
        }
    } else if ([rhs expressionType] == NSKeyPathExpressionType) {
        keyValue = @{
            @"key" : [rhs keyPath],
            @"value" : [lhs expressionValueWithObject:nil context:nil]
        };
    } else {
        *error = [NSError
            errorWithDomain:CDTQueryBuilderErrorDomain
                       code:CDTQueryBuilderErrorNoKeyInComparisonPredicate
                   userInfo:@{
                       NSLocalizedDescriptionKey : @"No key specified in a NSComparisonPredicate",
                       NSLocalizedRecoverySuggestionErrorKey :
                           @"Use one key in NSComparisonPredicate",
                       NSLocalizedFailureReasonErrorKey : [NSString
                           stringWithFormat:@"%@ %@ are not keys in an NSComparisonPredicate", lhs,
                                            rhs]
                   }];
        ;
    }
    return keyValue;
}

/**
 Get all key references from NSComparisonPredicates
 @param keySet Output parameter to hold all the key references
 @param predicate NSComparisonPredicate to get the key references from
 @param error Error ptr to hold the error object
 @return bool true if success or false if failure
 */
+ (bool)accumulateKeysIntoSet:(NSMutableSet*)keyReferences
      fromComparisonPredicate:(NSComparisonPredicate*)predicate
                        error:(NSError* __autoreleasing*)error
{
    NSDictionary* keyValue = [self getKeyValueFromComparisonPredicate:predicate error:error];
    if (keyValue == nil) {
        return false;  // can't get key out of the comparison predicate;
                       // error obj is populated by getKeyFromComparisonPredicate
    } else {
        [keyReferences addObject:[keyValue objectForKey:@"key"]];
        return true;
    }
}

#pragma mark - NSCompoundPredicate Handling

/**
 Generate a SQL fragment based on the NSCompoundPredicate
 @param predicate   NSCompoundPredicate to generate the SQL Fragment
 @param queryValues Output parameter to hold the query values for the parameter markers
 @param error       Error output object
 @return sql fragment for the NSPredicate or nil if an error is encountered
 */
+ (NSString*)toSQLFragmentWithCompoundPredicate:(NSCompoundPredicate*)compoundPredicate
                             extractQueryValues:(NSMutableArray*)queryValues
                                          error:(NSError* __autoreleasing*)error
{
    NSMutableString* string = [[NSMutableString alloc] init];
    [string appendString:@"("];

    bool success = NO;
    switch ([compoundPredicate compoundPredicateType]) {
        case NSAndPredicateType:
            success = [self generateClause:string
                      forCompoundPredicate:compoundPredicate
                              withOperator:@" and "
                        extractQueryValues:queryValues
                                     error:error];
            break;
        case NSOrPredicateType:
            success = [self generateClause:string
                      forCompoundPredicate:compoundPredicate
                              withOperator:@" or "
                        extractQueryValues:queryValues
                                     error:error];
            break;
        case NSNotPredicateType:
            success = [self generateClause:string
                      forCompoundPredicate:compoundPredicate
                              withOperator:@" not "
                        extractQueryValues:queryValues
                                     error:error];
            break;
        default:
            *error = [NSError
                errorWithDomain:CDTQueryBuilderErrorDomain
                           code:CDTQueryBuilderErrorUnknownCompoundPredicateType
                       userInfo:@{
                           NSLocalizedDescriptionKey : @"Unsupported NSCompoundPredicate type",
                           NSLocalizedRecoverySuggestionErrorKey : @"Use NSCompoundPredicate types "
                                                                   @"NSAndPredicateType, "
                                                                   @"NSOrPredicateType or "
                                                                    "NSNotPredicateType",
                           NSLocalizedFailureReasonErrorKey :
                               @"Unsupported NSCompoundPredicate type"
                       }];
            success = NO;
    }

    if (!success) {
        return nil;  // failed to generate clause
    }

    [string appendString:@")"];
    return string;
}

/**
 Generate a SQL clause for the NSCompoundPredicate
 @param predicate NSCompoundPredicate to generate the clause from
 @param queryValues Output parameter to hold values for the parameter markers
 @param error Error ptr to hold the error object
 @return NSDictonary with two keys: @"key" and @"value" or nil if failure
 */
+ (bool)generateClause:(NSMutableString*)string
    forCompoundPredicate:(NSCompoundPredicate*)compoundPredicate
            withOperator:(NSString*) operator
      extractQueryValues:(NSMutableArray*)queryValues
                   error:(NSError* __autoreleasing*)error
{
    if ([operator isEqualToString: @" not "]) { // Negation predicate handling
        NSPredicate* predicate = [[compoundPredicate subpredicates] firstObject];
        NSString* clause =
            [self toSQLFragmentWithPredicate:predicate extractQueryValues:queryValues error:error];
        if (clause != nil) {
            [string appendString: [NSString stringWithFormat: @"%@ %@", operator, clause]];
        } else {
            return NO;
        }
    } else {
        NSMutableArray* subclauses = [NSMutableArray array];
        for (NSPredicate* predicate in [compoundPredicate subpredicates]) {
            NSString* clause = [self toSQLFragmentWithPredicate:predicate
                                             extractQueryValues:queryValues
                                                          error:error];
            if (clause != nil) {
                [subclauses addObject:clause];
            } else {
                return NO;
            }
        }
        [string appendString:[subclauses componentsJoinedByString:operator]];
    }
    return YES;
}

/**
 Get all key references from NSCompoundPredicates
 @param keySet Output parameter to hold all the key references
 @param predicate NSCompoundPredicate to get the key references from
 @param error Error ptr to hold the error object
 @return bool true if success or false if failure
 */
+ (bool)accumulateKeysIntoSet:(NSMutableSet*)keyReferences
        fromCompoundPredicate:(NSCompoundPredicate*)compoundPredicate
                        error:(NSError* __autoreleasing*)error
{
    for (NSPredicate* subpredicate in [compoundPredicate subpredicates]) {
        bool success =
            [self accumulateKeysIntoSet:keyReferences fromPredicate:subpredicate error:error];
        if (!success) {
            return NO;  // early termination if we get an error
        }
    }
    return YES;  // success
}

@end
