//
//  CDTURLSession.m
//  HttpTest
//
//  Created by tomblench on 12/03/2015.
//  Copyright (c) 2015 tomblench. All rights reserved.
//

#import "CDTURLSession.h"
#import "CDTURLSessionFilterContext.h"
#import "MYBlockUtils.h"

@interface CDTURLSession ()

@property NSURLSession *session;
@property NSThread * thread;


@end


@implementation CDTURLSession{
   // dispatch_queue_t queue;
}


- (instancetype)init
{
    return [self initWithDelegate:nil];
}

-(instancetype)initWithDelegate:(id<NSURLSessionDelegate>)delegate{
    self = [super init];
    if (self) {
        _numberOfRetries = 10;
        //queue = dispatch_queue_create("com.cloudant.sync.http.callback.queue",NULL);
        _thread = [NSThread currentThread];
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        _session = [NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:[NSOperationQueue currentQueue]];
    }
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
    __weak CDTURLSession *weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler: ^void (NSData *_data, NSURLResponse *_response, NSError *_error) {
        
        __strong CDTURLSession *strongSelf = weakSelf;
        _data = [NSData dataWithData:_data];
        // if we're not replaying then we can call the completion handler on a callback queue
        //dispatch_async(queue, ^{
        
        MYOnThread(strongSelf.thread, ^{
            completionHandler(_data,_response,_error);
        });
        
        
        //});
        
        
    } ];
    
    return task;
    
}

-(void)dealloc
{
    [self.session finishTasksAndInvalidate];
}

@end
