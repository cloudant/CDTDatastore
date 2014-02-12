//
//  CDTReplicateController.m
//  Project
//
//  Created by Michael Rhodes on 08/01/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <CloudantSync.h>

#import "CDTReplicateController.h"

#import "CDTAppDelegate.h"

@interface CDTReplicateController ()

-(void)log:(NSString*)format, ...;
-(NSURL*)replicatorURL;
-(void)startAndFollowReplicator:(CDTReplicator*)replicator label:(NSString*)label;

@end

@implementation CDTReplicateController

+(NSString*)username
{
//    return @"dgenumeactseirabsedclown";  // ios-todo-sample
    return @"therstontsiveneavedgetil";  // android-eap-todo-sample
}

+(NSString*)password
{
//    return @"dxuUWlvMgNTGiTqWgCpGb0yW";  // ios-todo-sample
    return @"VIGuatsOpN2dK6LvaC6cRMrm";
}

-(NSURL*)replicatorURL {
    NSString *url = [NSString stringWithFormat:@"https://%@:%@@mikerhodes.cloudant.com/%@",
                     [CDTReplicateController username],
                     [CDTReplicateController password],
//                     @"ios-todo-sample"];
                     @"android-eap-todo-sample"];
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

        dispatch_async(dispatch_get_main_queue(), ^{
            if (replicator.state == CDTReplicatorStateComplete || replicator.state == CDTReplicatorStateStopped) {
                [weakSelf replicatorDidComplete:replicator];
            } else if (replicator.state == CDTReplicatorStateError) {
                [weakSelf replicatorDidError:replicator info:nil];
            }
        });
    });
}

#pragma mark CDTReplicatorListener delegate

-(void)replicatorDidComplete:(CDTReplicator *)replicator {
    [self log:@"complete"];
}

-(void)replicatorDidError:(CDTReplicator *)replicator info:(CDTReplicationErrorInfo *)info {
    [self log:@"error: %@", info];
}

@end
