//
//  CDTURLSessionTaskTests.m
//  Tests
//
//  Created by Rhys Short on 24/08/2015.
//  Copyright (c) 2015 IBM Corp.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>
#import "CloudantSyncTests.h"
#import "CDTURLSession.h"
#import "CDTURLSessionTask.h"
#import <OCMock/OCMock.h>

@interface CDTURLSessionTaskTests : CloudantSyncTests

@end

@implementation CDTURLSessionTaskTests

- (void)testTaskCorrectlyProxiesCalls
{
    NSURLSessionDataTask *task = [[NSURLSessionDataTask alloc] init];
    id mockedTask = OCMPartialMock(task);
    OCMStub([mockedTask state]).andReturn(NSURLSessionTaskStateSuspended);
    OCMStub([(NSURLSessionDataTask *)mockedTask resume]).andDo(nil);
    OCMStub([mockedTask cancel]).andDo(nil);

    NSThread *thread = [[NSThread alloc] init];
    CDTURLSession *session = [[CDTURLSession alloc] initWithCallbackThread:thread
                                                       requestInterceptors:nil
                                                     sessionConfigDelegate:nil];
    id mockedSession = OCMPartialMock(session);
    OCMStub([mockedSession createDataTaskWithRequest:[OCMArg any] associatedWithTask:[OCMArg any]])
        .andReturn(mockedTask);
    OCMStub([mockedSession disassociateTask:[OCMArg any]]).andDo(nil);

    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost"]];

    CDTURLSessionTask *cdtTask =
        [[CDTURLSessionTask alloc] initWithSession:mockedSession request:r interceptors:nil];

    //call void methods methods
    [cdtTask resume];
    [cdtTask cancel];
    
    //verify that object state is as expected
    XCTAssertEqual(NSURLSessionTaskStateSuspended, [cdtTask state]);

    //verify mock methods called
    OCMVerify([(NSURLSessionDataTask *)mockedTask resume]);
    OCMVerify([mockedTask cancel]);
    OCMVerify([mockedTask state]);
}

@end
