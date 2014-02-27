//
//  CDTReplicateController.m
//  Project
//
//  Created by Michael Rhodes on 08/01/2014.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <CloudantSync.h>

#import "CDTReplicateController.h"

#import "CDTAppDelegate.h"

@interface CDTReplicateController ()

-(void)log:(NSString*)format, ...;
-(NSURL*)replicatorURL;
-(void)startAndFollowReplicator:(CDTReplicator*)replicator label:(NSString*)label;

@end

@implementation CDTReplicateController

-(NSURL*)replicatorURL {
    // Shared database for demo purposes -- anyone can put stuff here...
    NSString *username = @"iessidesseepromanownessi";
    NSString *password = @"Y1GFiXSJ0trIonovEj3dhvSK";
    NSString *db_name = @"shared_todo_sample";
    NSString *url = [NSString stringWithFormat:@"https://%@:%@@mikerhodescloudant.cloudant.com/%@",
                     username,
                     password,
                     db_name];
    [self log:url];
    return [NSURL URLWithString:url];
}

-(void)log:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    self.logView.text = [NSString stringWithFormat:@"%@\n%@", message, self.logView.text];
}

-(IBAction)pullButtonTap:(id)sender {
    [self log:@"pullButtonTap"];

    NSURL *url = [self replicatorURL];

    CDTAppDelegate *delegate = (CDTAppDelegate *)[[UIApplication sharedApplication] delegate];
    CDTReplicatorFactory *factory = delegate.replicatorFactory;
    CDTReplicator *replicator = [factory onewaySourceURI:url targetDatastore:delegate.datastore];

    [self startAndFollowReplicator:replicator label:@"pull"];
}

-(IBAction)pushButtonTap:(id)sender {
    [self log:@"pushButtonTap"];

    NSURL *url = [self replicatorURL];

    CDTAppDelegate *delegate = (CDTAppDelegate *)[[UIApplication sharedApplication] delegate];
    CDTReplicatorFactory *factory = delegate.replicatorFactory;
    CDTReplicator *replicator = [factory onewaySourceDatastore:delegate.datastore targetURI:url];

    [self startAndFollowReplicator:replicator label:@"push"];
}

-(void)startAndFollowReplicator:(CDTReplicator*)replicator label:(NSString*)label {

    NSString *state = [CDTReplicator stringForReplicatorState:replicator.state];
    [self log:@"%@ state: %@ (%d)", label, state, replicator.state];

    [replicator setDelegate:self];
    [replicator start];

    state = [CDTReplicator stringForReplicatorState:replicator.state];
    [self log:@"%@ state: %@ (%d)", label, state, replicator.state];

    __block CDTReplicateController *weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while ([replicator isActive]) {
            [NSThread sleepForTimeInterval:2.0f];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *state = [CDTReplicator stringForReplicatorState:replicator.state];
                [weakSelf log:@"%@ state: %@ (%d)", label, state, replicator.state];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *state = [CDTReplicator stringForReplicatorState:replicator.state];
            [weakSelf log:@"%@ state: %@ (%d)", label, state, replicator.state];
        });

        // Both replicatorDidComplete and replicatorDidError dispatch to the main thread
        if (replicator.state == CDTReplicatorStateComplete || replicator.state == CDTReplicatorStateStopped) {
            [weakSelf replicatorDidComplete:replicator];
        } else if (replicator.state == CDTReplicatorStateError) {
            [weakSelf replicatorDidError:replicator info:nil];
        }
    });
}

#pragma mark CDTReplicatorListener delegate

-(void)replicatorDidComplete:(CDTReplicator *)replicator {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self log:@"complete"];
    });
}

-(void)replicatorDidError:(CDTReplicator *)replicator info:(CDTReplicationErrorInfo *)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self log:@"error: %@", info];
    });
}

@end
