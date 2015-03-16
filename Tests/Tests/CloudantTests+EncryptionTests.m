//
//  CloudantTests+EncryptionTests.m
//  EncryptionTests
//
//  Created by Enrique de la Torre Fernandez on 10/03/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CloudantTests+EncryptionTests.h"

#import "CDTDatastore.h"

@implementation CloudantTests (EncryptionTests)

#pragma mark - Public class methods
+ (NSString *)pathForIndexInDatastore:(CDTDatastore *)datastore
{
    NSString *dir = [datastore extensionDataFolder:kCDTIndexFolder];
    NSString *path = [NSString pathWithComponents:@[dir, kCDTIndexFilename]];
    
    return path;
}

@end
