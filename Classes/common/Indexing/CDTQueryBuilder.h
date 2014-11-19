//
//  CDTQueryBuilder.h
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

extern NSString *const CDTQueryBuilderErrorDomain;

@interface CDTQueryBuilderResult : NSObject

/**
 The SQL query, including placeholder marks, to use for querying.
 */
@property NSString *sql;

/**
 The placeholder values associated with `sql`.
 */
@property NSArray *values;

/**
 The indexes used in this query, provided so they can be validated prior to
 running the query.
 */
@property NSSet *usedIndexes;

@end

@interface CDTQueryBuilder : NSObject

/**
 * Error Codes
 */
typedef NS_ENUM(NSInteger, CDTQueryBuilderError) {
    /**
     * NSPredicate subclasses is not supported by us.
     * We only support NSCompoundPredicate and NSComparisonPredicate
     */
    CDTQueryBuilderErrorUnknownPredicateType = 1,
    /**
     * For NSComparisonPredicates, we only support
     *  >, >=, <, <=, =, !=
     */
    CDTQueryBuilderErrorUnknownComparisonPredicateType = 2,
    /**
     * NSComparisonPredicate can have key expression on both sides,
     * we can only support key on one side and a constant on the other side
     */
    CDTQueryBuilderErrorMultipleKeyInComparisonPredicate = 3,
    /**
     * We only support CompoundPredicates with types: and, or, not
     */
    CDTQueryBuilderErrorUnknownCompoundPredicateType = 4,
    /**
     * The Comparison predicate must contain one key
     */
    CDTQueryBuilderErrorNoKeyInComparisonPredicate = 5
};

/**
 Builds a sql and parameter values for querying the local Cloudant Database

 @param predicate NSPredicate to bulid the query
 @param options   Query options
 @param error     Error object to hold any errors
 @return an object containing the SQL, placeholder values and used indexes for this predicate
 */
+ (CDTQueryBuilderResult *)buildWithPredicate:(NSPredicate *)predicate
                                      options:(NSDictionary *)options
                                        error:(NSError *__autoreleasing *)error;

@end
