//
//  CDTQQueryMatcher.h
//  CloudantQueryObjc
//
//  Created by Rhys Short on 21/01/2015.
//  Copyright (c) 2015 IBM Corp. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Expecta.h"

/**
 *  Determines if two raw cloudant queries are the same
 *
 */
EXPMatcherInterface(beTheSameQueryAs, (NSDictionary * expected));


