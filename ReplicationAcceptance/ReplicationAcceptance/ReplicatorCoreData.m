//
//  ReplicatorCoreData.m
//  ReplicationAcceptance
//
//  Created by Jimi Xenidis on 12/19/14.
//
//

#import <CoreData/CoreData.h>
#import <UNIRest.h>

#import "ReplicatorCoreData.h"
#import "CDTIncrementalStore.h"

@interface ReplicatorCoreData ()

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong) NSURL *storeURL;
@property (nonatomic, strong) NSString *primaryRemoteDatabaseName;

@end

/**
 *  Create a CoreData Managed Object Model for testing
 */

@interface Entry : NSManagedObject
@property (nonatomic, retain) NSNumber *number;
@property (nonatomic, retain) NSString *string;
@property (nonatomic, retain) NSSet *stuff;
@end

@class Stuff;

@interface Entry (CoreDataGeneratedAccessors)
- (void)addStuffObject:(Stuff *)value;
- (void)removeStuffObject:(Stuff *)value;
- (void)addStuff:(NSSet *)values;
- (void)removeStuff:(NSSet *)values;
@end

@interface Stuff : NSManagedObject
@property (nonatomic, retain) NSNumber *size;
@property (nonatomic, retain) NSString *data;
@property (nonatomic, retain) Entry *entry;
@end

NSAttributeDescription *MakeAttribute(NSString *name, BOOL optional, NSAttributeType type,
                                      id defaultValue)
{
    NSAttributeDescription *attribute = [NSAttributeDescription new];
    [attribute setName:name];
    [attribute setOptional:optional];
    [attribute setAttributeType:type];
    if (defaultValue) {
        [attribute setDefaultValue:defaultValue];
    }
    return attribute;
}
NSRelationshipDescription *MakeRelationship(NSString *name, BOOL optional, BOOL toMany,
                                            NSDeleteRule deletionRule,
                                            NSEntityDescription *destinationEntity)
{
    NSRelationshipDescription *relationship = [NSRelationshipDescription new];
    [relationship setName:name];
    [relationship setOptional:optional];
    [relationship setMinCount:optional ? 0 : 1];
    [relationship setMaxCount:toMany ? 0 : 1];
    [relationship setDeleteRule:deletionRule];
    [relationship setDestinationEntity:destinationEntity];
    return relationship;
}

NSManagedObjectModel *MakeCoreDataModel(void)
{
    NSManagedObjectModel *model = [NSManagedObjectModel new];

    NSEntityDescription *entry = [NSEntityDescription new];
    [entry setName:@"Entry"];
    [entry setManagedObjectClassName:@"Entry"];

    NSEntityDescription *stuff = [NSEntityDescription new];
    [stuff setName:@"Stuff"];
    [stuff setManagedObjectClassName:@"Stuff"];

    NSRelationshipDescription *entryStuff =
        MakeRelationship(@"stuff", YES, YES, NSCascadeDeleteRule, stuff);
    NSRelationshipDescription *stuffEntry =
        MakeRelationship(@"entry", YES, NO, NSNullifyDeleteRule, entry);

    [entryStuff setInverseRelationship:stuffEntry];
    [stuffEntry setInverseRelationship:entryStuff];

    [entry setProperties:@[
        MakeAttribute(@"number", YES, NSInteger32AttributeType, @(0)),
        MakeAttribute(@"string", YES, NSStringAttributeType, nil),
        entryStuff
    ]];

    [stuff setProperties:@[
        MakeAttribute(@"size", YES, NSInteger32AttributeType, nil),
        MakeAttribute(@"data", YES, NSStringAttributeType, nil),
        stuffEntry
    ]];

    [model setEntities:@[ entry, stuff ]];

    return model;
}

@implementation Entry
@dynamic number, string, stuff;
@end

@implementation Stuff
@dynamic size, data, entry;
@end

/**
 *  Convenience function to create an CoreData Entry
 *
 *  @param moc Managed object context
 *
 *  @return A useable entry or nil if fail
 */
Entry *MakeEntry(NSManagedObjectContext *moc)
{
    return
        [NSEntityDescription insertNewObjectForEntityForName:@"Entry" inManagedObjectContext:moc];
}

@implementation ReplicatorCoreData

#pragma mark - getters
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    _managedObjectModel = MakeCoreDataModel();

    return _managedObjectModel;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [NSManagedObjectContext new];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    _persistentStoreCoordinator =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];

    NSError *err = nil;
    NSURL *storeURL =
        [NSURL URLWithString:self.primaryRemoteDatabaseName relativeToURL:self.remoteRootURL];
    NSPersistentStore *theStore;
    theStore = [_persistentStoreCoordinator addPersistentStoreWithType:[CDTIncrementalStore type]
                                                         configuration:nil
                                                                   URL:storeURL
                                                               options:nil
                                                                 error:&err];
    XCTAssertNotNil(theStore, @"could not get theStore: %@", err);

    self.storeURL = storeURL;

    return _persistentStoreCoordinator;
}

