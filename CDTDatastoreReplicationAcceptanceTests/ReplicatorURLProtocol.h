//
//  ReplicatorURLProtocol.h
//  ReplicationAcceptance
//
//  Created by Adam Cox on 10/16/14.
//
//
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@class ReplicatorURLProtocolTester;

@interface ReplicatorURLProtocol : NSURLProtocol
+(void)setTestDelegate:(ReplicatorURLProtocolTester*) delegate;
@end

