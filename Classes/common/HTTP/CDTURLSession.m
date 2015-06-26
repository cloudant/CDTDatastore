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
#import "CDTURLSessionFilterContext.h"
#import "MYBlockUtils.h"

@interface CDTURLSession ()

@property NSURLSession *session;
@property NSThread * thread;


@end


@implementation CDTURLSession{
}


- (instancetype)init
{
    return [self initWithDelegate:nil];
}

-(instancetype)initWithDelegate:(id<NSURLSessionDelegate>)delegate{
    self = [super init];
    if (self) {
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
        
        MYOnThread(strongSelf.thread, ^{
            completionHandler(_data,_response,_error);
        });
        
    } ];
    
    return task;
    
}

-(void)dealloc
{
    [self.session finishTasksAndInvalidate];
}

@end