- (CDTIncrementalStore *)getIncrenmentalStore
{
    NSArray *stores = [CDTIncrementalStore storesFromCoordinator:self.persistentStoreCoordinator];
    XCTAssertNotNil(stores, @"could not get stores");
    CDTIncrementalStore *store = [stores firstObject];
    XCTAssertNotNil(store, @"could not get incremental store");

    return store;
}

- (NSInteger)replicate:(CDTISReplicateDirection)direction
{
    CDTIncrementalStore *is = [self getIncrenmentalStore];
    NSError *err = nil;
    NSError *__block repErr = nil;
    BOOL __block done = NO;
    NSInteger __block count = 0;
    BOOL rep =
        [is replicateInDirection:direction
                       withError:&err
                    withProgress:^(BOOL end, NSInteger processed, NSInteger total, NSError *e) {
                        if (end) {
                            if (e) repErr = e;
                            done = YES;
                        } else {
                            count = processed;
                        }
                    }];
    XCTAssertTrue(rep, @"call to replicate failed");
    XCTAssertNil(err, @"call to replicate caused error: %@", err);
    while (!done) {
        [NSThread sleepForTimeInterval:1.0f];
    }
    XCTAssertNil(repErr, @"error while replicating: %@", repErr);
    return count;
}

- (void)setUp
{
    [super setUp];

    // Create remote database
    self.primaryRemoteDatabaseName =
        [NSString stringWithFormat:@"%@-test-coredata-database-%@", self.remoteDbPrefix,
                                   [CloudantReplicationBase generateRandomString:5]];
    self.primaryRemoteDatabaseURL =
        [self.remoteRootURL URLByAppendingPathComponent:self.primaryRemoteDatabaseName];

    [self createRemoteDatabase:self.primaryRemoteDatabaseName instanceURL:self.remoteRootURL];
}

- (void)tearDown
{
    self.managedObjectContext = nil;
    self.persistentStoreCoordinator = nil;

    // Delete remote database
    [self deleteRemoteDatabase:self.primaryRemoteDatabaseName instanceURL:self.remoteRootURL];

    [super tearDown];
}

- (void)testCoreDataReplication
{
    int max = 100;

    NSError *err = nil;
    // This will create the database
    NSManagedObjectContext *moc = self.managedObjectContext;
    XCTAssertNotNil(moc, @"could not create Context");

    // create some entries
    for (int i = 0; i < max; i++) {
        Entry *e = MakeEntry(moc);
        // check will indicate if value is an even number
        e.number = @(i);
        e.string = [NSString stringWithFormat:@"%u", (max * 10) + i];
    }

    // save to backing store
    XCTAssertTrue([moc save:&err], @"MOC save failed");
    XCTAssertNil(err, @"MOC save failed with error: %@", err);

    // there is actually `max` docs plut the metadata document
    int docs = max + 1;

    /**
     *  Push
     */
    NSInteger count = [self replicate:push];

    XCTAssertTrue(count == docs, @"push: unexpected processed objects: %@ != %d", @(count), docs);

    /**
     *  blow away the local database
     */
    self.managedObjectContext = nil;
    self.persistentStoreCoordinator = nil;

    // remove the entire database directory
    NSURL *dir = [CDTIncrementalStore localDir];
    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertNotNil(fm, @"Could not get File Manager");
    if (![fm removeItemAtURL:dir error:&err]) {
        XCTAssertTrue(err.code != NSFileNoSuchFileError,
                      @"removal of database directory failed: %@", err);
    }

    /**
     *  Out of band tally of the number of documents in the remote replicant
     */
    NSString *all_docs =
        [NSString stringWithFormat:@"%@/_all_docs?limit=0", [self.storeURL absoluteString]];
    UNIHTTPRequest *req = [UNIRest get:^(UNISimpleRequest *request) { [request setUrl:all_docs]; }];
    UNIHTTPJsonResponse *json = [req asJson];
    UNIJsonNode *body = json.body;
    NSDictionary *dic = body.object;
    NSNumber *total_rows = dic[@"total_rows"];
    count = [total_rows integerValue];
    XCTAssertTrue(count == docs, @"oob: unexpected number of objects: %@ != %d", @(count), docs);

    /**
     *  New context for pull
     */
    moc = self.managedObjectContext;
    XCTAssertNotNil(moc, @"could not create Context");

    count = [self replicate:pull];
    XCTAssertTrue(count == docs, @"pull: unexpected processed objects: %@ != %d", @(count), docs);

    /**
     *  Read it back
     */
    NSArray *results;
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES];

    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"Entry"];
    fr.shouldRefreshRefetchedObjects = YES;
    fr.sortDescriptors = @[ sd ];

    results = [moc executeFetchRequest:fr error:&err];
    XCTAssertNotNil(results, @"Expected results: %@", err);
    count = [results count];
    XCTAssertTrue(count == max, @"fetch: unexpected processed objects: %@ != %d", @(count), max);

    long long last = -1;
    for (Entry *e in results) {
        long long val = [e.number longLongValue];
        XCTAssertTrue(val < max, @"entry is out of range [0, %d): %lld", max, val);
        XCTAssertTrue(val == last + 1, @"unexpected entry %@: %@", @(val), e);
        ++last;
    }
}

@end
