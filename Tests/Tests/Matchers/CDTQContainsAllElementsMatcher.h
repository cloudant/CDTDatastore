//
//  CDTQContainsAllElementsMatcher.h
//  CloudantQueryObjc
//
//  Created by Rhys Short on 21/01/2015.
//  Copyright (c) 2015 IBM Corp. All rights reserved.
//

#ifndef CloudantQueryObjc_CDTQContainsAllElementsMatcher_h
#define CloudantQueryObjc_CDTQContainsAllElementsMatcher_h

#import "Expecta.h"

/**
 * Determines if an Array contains all the specified array,
 * this does not take account of the ordering of elements.
 *
 */
EXPMatcherInterface(containsAllElements, (NSArray * expected));

#define containAllElements containsAllElements

#endif
