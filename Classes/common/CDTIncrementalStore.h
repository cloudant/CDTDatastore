//
//  CDTIncrementalStore.h
//
//
//  Created by Jimi Xenidis on 11/18/14.
//
//

#import <CoreData/CoreData.h>
#import <CloudantSync.h>

extern NSString *const CDTISErrorDomain;
extern NSString *const CDTISException;

/**
 *  Block of code to be executed as communication with backing store progresses.
 *
 *  @param end       YES: communication is finished.
 *                   NO: communication has ended.
 *  @param processed Number of backing store transactions processed
 *  @param total     Total number of transactions to be completed
 *  @param err       Optional error if `end` is `YES`
 */
typedef void (^CDTISProgressBlock)(BOOL end, NSInteger processed, NSInteger total, NSError *err);

typedef NS_ENUM(NSInteger, CDTISReplicateDirection) {
    push = 0,
    pull = 1
};

@interface CDTIncrementalStore : NSIncrementalStore

@property (nonatomic, strong) CDTDatastore *datastore;

- (NSInteger)propertyTypeFromDoc:(NSDictionary *)body withName:(NSString *)name;

/**
*  Cause the store to push to the remote database
*  > *Note*: does not block
*
*  @param error    Error if push could not be initiated
*  @param progress @See CDTISProgressBlock
*
*  @return YES/NO with optional error
*/
- (BOOL)pushToRemote:(NSError **)error withProgress:(CDTISProgressBlock)progress;

/**
 *  Cause the store to pull from the remote database
 *  > *Note*: does not block
 *
 *  @param error    Error if push could not be initiated
 *  @param progress @See CDTISProgressBlock
 *
 *  @return YES/NO with optional error
 */
- (BOOL)pullFromRemote:(NSError **)error withProgress:(CDTISProgressBlock)progress;

/**
 *  Convenience function where direction is an argument.
 *  Use this when you find that the `progress` block is the same for push and
 *  pull.
 *
 *  @param direction Which direction should the replication be done in
 *  @param error     Error if replication could not be initiated
 *  @param progress  @See CDTISProgressBlock
 *
 *  @return YES/NO with optional error
 */
- (BOOL)replicateInDirection:(CDTISReplicateDirection)direction withError:(NSError **)error withProgress:(CDTISProgressBlock)progress;

/**
 *  Define the remote backing store of an existing datastore
 *
 *  @param remoteURL URL to database
 */
- (BOOL)linkReplicators:(NSURL *)remoteURL;

/**
 *  Unlink the backing stores
 */
- (void)unlinkReplicators;

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

/**
 *  Returns an array of @ref CDTIncrementalStore objects associated with a
 *  @ref NSPersistentStoreCoordinator
 *
 *  @param coordinator The coordinator
 *
 *  @return the array
 */
+ (NSArray *)storesFromCoordinator:(NSPersistentStoreCoordinator *)coordinator;

/**
 *  The databaseName is exposed in order to be able to identify the different
 *  CDTIncrementalStore objects. @see +storesFromCoordinator:coordinator
 */
@property (nonatomic, strong) NSString *databaseName;


typedef NS_ENUM(NSInteger, CDTIncrementalStoreErrors) {
    CDTISErrorBadURL = 1,
    CDTISErrorBadPath,
    CDTISErrorNilObject,
    CDTISErrorUndefinedAttributeType,
    CDTISErrorObjectIDAttributeType,
    CDTISErrorNaN,
    CDTISErrorRevisionIDMismatch,
    CDTISErrorExectueRequestTypeUnkown,
    CDTISErrorExectueRequestFetchTypeUnkown,
    CDTISErrorMetaDataMismatch,
    CDTISErrorNoRemoteDB,
    CDTISErrorSyncBusy,
    CDTISErrorNotSupported
};

@end
