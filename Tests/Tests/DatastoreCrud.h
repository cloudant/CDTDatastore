//
//  DatastoreCrud.h
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "CloudantSyncIOSTests.h"

@class CDTDatastore;

@interface DatastoreCrud : CloudantSyncIOSTests

@property (nonatomic,strong) CDTDatastore *datastore;

@end
