//
//  CSDatastoreManager.m
//  CloudantSyncLib
//
//  Created by Michael Rhodes on 04/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"

#import "TD_DatabaseManager.h"
#import "TD_Database.h"

NSString* const CDTDatastoreErrorDomain = @"CDTDatastoreErrorDomain";

@interface CDTDatastoreManager ()

@end

@implementation CDTDatastoreManager

-(id)initWithDirectory:(NSString*)directoryPath
                 error:(NSError**)outError
{
    self = [super init];
    if (self) {
        _manager = [[TD_DatabaseManager alloc] initWithDirectory:directoryPath
                                                         options:nil
                                                           error:outError];
        if(!_manager)
            return nil;
    }
    return self;
}

-(CDTDatastore *)datastoreNamed:(NSString*)name
                          error:(NSError * __autoreleasing *)error
{
//    if (![TD_Database isValidDatabaseName:name]) {
//      Not a public method yet
//    }

    TD_Database *db = [self.manager databaseNamed:name];

    if (db) {
        return [[CDTDatastore alloc] initWithDatabase:db];
    } else {
        NSDictionary *userInfo = @{
          NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't create database.", nil),
          NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Invalid name?", nil),
          NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Invalid name?", nil)
        };
        *error = [NSError errorWithDomain:CDTDatastoreErrorDomain
                                     code:400
                                 userInfo:userInfo];
        return nil;
    }
}

@end
