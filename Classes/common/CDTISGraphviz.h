//
//  CDTISGraphviz.h
//
//
//  Created by Jimi Xenidis on 2/14/15.
//
//

#import <CoreData/CoreData.h>
#import <CloudantSync.h>
#import "CDTIncrementalStore.h"

/**
 *  CDTISGraphviz creates a graph representation of the datastore using the
 *  [Graphviz](http://www.graphviz.org/) "dot" format.
 *  See the Graphviz docuementation on how to display the output.
 */

@interface CDTISGraphviz : NSObject

- (instancetype)initWithIncrementalStore:(CDTIncrementalStore *)is;

/**
 *  Actually create the "dot" output in memory
 *
 *  @return `YES` on success, `NO` on failure
 */
- (BOOL)dotMe;

/**
 *  Creates a string that is a debugger commance so the memory image
 *  can be dumped to a file
 *
 *  > *Warning*: this replaces contents of an existing file but does not
 *  > truncate it. So if the original file was bigger there will be garbage
 *  > at the end.
 *
 *  @param path File path to use
 *
 *  @return the string or `nil` on failure
 */
- (NSString *)extractLLDB:(NSString *)path;

@end
