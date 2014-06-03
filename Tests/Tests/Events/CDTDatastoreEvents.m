//
//  CDTDatastoreEvents.m
//  Tests
//
//  Created by Michael Rhodes on 03/06/2014.
//
//

#import "CloudantSyncTests.h"

#import <CloudantSync.h>
#import <SenTestingKit/SenTestingKit.h>

#pragma mark EventWatcher

@interface EventWatcher : NSObject

@property (atomic) NSInteger counter;

@end

@implementation EventWatcher

-(void)eventHappened:(NSObject*)sender
{
    _counter++;
}

@end

#pragma mark - CDTDatastoreEvents

@interface CDTDatastoreEvents : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;
@property (nonatomic,strong) EventWatcher *watcher;
@property (nonatomic,strong) EventWatcher *globalWatcher;
@property (nonatomic,strong) EventWatcher *otherWatcher;

@end

@implementation CDTDatastoreEvents

- (void)setUp
{
    [super setUp];
    
    NSError *error;
    self.datastore = [self.factory datastoreNamed:@"test" error:&error];
    
    // This watcher should see all events on the datastore object we
    // will modify during the tests.
    self.watcher = [[EventWatcher alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self.watcher
                                             selector:@selector(eventHappened:)
                                                 name:CDTDatastoreChangeNotification
                                               object:self.datastore];
    
    // This watcher should see all modifications.
    self.globalWatcher = [[EventWatcher alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self.globalWatcher
                                             selector:@selector(eventHappened:)
                                                 name:CDTDatastoreChangeNotification
                                               object:nil];
    
    // We don't ever modify the datastore `other`, so this watcher should
    // never see an event.
    CDTDatastore *other = [self.factory datastoreNamed:@"other" error:&error];
    self.otherWatcher = [[EventWatcher alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self.otherWatcher
                                             selector:@selector(eventHappened:)
                                                 name:CDTDatastoreChangeNotification
                                               object:other];
    
    STAssertNotNil(self.datastore, @"datastore is nil");
}

- (void)tearDown
{
    self.datastore = nil;
    
    [super tearDown];
}

- (void)testEventFiredOnCreate
{
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    
    STAssertNotNil([self.datastore createDocumentWithBody:body error:nil],
                   @"Document wasn't created");
    
    // Events happen syncronously on update
    
    STAssertEquals(self.watcher.counter, (NSInteger)1, @"Event not fired");
    STAssertEquals(self.globalWatcher.counter, (NSInteger)1, @"Event not fired");
    STAssertEquals(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
}

- (void)testEventFiredOnUpdate
{
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body error:nil];
    
    STAssertNotNil(rev1, @"Document wasn't created");
    
    // Events happen syncronously on update
    
    STAssertEquals(self.watcher.counter, (NSInteger)1, @"Event not fired");
    STAssertEquals(self.globalWatcher.counter, (NSInteger)1, @"Event not fired");
    STAssertEquals(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
    
    CDTDocumentBody *body2 = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello2": @"world2"}];
    STAssertNotNil([self.datastore updateDocumentWithId:rev1.docId
                                                prevRev:rev1.revId
                                                   body:body2
                                                  error:nil],
                   @"Document wasn't updated");
    
    STAssertEquals(self.watcher.counter, (NSInteger)2, @"Event not fired");
    STAssertEquals(self.globalWatcher.counter, (NSInteger)2, @"Event not fired");
    STAssertEquals(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
}

- (void)testEventFiredOnDelete
{
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:@{@"hello": @"world"}];
    CDTDocumentRevision *rev1 = [self.datastore createDocumentWithBody:body error:nil];
    
    STAssertNotNil(rev1, @"Document wasn't created");
    
    // Events happen syncronously on update
    
    STAssertEquals(self.watcher.counter, (NSInteger)1, @"Event not fired");
    STAssertEquals(self.globalWatcher.counter, (NSInteger)1, @"Event not fired");
    STAssertEquals(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
    
    STAssertNotNil([self.datastore deleteDocumentWithId:rev1.docId
                                                    rev:rev1.revId
                                                  error:nil],
                   @"Document wasn't updated");
    
    STAssertEquals(self.watcher.counter, (NSInteger)2, @"Event not fired");
    STAssertEquals(self.globalWatcher.counter, (NSInteger)2, @"Event not fired");
    STAssertEquals(self.otherWatcher.counter, (NSInteger)0, @"Event incorrectly fired");
}

@end
