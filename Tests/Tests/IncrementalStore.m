//
//  IncrementalStore.m
//  Tests
//
//  Created by Jimi Xenidis on 12/7/14.
//
//

#import <CoreData/CoreData.h>
#import <XCTest/XCTest.h>

#import "CloudantSyncTests.h"
#import "CDTIncrementalStore.h"

/*
 *  ##Start Ripoff:
 *  The following code segment, that creates a managed object model
 *  programatically, has been derived from:
 *  >
 *https://github.com/couchbase/couchbase-lite-ios/blob/master/Source/API/Extras/CBLIncrementalStoreTests.m
 *
 *  Which at the time of pilferage had the following license:
 *  > http://www.apache.org/licenses/LICENSE-2.0
 */

@interface Entry : NSManagedObject
@property (nonatomic, retain) NSNumber *check;
@property (nonatomic, retain) NSDate *created_at;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSString *text2;
@property (nonatomic, retain) NSNumber *i16;
@property (nonatomic, retain) NSNumber *i32;
@property (nonatomic, retain) NSNumber *i64;
@property (nonatomic, retain) NSDecimalNumber *fpDecimal;
@property (nonatomic, retain) NSNumber *fpDouble;
@property (nonatomic, retain) NSNumber *fpFloat;
@property (nonatomic, retain) NSSet *subEntries;
@property (nonatomic, retain) NSSet *files;
@end

@class Subentry;
@class File;

@interface Entry (CoreDataGeneratedAccessors)
- (void)addSubEntriesObject:(Subentry *)value;
- (void)removeSubEntriesObject:(Subentry *)value;
- (void)addSubEntries:(NSSet *)values;
- (void)removeSubEntries:(NSSet *)values;

- (void)addFilesObject:(File *)value;
- (void)removeFilesObject:(File *)value;
- (void)addFiles:(NSSet *)values;
- (void)removeFiles:(NSSet *)values;
@end

@interface Subentry : NSManagedObject
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSNumber *number;
@property (nonatomic, retain) Entry *entry;
@end

@interface File : NSManagedObject
@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) NSData *data;
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

    NSEntityDescription *file = [NSEntityDescription new];
    [file setName:@"File"];
    [file setManagedObjectClassName:@"File"];

    NSEntityDescription *subentry = [NSEntityDescription new];
    [subentry setName:@"Subentry"];
    [subentry setManagedObjectClassName:@"Subentry"];

    NSRelationshipDescription *entryFiles =
        MakeRelationship(@"files", YES, YES, NSCascadeDeleteRule, file);
    NSRelationshipDescription *entrySubentries =
        MakeRelationship(@"subEntries", YES, YES, NSCascadeDeleteRule, subentry);
    NSRelationshipDescription *fileEntry =
        MakeRelationship(@"entry", YES, NO, NSNullifyDeleteRule, entry);
    NSRelationshipDescription *subentryEntry =
        MakeRelationship(@"entry", YES, NO, NSNullifyDeleteRule, entry);

    [entryFiles setInverseRelationship:fileEntry];
    [entrySubentries setInverseRelationship:subentryEntry];
    [fileEntry setInverseRelationship:entryFiles];
    [subentryEntry setInverseRelationship:entrySubentries];

    [entry setProperties:@[
        MakeAttribute(@"check", YES, NSBooleanAttributeType, nil),
        MakeAttribute(@"created_at", YES, NSDateAttributeType, nil),
        MakeAttribute(@"fpDecimal", YES, NSDecimalAttributeType, @(0.0)),
        MakeAttribute(@"fpDouble", YES, NSDoubleAttributeType, @(0.0)),
        MakeAttribute(@"fpFloat", YES, NSFloatAttributeType, @(0.0)),
        MakeAttribute(@"i16", YES, NSInteger16AttributeType, @(0)),
        MakeAttribute(@"i32", YES, NSInteger32AttributeType, @(0)),
        MakeAttribute(@"i64", YES, NSInteger64AttributeType, @(0)),
        MakeAttribute(@"text", YES, NSStringAttributeType, nil),
        MakeAttribute(@"text2", YES, NSStringAttributeType, nil),
        entryFiles,
        entrySubentries
    ]];

    [file setProperties:@[
        MakeAttribute(@"data", YES, NSBinaryDataAttributeType, nil),
        MakeAttribute(@"filename", YES, NSStringAttributeType, nil),
        fileEntry
    ]];

    [subentry setProperties:@[
        MakeAttribute(@"number", YES, NSInteger32AttributeType, @(0)),
        MakeAttribute(@"text", YES, NSStringAttributeType, nil),
        subentryEntry
    ]];

    [model setEntities:@[ entry, file, subentry ]];

    return model;
}

