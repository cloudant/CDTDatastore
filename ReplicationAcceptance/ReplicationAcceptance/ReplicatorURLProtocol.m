//
//  ReplicatorURLProtocol.m
//  ReplicationAcceptance
//
//  Created by Adam Cox on 10/16/14.
//
//

#import "ReplicatorURLProtocol.h"
#import "ReplicatorURLProtocolTester.h"

static ReplicatorURLProtocolTester* gReplicatorTester = nil;

@implementation ReplicatorURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // Capture all of the GET, PUT and POST calls
    // This protocol must be registered just before replication
    // and then unregistered immediately after the test. We then assume all HTTP
    // calls captured here are for execution of the replication.
    
    NSString *httpmethod = [request HTTPMethod];
    
    if ( ([httpmethod isEqualToString:@"GET"] || [httpmethod isEqualToString:@"PUT"] ||
        [httpmethod isEqualToString:@"POST"]) &&  gReplicatorTester) {
        
        [gReplicatorTester runTestForRequest:request];

    }
    return NO;
}

+(void)setTestDelegate:(ReplicatorURLProtocolTester*) delegate
{
    gReplicatorTester = delegate;
}

@end
