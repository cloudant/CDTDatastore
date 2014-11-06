//
//  ReplicatorURLProtocolTester.m
//  ReplicationAcceptance
//
//  Created by Adam Cox on 10/21/14.
//
//

#import "ReplicatorURLProtocolTester.h"

@interface ReplicatorURLProtocolTester()
@property (nonatomic, readwrite) NSMutableDictionary *headerFailures;
@end


@implementation ReplicatorURLProtocolTester

-(void) runTestForRequest:(NSURLRequest*)request
{
    for (NSString* name in self.expectedHeaders) {
        NSString *httpValue = [request valueForHTTPHeaderField:name];
        
        if (![httpValue isEqualToString:self.expectedHeaders[name]]) {
            
            if (!self.headerFailures) {
                self.headerFailures = [[NSMutableDictionary alloc] init];
            }

            if (self.headerFailures[name]) {
                NSInteger number = [[self.headerFailures objectForKey:name] integerValue];
                number+=1;
                self.headerFailures[name] = @(number);
            }
            else {
                self.headerFailures[name] = @1;
            }
        }
        
    }
}


@end
