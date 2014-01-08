//
//  CSDatastoreManager.m
//  CloudantSyncLib
//
//  Created by Michael Rhodes on 04/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

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
