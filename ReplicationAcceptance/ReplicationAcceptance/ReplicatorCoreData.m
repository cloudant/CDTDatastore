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

@interface Entry : NSManagedObject
@property (nonatomic, strong) NSNumber *number;
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSDate *created;
@property (nonatomic, strong) NSSet *stuff;
@end

@implementation Entry
@dynamic number, string, created, stuff;
@end

@interface Stuff : NSManagedObject
@property (nonatomic, retain) NSNumber *size;
@property (nonatomic, retain) NSString *data;
@property (nonatomic, retain) Entry *entry;
@end

@implementation Stuff
@dynamic size, data, entry;
@end

@implementation ReplicatorCoreData

- (Entry *)makeEntry:(NSManagedObjectContext *)moc
{
    Entry *e =
        [NSEntityDescription insertNewObjectForEntityForName:@"Entry" inManagedObjectContext:moc];
    XCTAssertNotNil(e, "could not get entity");
    return e;
}

#pragma mark - getters
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:@"CDEv1.0" withExtension:@"momd"];
    XCTAssertNotNil(url, @"could not find CoreDataEntry resource");

    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    XCTAssertTrue(([[_managedObjectModel entities] count] > 0), @"no entities");
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

- (NSManagedObjectContext *)createNumbersAndSave:(int)max
{
    NSError *err = nil;
    // This will create the database
    NSManagedObjectContext *moc = self.managedObjectContext;
    XCTAssertNotNil(moc, @"could not create Context");

    // create some entries
    for (int i = 0; i < max; i++) {
        Entry *e = [self makeEntry:moc];

        e.number = @(i);
        e.string = [NSString stringWithFormat:@"%u", (max * 10) + i];
        e.created = [NSDate dateWithTimeIntervalSinceNow:0];
    }

    // save to backing store
    XCTAssertTrue([moc save:&err], @"MOC save failed");
    XCTAssertNil(err, @"MOC save failed with error: %@", err);

    return moc;
}

- (void)removeLocalDatabase
{
    NSError *err = nil;

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
}

