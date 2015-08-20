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
    NSURLSessionDataTask *task = [[NSURLSessionDataTask alloc]init];
    id mockedTask = OCMPartialMock(task);
    OCMStub([mockedTask state]).andReturn(NSURLSessionTaskStateSuspended);
    OCMStub([(NSURLSessionDataTask *)mockedTask resume]).andDo(nil);
    OCMStub([mockedTask cancel]).andDo(nil);
    
    CDTURLSessionTask * cdtTask  = [[CDTURLSessionTask alloc]initWithTask:mockedTask];
    
    //call void methods methods
    [cdtTask resume];
    [cdtTask cancel];
    
    //verify that object state is as expected
    XCTAssertEqual(NSURLSessionTaskStateSuspended, cdtTask.state);
    XCTAssertEqual(mockedTask, cdtTask.task);
    
    //verify mock methods called
    OCMVerify([(NSURLSessionDataTask *)mockedTask resume]);
    OCMVerify([mockedTask cancel]);
    OCMVerify([mockedTask state]);
}

@end
