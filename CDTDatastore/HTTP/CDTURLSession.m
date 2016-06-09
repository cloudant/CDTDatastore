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
#import "CDTLogging.h"
#import "CDTHTTPInterceptorContext.h"
#import "CDTHTTPInterceptor.h"

@interface CDTURLSession ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) NSArray *interceptors;
@property (nonatomic, strong) NSMapTable *taskMap;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*,NSMutableData*> *dataMap;

@end

/* number of async tasks to launch at any given time
 * if more tasks than this limit are launched, they will block until
 * -URLSession:task:didCompleteWithError is called
 */
static const int kAsyncTasks = 4;
static dispatch_semaphore_t g_asyncTaskMonitor;

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
    static dispatch_once_t onceToken;
    
    dispatch_once (&onceToken, ^{
        g_asyncTaskMonitor = dispatch_semaphore_create(kAsyncTasks);
    });

    NSParameterAssert(thread);
    self = [super init];
    if (self) {
        _thread = thread;
        _interceptors = [NSArray arrayWithArray:requestInterceptors];

        NSURLSessionConfiguration *config;
        // Create a unique session id using the address of self.
        NSString *sessionId = [NSString stringWithFormat:@"com.cloudant.sync.sessionid.%p", self];

// Only compile this for iOS8.0 and above or OSX 10.10 and above
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000) \
 || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 101000)
        // NSURLSessionConfiguration:backgroundSessionConfigurationWithIdentifier was introduced in iOS 8.0
        // to replace backgroundSessionConfiguration which was deprecated in iOS 8.0, so use the new version if
        // available.
        if ([[NSURLSessionConfiguration class] respondsToSelector:@selector(backgroundSessionConfigurationWithIdentifier:)]) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId];
        } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            // since the method is only called on platforms where its replacement is missing
            // we supress the warning
            config = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionId];
#pragma GCC pop
        }
#else
        config = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionId];
#endif
        [config setTimeoutIntervalForRequest:300];
        [sessionConfigDelegate customiseNSURLSessionConfiguration:config];

        _session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:nil];

        // Configure taskMap to hold weak references to the underlying NSURLSessionDataTask objects
        // so we don't unnecessarily hold on to objects and that values are removed from
        // the taskMap when the NSURLSessionDataTasks are deallocated.
        _taskMap = [NSMapTable strongToWeakObjectsMapTable];
        
        // Strong map table to handle the queueing of data.
        _dataMap = [NSMutableDictionary dictionary];
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
    // Unless we provide a queue from which to run the delegate this method will on be called in serial
    // see: https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSURLSession_class/#//apple_ref/occ/clm/NSURLSession/sessionWithConfiguration:delegate:delegateQueue:
    NSMutableData * storedData = [self.dataMap objectForKey:@(dataTask.taskIdentifier)];
    if (!storedData) {
        storedData = [NSMutableData data];
        [self.dataMap setObject:storedData forKey:@(dataTask.taskIdentifier)];
    }
    
    [storedData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    CDTURLSessionTask *cdtURLSessionTask = [self getSessionTaskForId:task.taskIdentifier];
    NSData * data = [self.dataMap objectForKey:@(task.taskIdentifier)];
    //remove from map so it can be deallocated.
    [self.dataMap removeObjectForKey:@(task.taskIdentifier)];
    
    [cdtURLSessionTask processError:error onThread:self.thread];
    [cdtURLSessionTask processData:data];
    [cdtURLSessionTask completedThread:self.thread];
    CDTLogVerbose(CDTTD_REMOTE_REQUEST_CONTEXT, @"Signalling asyncTaskMonitor");
    dispatch_semaphore_signal(g_asyncTaskMonitor);
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

- (void) waitForFreeSlot
{
    dispatch_semaphore_wait(g_asyncTaskMonitor, DISPATCH_TIME_FOREVER);
}

@end
