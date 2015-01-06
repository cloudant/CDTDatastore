//
//  IndexManagerTests.h
//  Tests
//
//  Created by Thomas Blench on 27/01/2014.
//
//

#import <XCTest/XCTest.h>
#import "CloudantSyncTests.h"
#import "CDTIndexer.h"

@class CDTDatastore;

@interface IndexManagerTests : CloudantSyncTests

@property (nonatomic,strong) CDTDatastore *datastore;


@end

@interface CDTTestIndexer1NewAPI : NSObject<CDTIndexer>

@end
