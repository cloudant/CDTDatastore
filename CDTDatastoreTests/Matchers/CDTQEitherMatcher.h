//
//  CDTQEitherMatcher.h
//  CloudantQueryObjc
//
//  Created by Rhys Short on 21/01/2015.
//  Copyright (c) 2015 IBM Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Expecta.h"

/**
 * Determines if the value matches either values.
 *
 */
EXPMatcherInterface(isEqualToEither, (id expected,id otherExpected))

#define isEither
