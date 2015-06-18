//
//  CDTURLSession.m
//  HttpTest
//
//  Created by tomblench on 12/03/2015.
//  Copyright (c) 2015 tomblench. All rights reserved.
//

#import "CDTURLSession.h"
#import "CDTURLSessionFilterContext.h"

@interface CDTURLSession ()

@property NSMutableArray * responseFilters;
@property NSMutableArray * requestFilters;
@property BOOL requestProcessing;
@property int remaingRetires;
@property NSURLSession *session;


@end


@implementation CDTURLSession{
    dispatch_queue_t queue;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _responseFilters = [NSMutableArray array];
        _requestFilters = [NSMutableArray array];
        _numberOfRetries = 10;
        _remaingRetires = _numberOfRetries;
        _requestProcessing = NO;
        queue = dispatch_queue_create("com.cloudant.sync.http.callback.queue",NULL);
        _session = [NSURLSession sessionWithConfiguration:nil];
    }
    return self;
}

- (void)addResponseFilter:(NSObject<CDTURLSessionResponseFilter>*)filter
{
    [self.responseFilters addObject:filter];
}

- (void)addRequestFilter:(NSObject<CDTURLSessionRequestFilter>*)filter{
    [self.requestFilters addObject:filter];
}


- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
    CDTURLSessionFilterContext *context = [[CDTURLSessionFilterContext alloc] initWithRequest:request];
    return [self dataTaskWithContext:context completionHandler:completionHandler];
    
}

- (NSURLSessionDataTask *)dataTaskWithContext:(CDTURLSessionFilterContext*)context
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
    
    if(self.requestProcessing){
        //need to decrement the retry count.
        self.remaingRetires--;
    } else {
        self.requestProcessing = YES;
        self.remaingRetires = self.numberOfRetries;
    }
    
    // do request
    // run response filter before completion handler
    // retries?
    
    __weak CDTURLSession *weakSelf = self;

    
    for (NSObject<CDTURLSessionRequestFilter>* filter in self.responseFilters) {
        context = [filter filterRequestWithContext:context];
    }
    

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:context.request completionHandler: ^void (NSData *_data, NSURLResponse *_response, NSError *_error) {

        CDTURLSessionFilterContext *currentContext = context;
        context.response = _response;
        context.replayRequest = FALSE;
        for (NSObject<CDTURLSessionResponseFilter> *filter in _responseFilters) {
            currentContext = [filter filterResponseWithContext:currentContext];
        }

        if (currentContext.replayRequest && self.remaingRetires > 0) {
            CDTURLSession *strongSelf = weakSelf;
            NSURLSessionDataTask *replayTask = [strongSelf dataTaskWithContext:currentContext completionHandler:completionHandler];
            [replayTask resume];
        } else {
            // if we're not replaying then we can call the completion handler on a callback queue
            //dispatch_async(queue, ^{
                completionHandler(_data, _response, _error);
           // });
            
        }
    } ];

    return task;
}


@end
