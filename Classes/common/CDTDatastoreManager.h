//
//  CSDatastoreManager.h
//  CloudantSyncIOSLib
//
//  Created by Michael Rhodes on 04/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CDTDatastore;

// A CDTDatastoreManager manages a group of CDTDatastore's. It also manages
// the behind the scenes threading details to ensure the underlying SQLite
// database is accessed safely.
@interface CDTDatastoreManager : NSObject

-(id)initWithDirectory:(NSString*)directoryPath
                 error:(NSError**)outError;

-(CDTDatastore *)datastoreNamed:(NSString*)name;

@end
