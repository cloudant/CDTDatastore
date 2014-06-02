//
//  CloudantSyncTests.h
//  CloudantSyncTests
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <SenTestingKit/SenTestingKit.h>

@class CDTDatastoreManager;

#define kDBExtension @"touchdb"  //in TD_DatabaseManager.m. Move it into .h?

@interface CloudantSyncTests : SenTestCase

@property (nonatomic,strong) CDTDatastoreManager *factory;
@property (nonatomic,strong) NSString *factoryPath;
@property (nonatomic, readonly) NSSet *sqlTables;

- (NSString*)createTemporaryDirectoryAndReturnPath;
- (NSString *)pathForDBName:(NSString *)name;

@end
