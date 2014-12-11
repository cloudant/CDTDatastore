//
//  CDTIncrementalStore.h
//
//
//  Created by Jimi Xenidis on 11/18/14.
//
//

#import <CoreData/CoreData.h>
#import <CloudantSync.h>

extern NSString *const kCDTISErrorDomain;
extern NSString *const kCDTISException;

@interface CDTIncrementalStore : NSIncrementalStore

/**
 *  Returns the string that was used to register this incremental store
 *
 *  @return NSString
 */
+ (NSString *)type;

/**
 *  Returns URL to the local directory that the incremental databases shall be
 *  stored.
 *
 *  @return NSURL
 */
+ (NSURL *)localDir;

@end
