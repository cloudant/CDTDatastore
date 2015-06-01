//
//  TD_Database+BlobFilenames.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 29/05/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "TD_Database+BlobFilenames.h"

NSString *const TDDatabaseBlobFilenamesTableName = @"attachments_key_filename";

@implementation TD_Database (BlobFilenames)

#pragma mark - Public class methods
+ (NSString *)sqlCommandToCreateBlobFilenamesTable
{
    NSString *cmd =
        [NSString stringWithFormat:@"CREATE TABLE %@ (hexKey TEXT PRIMARY KEY, blobFilename TEXT);",
                                   TDDatabaseBlobFilenamesTableName];

    return cmd;
}

@end
