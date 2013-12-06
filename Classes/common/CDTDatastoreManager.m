//
//  CSDatastoreManager.m
//  CloudantSyncIOSLib
//
//  Created by Michael Rhodes on 04/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"

#import "TD_DatabaseManager.h"

@interface CDTDatastoreManager ()

@property (nonatomic,strong,readonly) TD_DatabaseManager *manager;

@end

@implementation CDTDatastoreManager

-(id)initWithDirectory:(NSString*)directoryPath
                 error:(NSError**)outError
{
    self = [super init];
    if (self) {
//        _server = [[TD_Server alloc] initWithDirectory:directoryPath
//                                                 error:outError];
        _manager = [[TD_DatabaseManager alloc] initWithDirectory:directoryPath
                                                         options:nil
                                                           error:outError];
    }
    return self;
}

-(CDTDatastore *)datastoreNamed:(NSString*)name
{
//    return [_server waitForDatabaseManager:^id(TD_DatabaseManager *manager) {
//        return [[CDTDatastore alloc] initWithDatabase:[manager databaseNamed:name]];
//    }];
    return [[CDTDatastore alloc] initWithDatabase:[self.manager databaseNamed:name]];
}

@end
