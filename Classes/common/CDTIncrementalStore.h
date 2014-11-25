//
//  CDTIncrementalStore.h
//  
//
//  Created by Jimi Xenidis on 11/18/14.
//
//

#import <CoreData/CoreData.h>
#import <CloudantSync.h>

extern NSString* const CDTIncrementalStoreErrorDomain;

@interface CDTIncrementalStore : NSIncrementalStore

+ (NSString *)type;

@end

