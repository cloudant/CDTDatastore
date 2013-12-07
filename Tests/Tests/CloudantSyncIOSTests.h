//
//  CloudantSyncIOSTests.h
//  CloudantSyncIOSTests
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class CDTDatastoreManager;

@interface CloudantSyncIOSTests : SenTestCase

@property (nonatomic,strong) CDTDatastoreManager *factory;
@property (nonatomic,strong) NSString *factoryPath;

@end
