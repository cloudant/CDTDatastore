//
//  CDTURLSession.m
//
//  Created by Rhys Short.
//  Copyright (c) 2015 IBM Corp.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTURLSession.h"
#import "MYBlockUtils.h"
#import "CDTLogging.h"
#import "CDTHTTPInterceptorContext.h"
#import "CDTHTTPInterceptor.h"

@interface CDTURLSession ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) NSArray *interceptors;
@property (nonatomic, strong) NSMapTable *taskMap;

@end


@implementation CDTURLSession


- (instancetype)init
{
    return [self initWithCallbackThread:[NSThread currentThread]
                    requestInterceptors:@[]
                  sessionConfigDelegate:nil];
}

- (instancetype)initWithCallbackThread:(NSThread *)thread
                   requestInterceptors:(NSArray *)requestInterceptors
                 sessionConfigDelegate:(NSObject<CDTNSURLSessionConfigurationDelegate> *)sessionConfigDelegate
{
    NSParameterAssert(thread);
    self = [super init];
    if (self) {
        _thread = thread;
        _interceptors = [NSArray arrayWithArray:requestInterceptors];

        NSURLSessionConfiguration *config;
        // Create a unique session id using the address of self.
        NSString *sessionId = [NSString stringWithFormat:@"com.cloudant.sync.sessionid.%p", self];
        if ([[NSURLSessionConfiguration class] respondsToSelector:@selector(backgroundSessionConfigurationWithIdentifier:)]) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId];
        } else {
            config = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionId];
        }
        config = [sessionConfigDelegate customiseNSURLSessionConfiguration:config];

        _session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:nil];

        _taskMap = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (void)dealloc { [self.session finishTasksAndInvalidate]; }

- (CDTURLSessionTask *)dataTaskWithRequest:(NSURLRequest *)request
                              taskDelegate:(NSObject<CDTURLSessionTaskDelegate> *)taskDelegate
{
    CDTURLSessionTask *task = [[CDTURLSessionTask alloc] initWithSession:self
                                                                 request:request
                                                            interceptors:self.interceptors];
    task.delegate = taskDelegate;
    return task;
}

- (NSURLSessionDataTask *)createDataTaskWithRequest:(NSURLRequest *)request
                                 associatedWithTask:(CDTURLSessionTask *)task

{
    NSURLSessionDataTask *nsURLSessionTask = [self.session dataTaskWithRequest:request];
    [self.taskMap setObject:task forKey:[NSNumber numberWithInteger:nsURLSessionTask.taskIdentifier]];
    return nsURLSessionTask;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    CDTURLSessionTask *cdtURLSessionTask = [self getSessionTaskForId:dataTask.taskIdentifier];
    data = [NSData dataWithData:data];
    MYOnThread(self.thread, ^{
        [cdtURLSessionTask.delegate handleData:data];
    });

}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    CDTURLSessionTask *cdtURLSessionTask = [self getSessionTaskForId:task.taskIdentifier];
    if (error && cdtURLSessionTask) {
        [cdtURLSessionTask processError:error onThread:self.thread];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    CDTURLSessionTask *cdtURLSessionTask = [self getSessionTaskForId:dataTask.taskIdentifier];
    if (cdtURLSessionTask) {
        [cdtURLSessionTask processResponse:response onThread:self.thread];
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (CDTURLSessionTask *)getSessionTaskForId:(NSUInteger)identifier
{
    return [self.taskMap objectForKey:[NSNumber numberWithInteger:identifier]];
}

- (void) disassociateTask:(nonnull NSURLSessionDataTask *)task
{
    [self.taskMap removeObjectForKey:[NSNumber numberWithInteger:task.taskIdentifier]];
    [task cancel];
}

@end
