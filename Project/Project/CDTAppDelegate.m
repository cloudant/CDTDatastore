//
//  CDTAppDelegate.m
//  Project
//
//  Created by Michael Rhodes on 03/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CDTAppDelegate.h"

#import <CloudantSync.h>

@interface CDTAppDelegate()

- (CDTDatastore*)create_datastore;

@end

@implementation CDTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.datastore = [self create_datastore];
    
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
    
    CDTDatastore *datastore = [manager datastoreNamed:@"todo_items" error:&outError];

    if (nil != outError) {
        NSLog(@"Error creating datastore: %@", outError);
        exit(1);
    }

    return datastore;

}

@end
