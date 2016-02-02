//
//  ChangeTrackerNSURLProtocolTimedOut.m
//  ReplicationAcceptance
//
//  Created by Adam Cox on 1/11/15.
//
//

#import "ChangeTrackerNSURLProtocolTimedOut.h"

static NSURL* gChangeTrackerNSURLProtocolTimedOut_url = nil;

@implementation ChangeTrackerNSURLProtocolTimedOut

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [request.URL isEqual:gChangeTrackerNSURLProtocolTimedOut_url];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

+(void)setURL:(NSURL*) url;
{
    gChangeTrackerNSURLProtocolTimedOut_url = url;
}

- (void)startLoading
{
    id <NSURLProtocolClient> client = self.client;
    
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorTimedOut
                                     userInfo:nil];
    
    [client URLProtocol:self didFailWithError:error];
}

- (void)stopLoading
{
    
}
@end
