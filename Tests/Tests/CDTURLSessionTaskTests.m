//
//  CDTURLSessionTaskTests.m
//  Tests
//
//  Created by Rhys Short on 24/08/2015.
//
//

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>
#import "CloudantSyncTests.h"
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

    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    id mockedSession = OCMPartialMock(session);
    OCMStub([mockedSession dataTaskWithRequest:[OCMArg any] completionHandler:[OCMArg any]])
        .andReturn(task);

    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost"]];

    CDTURLSessionTask *cdtTask =
        [[CDTURLSessionTask alloc] initWithSession:mockedSession request:r interceptors:nil];

    //call void methods methods
    [cdtTask resume];
    [cdtTask cancel];
    
    //verify that object state is as expected
    XCTAssertEqual(NSURLSessionTaskStateSuspended, cdtTask.state);
    
    //verify mock methods called
    OCMVerify([(NSURLSessionDataTask *)mockedTask resume]);
    OCMVerify([mockedTask cancel]);
    OCMVerify([mockedTask state]);
}

@end
