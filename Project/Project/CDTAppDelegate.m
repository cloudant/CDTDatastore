//
//  CDTAppDelegate.m
//  Project
//
//  Created by Michael Rhodes on 03/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTAppDelegate.h"

#import "CDTCompletedIndexer.h"
#import "CDTTodoReplicator.h"
#import "CDTLogging.h"
#import <CloudantSync.h>

@interface CDTAppDelegate()

- (CDTDatastore*)create_datastore;

@end

@implementation CDTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    
    CDTChangeLogLevel(CDTINDEX_LOG_CONTEXT, DDLogLevelError);
    CDTChangeLogLevel(CDTREPLICATION_LOG_CONTEXT, DDLogLevelError);
    CDTChangeLogLevel(CDTDATASTORE_LOG_CONTEXT, DDLogLevelError);
    CDTChangeLogLevel(CDTDOCUMENT_REVISION_LOG_CONTEXT, DDLogLevelError);
    CDTChangeLogLevel(CDTTD_REMOTE_REQUEST_CONTEXT, DDLogLevelError);
    CDTChangeLogLevel(CDTTD_JSON_CONTEXT, DDLogLevelError);
    
    self.datastore = [self create_datastore];

    // Create the indexManager and add an index on the "completed" field with a
    // custom indexer (so we can index the BOOL value).
    NSError *error;
    self.indexManager = [[CDTIndexManager alloc] initWithDatastore:self.datastore
                                                             error:&error];
    if (!self.indexManager) {
        NSLog(@"Error creating indexManager: %@", error);
        exit(1);
    }

    error = nil;
    CDTCompletedIndexer *fi = [[CDTCompletedIndexer alloc] init];
    BOOL ensuredIndex = [self.indexManager ensureIndexedWithIndexName:@"completed"
                                                                 type:CDTIndexTypeInteger
                                                              indexer:fi
                                                                error:&error];
    if (!ensuredIndex) {
        NSLog(@"Error creating indexManager: %@", error);
        exit(1);
    }

    self.todoReplicator = [[CDTTodoReplicator alloc] init];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

}

/**
 * Creates the datastore which the application uses
 */
- (CDTDatastore*)create_datastore
{
    // Override point for customization after application launch.
    
    NSError *outError = nil;
    
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsDir URLByAppendingPathComponent: @"cloudant-sync-datastore"];
    
    BOOL isDir;
    BOOL exists = [fileManager fileExistsAtPath:[storeURL path] isDirectory:&isDir];
    
    if (exists && !isDir) {
        NSLog(@"Can't create datastore directory: file in the way at %@", storeURL);
        exit(1);
    }
    
    if (!exists) {
        [fileManager createDirectoryAtURL:storeURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:&outError];
        
        if (nil != outError) {
            NSLog(@"Error creating manager directory: %@", outError);
            exit(1);
        }
    }
    
    NSString *path = [storeURL path];
    
    CDTDatastoreManager *manager = [[CDTDatastoreManager alloc] initWithDirectory:path
                                                                            error:&outError];
    
    if (nil != outError) {
        NSLog(@"Error creating manager: %@", outError);
        exit(1);
    }

    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];

    CDTDatastore *datastore = [manager datastoreNamed:@"todo_items" error:&outError];

    if (nil != outError) {
        NSLog(@"Error creating datastore: %@", outError);
        exit(1);
    }

    return datastore;

}

@end
