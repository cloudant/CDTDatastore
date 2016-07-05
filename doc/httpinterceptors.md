# HTTPInterceptors

With the release of CDTDatastore 0.19 a new HTTP Interceptor API was introduced.
HTTP Interceptors allow the developer to modify the HTTP requests and responses
during the replication process.

Interceptors can be used to implement your own authentication schemes, for
example OAuth, or provide custom headers so you can perform your own analysis on
usage. They can also be used to monitor the requests made by the library.

To monitor or make changes to HTTP requests, conformance to the protocol `CDTHTTPInterceptor`
is required and you need to implement one of the following methods:

- To modify the outgoing request, `-interceptRequestInContext:`
- To modify the incoming response, `-interceptResponseInContext:`

If an interceptor instance needs to maintain state information across
invocations, this should be stored in the `state` dictionary available
on the `CDTHTTPInterceptorContext` object. Because this is shared by
the interceptor pipeline, interceptor authors are strongly encouranged
to use unique keys by ensuring keys are prefixed. See the
`CDTHTTPInterceptorContext` documentation for more detais and
`CDTRequestLimitInterceptor` source code for an example of usage.

A example of a HTTP interceptor:

```objc
#import "CDTHTTPInterceptor.h"

@interface SampleInterceptor : NSObject <CDTHTTPInterceptor>

@end

@implementation SampleInterceptor

- (instancetype)init
{
    self = [super init];
    if (self) {
        /* Init */
    }
    return self;
}

- (CDTHTTPInterceptorContext *)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    NSLog(@"Calling URL: %@", context.request.URL);

    return context;
}

- (CDTHTTPInterceptorContext *)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    NSLog(@"Received response; URL: %@; status code: %@.",
        context.request.URL, context.response.statusCode);
    return context;
}

@end

```

In order to add an HTTP interceptor to a replication, you call the `-addInterceptor:` or
`-addInterceptors:` method.

For example this is how you add an instance of `SampleInterceptor` to a pull replication:

```objc

#import "CloudantSync.h"

CDTDatastore *ds = [manager datastoreNamed:@"my_datastore" error:nil];
SampleInterceptor *interceptor = [[SampleInterceptor alloc] init];

CDTPullReplication *pull = [CDTPullReplication replicationWithSource:[NSURL urlWithString:@"https://username.cloudant.com"]
                                                               target:self.ds];
[pull addInterceptor:interceptor];

CDTReplicator * replicator = [factory oneway:pull error:nil];
[replicator start];
```