@implementation Entry
@dynamic check, created_at, text, text2, i16, i32, i64, fpDecimal, fpDouble, fpFloat, subEntries,
    files;
@end

@implementation Subentry
@dynamic text, number, entry;
@end

@implementation File
@dynamic filename, data, entry;
@end

/*
 *  ##End Ripoff:
 */

Entry *MakeEntry(NSManagedObjectContext *moc)
{
    return
        [NSEntityDescription insertNewObjectForEntityForName:@"Entry" inManagedObjectContext:moc];
}

@interface IncrementalStore : CloudantSyncTests

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

@implementation IncrementalStore

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
    NSURL *storeURL = [NSURL URLWithString:@"cdtis_test"];
    NSPersistentStore *theStore;
    theStore = [_persistentStoreCoordinator addPersistentStoreWithType:[CDTIncrementalStore type]
                                                         configuration:nil
                                                                   URL:storeURL
                                                               options:nil
                                                                 error:&err];
    XCTAssertNotNil(theStore, @"could not get theStore: %@", err);
    return _persistentStoreCoordinator;
}

- (void)setUp
{
    [super setUp];

    static BOOL initialized = NO;
    if (!initialized) {
        [CDTIncrementalStore initialize];
        initialized = YES;
    }

    // remove the entire database directory
    NSError *err = nil;
    NSURL *dir = [CDTIncrementalStore localDir];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm removeItemAtURL:dir error:&err]) {
        XCTAssertNil(err, @"%@", err);
    }
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.
    [super tearDown];

    self.managedObjectContext = nil;
    self.persistentStoreCoordinator = nil;
}

- (void)testCheckNumbers
{
    NSError *err = nil;
    // This will create the database
    NSManagedObjectContext *moc = self.managedObjectContext;
    XCTAssertNotNil(moc, @"could not create Context");

    // Increment this for every entry you make
    NSUInteger entries = 0;

    Entry *maxNums = MakeEntry(moc);
    ++entries;
    maxNums.check = @YES;
    maxNums.fpDecimal = [NSDecimalNumber maximumDecimalNumber];
    maxNums.fpDouble = @(FLT_MAX);  //@(DBL_MAX);
    maxNums.fpFloat = @(FLT_MAX);
    maxNums.i16 = @INT16_MAX;
    maxNums.i32 = @INT32_MAX;
    maxNums.i64 = @INT64_MAX;

    Entry *minNums = MakeEntry(moc);
    ++entries;
    minNums.check = @NO;
    minNums.fpDecimal = [NSDecimalNumber minimumDecimalNumber];
    minNums.fpDouble = @(FLT_MIN);  //@(DBL_MIN);
    minNums.fpFloat = @(FLT_MIN);
    minNums.i16 = @INT16_MIN;
    minNums.i32 = @INT32_MIN;
    minNums.i64 = @INT64_MIN;

    Entry *infNums = MakeEntry(moc);
    ++entries;
    infNums.fpDouble = @(INFINITY);
    infNums.fpFloat = @(INFINITY);

    Entry *ninfNums = MakeEntry(moc);
    ++entries;
    ninfNums.fpFloat = @(-INFINITY);
    ninfNums.fpDouble = @(-INFINITY);

    Entry *nanNums = MakeEntry(moc);
    ++entries;
    nanNums.fpDouble = @(NAN);
    nanNums.fpFloat = @(NAN);

    XCTAssertTrue([moc save:&err], @"Save Failed: %@", err);

    // does this really cause everything to fault?
    [moc refreshObject:infNums mergeChanges:NO];

    XCTAssertTrue([infNums.fpDouble isEqual:@(INFINITY)], @"Failed to retain double infinity");
    XCTAssertTrue([infNums.fpFloat isEqual:@(INFINITY)], @"Failed to retain float infinity");

    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"Entry"];
    NSUInteger count = [moc countForFetchRequest:fr error:&err];

    XCTAssertTrue(count == entries, @"Count fails");
}

#if 0
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
#endif

@end
