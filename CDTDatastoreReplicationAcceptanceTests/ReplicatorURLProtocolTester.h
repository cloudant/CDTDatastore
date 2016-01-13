//
//  ReplicatorURLProtocolTester.h
//  ReplicationAcceptance
//
//  Created by Adam Cox on 10/21/14.
//
//

#import <Foundation/Foundation.h>

@interface ReplicatorURLProtocolTester : NSObject 
@property (nonatomic, strong) NSDictionary *expectedHeaders;
@property (nonatomic, readonly) NSMutableDictionary *headerFailures;
-(void) runTestForRequest:(NSURLRequest*)request;
@end
