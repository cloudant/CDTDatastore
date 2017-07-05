//
//  CDTPushReplication.m
//
//
//  Created by Adam Cox on 4/8/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTAbstractReplication.h"
#import "CDTPushReplication.h"
#import "CDTDatastore.h"
#import "CDTSessionCookieInterceptor.h"
#import "CDTIAMSessionCookieInterceptor.h"
#import "CDTReplay429Interceptor.h"
#import "TDMisc.h"
#import "CDTLogging.h"

@interface CDTPushReplication ()
@property (nonatomic, strong, readwrite) NSURL *target;
@property (nonatomic, strong, readwrite) CDTDatastore *source;
@end

@implementation CDTPushReplication

+ (instancetype)replicationWithSource:(CDTDatastore *)source target:(NSURL *)target
{
    return
        [CDTPushReplication replicationWithSource:source target:target username:nil password:nil];
}

+ (instancetype)replicationWithSource:(CDTDatastore *)source
                               target:(NSURL *)target
                             username:(NSString *)username
                             password:(NSString *)password
{
    return [[self alloc] initWithSource:source target:target username:username password:password];
}

+ (instancetype)replicationWithSource:(CDTDatastore *)source
                               target:(NSURL *)target
                            IAMAPIKey:(NSString *)IAMAPIKey
{
    return [[self alloc] initWithSource:source target:target IAMAPIKey:IAMAPIKey];
}

- (instancetype)initWithSource:(CDTDatastore *)source
                        target:(NSURL *)target
                      username:(NSString *)username
                      password:(NSString *)password
{
    if (self = [super initWithUsername:username password:password]) {
        NSURLComponents * targetComponents = [NSURLComponents componentsWithURL:target resolvingAgainstBaseURL:NO];
        if(targetComponents.user && targetComponents.password){
            if (username && password) {
                CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"Credentials provided via the URL and username and password parameters, discarding URL credentials.");
            } else {
                CDTSessionCookieInterceptor * cookieInterceptor = [[CDTSessionCookieInterceptor alloc] initWithUsername:targetComponents.user password:targetComponents.password];
                [self addInterceptor:cookieInterceptor];
            }
            targetComponents.user = nil;
            targetComponents.password = nil;
        }
        
        _source = source;
        _target = targetComponents.URL;
    }
    return self;
}

- (instancetype)initWithSource:(CDTDatastore *)source
                        target:(NSURL *)target
                     IAMAPIKey:(NSString *)IAMAPIKey
{
    if (self = [super initWithIAMAPIKey:IAMAPIKey]) {
        NSURLComponents * targetComponents = [NSURLComponents componentsWithURL:target resolvingAgainstBaseURL:NO];
        if(targetComponents.user && targetComponents.password){
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"Credentials provided via the URL but IAM API key was provided, discarding URL credentials.");
        }
        CDTIAMSessionCookieInterceptor * cookieInterceptor = [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:IAMAPIKey];
        [self addInterceptor:cookieInterceptor];
        
        targetComponents.user = nil;
        targetComponents.password = nil;
        
        _source = source;
        _target = targetComponents.URL;
    }
    return self;
}


- (instancetype)copyWithZone:(NSZone *)zone
{
    CDTPushReplication *copy = [super copyWithZone:zone];

    if (copy) {
        copy.source = self.source;
        copy.target = self.target;
        copy.filter = self.filter;
        copy.filterParams = self.filterParams;
    }

    return copy;
}

- (NSString *)description
{    
    return [NSString stringWithFormat:@"%@, source: %@, target: %@, headers: %@, interceptors: %@, filter: %@, query_params: %@",
            [self class], self.source.name, TDCleanURLtoString(self.target), self.optionalHeaders, self.httpInterceptors,
            self.filter, self.filterParams];
}

// This is method is overridden and this code placed here so we can provide a better error message
- (BOOL)validateRemoteDatastoreURL:(NSURL *)url error:(NSError *__autoreleasing *)error
{
    if (url == nil) {
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT,
                @"CDTPullReplication -dictionaryForReplicatorDocument Error: target is nil.");

        if (error) {
            NSString *msg = @"Cannot sync data. Remote server not specified.";
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : NSLocalizedString(msg, nil)};
            *error = [NSError errorWithDomain:CDTReplicationErrorDomain
                                         code:CDTReplicationErrorUndefinedTarget
                                     userInfo:userInfo];
        }
        return NO;
    }

    return [super validateRemoteDatastoreURL:url error:error];
}

@end
