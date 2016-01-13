//
//  CDTDatastoreEvents.m
//  Tests
//
//  Created by Michael Rhodes on 03/06/2014.
//
//

#import "CloudantSyncTests.h"

#import <CDTDatastore/CloudantSync.h>
#import <XCTest/XCTest.h>
#import <CDTDatastore/TD_Body.h>
#import <CDTDatastore/TD_Revision.h>
#import <CDTDatastore/TD_Database.h>
#import <CDTDatastore/TD_Database+Insertion.h>

#pragma mark EventWatcher

@interface EventWatcher2 : NSObject

@property (atomic) NSInteger counter;

@end

@implementation EventWatcher2

-(void)eventHappened:(NSObject*)sender
{
    _counter++;
}

@end

#pragma mark - CDTDatastoreEvents

@interface CDTDatastoreEvents : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) EventWatcher2 *watcher;
@property (nonatomic,strong) EventWatcher2 *globalWatcher;
@property (nonatomic,strong) EventWatcher2 *otherWatcher;

@end

@implementation CDTDatastoreEvents

- (void)setUp
{
    [super setUp];
    
    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    
    // This watcher should see all events on the datastore object we
    // will modify during the tests.
    self.watcher = [[EventWatcher2 alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self.watcher
                                             selector:@selector(eventHappened:)
                                                 name:CDTDatastoreChangeNotification
                                               object:self.datastore];
    
    // This watcher should see all modifications.
    self.globalWatcher = [[EventWatcher2 alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self.globalWatcher
                                             selector:@selector(eventHappened:)
                                                 name:CDTDatastoreChangeNotification
                                               object:nil];
    
    // We don't ever modify the datastore `other`, so this watcher should
    // never see an event.
    CDTDatastore *other = [self.factory datastoreNamed:@"other" error:&error];
    self.otherWatcher = [[EventWatcher2 alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self.otherWatcher
                                             selector:@selector(eventHappened:)
                                                 name:CDTDatastoreChangeNotification
                                               object:other];
    
    XCTAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    self.datastore = nil;
    
    [super tearDown];
}

- (void)testEventFiredOnCreate
{
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = @{@"hello": @"world"};
    
    XCTAssertNotNil([self.datastore createDocumentFromRevision:rev error:nil],
                   @"Document wasn't created");
    
    // Events happen syncronously on update
    
    XCTAssertEqual(self.watcher.counter, (NSInteger)1, @"Event not fired");
    XCTAssertEqual(self.globalWatcher.counter, (NSInteger)1, @"Event not fired");
    XCTAssertEqual(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
}

- (void)testEventFiredOnUpdate
{
    CDTDocumentRevision *mutableRev = [CDTDocumentRevision revision];
    mutableRev.body = @{@"hello": @"world"};
    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:mutableRev error:nil];
    
    XCTAssertNotNil(rev1, @"Document wasn't created");
    
    // Events happen syncronously on update
    
    XCTAssertEqual(self.watcher.counter, (NSInteger)1, @"Event not fired");
    XCTAssertEqual(self.globalWatcher.counter, (NSInteger)1, @"Event not fired");
    XCTAssertEqual(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");

    mutableRev = [rev1 copy];
    mutableRev.body = @{@"hello2": @"world2"};
    XCTAssertNotNil([self.datastore updateDocumentFromRevision:mutableRev error:nil],
                   @"Document wasn't updated");
    
    XCTAssertEqual(self.watcher.counter, (NSInteger)2, @"Event not fired");
    XCTAssertEqual(self.globalWatcher.counter, (NSInteger)2, @"Event not fired");
    XCTAssertEqual(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
}

- (void)testEventFiredOnDelete
{
    CDTDocumentRevision *mutableRev = [CDTDocumentRevision revision];
    mutableRev.body = @{@"hello": @"world"};
    CDTDocumentRevision *rev1 = [self.datastore createDocumentFromRevision:mutableRev error:nil];
    
    XCTAssertNotNil(rev1, @"Document wasn't created");
    
    // Events happen syncronously on update
    
    XCTAssertEqual(self.watcher.counter, (NSInteger)1, @"Event not fired");
    XCTAssertEqual(self.globalWatcher.counter, (NSInteger)1, @"Event not fired");
    XCTAssertEqual(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
    
    XCTAssertNotNil([self.datastore deleteDocumentFromRevision:rev1 error:nil],
                   @"Document wasn't updated");
    
    XCTAssertEqual(self.watcher.counter, (NSInteger)2, @"Event not fired");
    XCTAssertEqual(self.globalWatcher.counter, (NSInteger)2, @"Event not fired");
    XCTAssertEqual(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
}

- (void)testEventFiredOnMultipleDelete
{
    NSError * error;
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"aTestDocId"];
    rev.body = @{ @"hello" : @"world" };

    rev = [self.datastore createDocumentFromRevision:rev error:&error];

    XCTAssertNotNil(rev, @"Document was not created");

    NSMutableDictionary *body = [rev.body mutableCopy];
    [body setObject:@"objc" forKey:@"writtenIn"];
    rev.body = body;
    [self.datastore updateDocumentFromRevision:rev error:&error];

    //now need to force insert into the DB little messy though

    [body setObject:@"conflictedinsert" forKey:@"conflictedkeyconflicted"];

    //borrow conversion code from update then do force insert
    
    TD_Revision *converted = [[TD_Revision alloc]initWithDocID:rev.docId
                                                         revID:rev.revId
                                                       deleted:rev.deleted];
    converted.body = [[TD_Body alloc] initWithProperties:body];

    TDStatus status;

    [self.datastore.database putRevision:converted
                          prevRevisionID:rev.revId
                           allowConflict:YES
                                  status:&status];

    [self.datastore deleteDocumentWithId:rev.docId error:&error];

    //3 notifications get fired for the set up, another one for the double delete
    XCTAssertEqual(self.watcher.counter, (NSInteger)4, @"Event not fired");
    XCTAssertEqual(self.globalWatcher.counter, (NSInteger)4, @"Event not fired");
    XCTAssertEqual(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
    
}

@end