- (void)testCoreDataPushPull
{
    int max = 100;
    NSError *err = nil;

    NSManagedObjectContext *moc = [self createNumbersAndSave:max];

    // there is actually `max` docs plus the metadata document
    int docs = max + 1;

    /**
     *  Push
     */
    NSInteger count = [self replicate:push];

    XCTAssertTrue(count == docs, @"push: unexpected processed objects: %@ != %d", @(count), docs);

    [self removeLocalDatabase];

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

- (void)testCoreDataDuplication
{
    int max = 100;
    NSError *err = nil;

    NSManagedObjectContext *moc = [self createNumbersAndSave:max];

    // there is actually `max` docs plus the metadata document
    int docs = max + 1;

    // push
    NSInteger count = [self replicate:push];
    XCTAssertTrue(count == docs, @"push: unexpected processed objects: %@ != %d", @(count), docs);

    [self removeLocalDatabase];

    // make another core data set with the exact same series
    moc = [self createNumbersAndSave:max];

    // now pull
    count = [self replicate:pull];
    XCTAssertTrue(count == docs, @"pull: unexpected processed objects: %@ != %d", @(count), docs);

    // Read it back
    NSArray *results;
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES];

    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"Entry"];
    fr.shouldRefreshRefetchedObjects = YES;
    fr.sortDescriptors = @[ sd ];

    results = [moc executeFetchRequest:fr error:&err];
    XCTAssertNotNil(results, @"Expected results: %@", err);
    count = [results count];
    XCTAssertTrue(count == max * 2, @"fetch: unexpected processed objects: %@ != %d", @(count),
                  max * 2);

    // Find dupes
    // see:
    // https://developer.apple.com/library/ios/documentation/DataManagement/Conceptual/UsingCoreDataWithiCloudPG/UsingSQLiteStoragewithiCloud/UsingSQLiteStoragewithiCloud.html#//apple_ref/doc/uid/TP40013491-CH3-SW8

    /**
     *  1. Choose a property or a hash of multiple properties to use as a
     *     unique ID for each record.
     */
    NSString *uniquePropertyKey = @"number";
    NSExpression *countExpression =
        [NSExpression expressionWithFormat:@"count:(%@)", uniquePropertyKey];
    NSExpressionDescription *countExpressionDescription = [[NSExpressionDescription alloc] init];
    [countExpressionDescription setName:@"count"];
    [countExpressionDescription setExpression:countExpression];
    [countExpressionDescription setExpressionResultType:NSInteger64AttributeType];
    NSManagedObjectContext *context = moc;
    NSEntityDescription *entity =
        [NSEntityDescription entityForName:@"Entry" inManagedObjectContext:context];
    NSAttributeDescription *uniqueAttribute =
        [[entity attributesByName] objectForKey:uniquePropertyKey];

    /**
     *  2. Fetch the number of times each unique value appears in the store.
     *     The context returns an array of dictionaries, each containing
     *     a unique value and the number of times that value appeared in
     *     the store.
     */
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Entry"];
    [fetchRequest setPropertiesToFetch:@[ uniqueAttribute, countExpressionDescription ]];
    [fetchRequest setPropertiesToGroupBy:@[ uniqueAttribute ]];
    [fetchRequest setResultType:NSDictionaryResultType];
    NSArray *fetchedDictionaries = [moc executeFetchRequest:fetchRequest error:&err];

    // check
    XCTAssertNotNil(fetchedDictionaries, @"fetch request failed: %@", err);
    count = [fetchedDictionaries count];
    XCTAssertTrue(count == max, @"fetch: unexpected processed objects: %@ != %d", @(count), max);

    /**
     *  3. Filter out unique values that have no duplicates.
     */
    NSMutableArray *valuesWithDupes = [NSMutableArray array];
    for (NSDictionary *dict in fetchedDictionaries) {
        NSNumber *count = dict[@"count"];
        if ([count integerValue] > 1) {
            [valuesWithDupes addObject:dict[@"number"]];
        }
    }

    /**
     *  4. Use a predicate to fetch all of the records with duplicates.
     *     Use a sort descriptor to properly order the results for the
     *     winner algorithm in the next step.
     */
    NSFetchRequest *dupeFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Entry"];
    [dupeFetchRequest setIncludesPendingChanges:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"number IN (%@)", valuesWithDupes];
    [dupeFetchRequest setPredicate:predicate];

    sd = [NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES];
    [dupeFetchRequest setSortDescriptors:@[ sd ]];
    NSArray *dupes = [moc executeFetchRequest:dupeFetchRequest error:&err];

    // check
    XCTAssertNotNil(dupes, @"fetch request failed: %@", err);
    count = [dupes count];
    XCTAssertTrue(count == max * 2, @"fetch: unexpected processed objects: %@ != %d", @(count),
                  max * 2);

    /**
     *  5. Choose the winner.
     *     After retrieving all of the duplicates, your app decides which
     *     ones to keep. This decision must be deterministic, meaning that
     *     every peer should always choose the same winner. Among other
     *     methods, your app could store a created or last-changed timestamp
     *     for each record and then decide based on that.
     */
    Entry *prevObject;
    for (Entry *duplicate in dupes) {
        if (prevObject) {
            if (duplicate.number == prevObject.number) {
                if ([duplicate.created compare:prevObject.created] == NSOrderedAscending) {
                    [moc deleteObject:duplicate];
                } else {
                    [moc deleteObject:prevObject];
                    prevObject = duplicate;
                }
            } else {
                prevObject = duplicate;
            }
        } else {
            prevObject = duplicate;
        }
    }
    /**
     *  Remember to set a batch size on the fetch and whenever you reach
     *  the end of a batch, save the context.
     */
    XCTAssertTrue([moc save:&err], @"MOC save failed");
    XCTAssertNil(err, @"MOC save failed with error: %@", err);

    // read it back
    results = [moc executeFetchRequest:fr error:&err];
    XCTAssertNotNil(results, @"Expected results: %@", err);
    count = [results count];
    XCTAssertTrue(count == max, @"fetch: unexpected processed objects: %@ != %d", @(count), max);

    count = [self replicate:push];
    XCTAssertTrue(count == docs + max, @"push: unexpected processed objects: %@ != %d", @(count),
                  docs + max);
}

@end
