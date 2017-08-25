//
//  CDTPullReplication.m
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

#import "CDTPullReplication.h"
#import "CDTSessionCookieInterceptor.h"
#import "CDTIAMSessionCookieInterceptor.h"
#import "CDTReplay429Interceptor.h"
#import "CDTDatastore.h"
#import "CDTLogging.h"
#import "TDMisc.h"

@interface CDTPullReplication ()
@property (nonatomic, strong, readwrite) CDTDatastore *target;
@property (nonatomic, strong, readwrite) NSURL *source;
@end

@implementation CDTPullReplication

+ (instancetype)replicationWithSource:(NSURL *)source target:(CDTDatastore *)target
{
    return
        [CDTPullReplication replicationWithSource:source target:target username:nil password:nil];
}

+ (instancetype)replicationWithSource:(NSURL *)source
                               target:(CDTDatastore *)target
                             username:(NSString *)username
                             password:(NSString *)password
{
    return [[self alloc] initWithSource:source target:target username:username password:password];
}

+ (instancetype)replicationWithSource:(NSURL *)source
                               target:(CDTDatastore *)target
                            IAMAPIKey:(NSString *)IAMAPIKey
{
    return [[self alloc] initWithSource:source target:target IAMAPIKey:IAMAPIKey];
}

- (instancetype)initWithSource:(NSURL *)source
                        target:(CDTDatastore *)target
                      username:(NSString *)username
                      password:(NSString *)password
{
    if (self = [super initWithUsername:username password:password]) {
        NSURLComponents * sourceComponents = [NSURLComponents componentsWithURL:source resolvingAgainstBaseURL:NO];
        if(sourceComponents.user && sourceComponents.password){
            if (username && password) {
                CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"Credentials provided via the URL and username and password parameters, discarding URL credentials.");
            } else {
                CDTSessionCookieInterceptor * cookieInterceptor = [[CDTSessionCookieInterceptor alloc] initWithUsername:sourceComponents.user password:sourceComponents.password];
                [self addInterceptor:cookieInterceptor];
            }
            sourceComponents.user = nil;
            sourceComponents.password = nil;
        }
        
        _source = sourceComponents.URL;
        _target = target;
    }
    return self;
}

- (instancetype)initWithSource:(NSURL *)source
                        target:(CDTDatastore *)target
                     IAMAPIKey:(NSString *)IAMAPIKey
{
    if (self = [super initWithIAMAPIKey:IAMAPIKey]) {
        NSURLComponents * sourceComponents = [NSURLComponents componentsWithURL:source resolvingAgainstBaseURL:NO];
        if(sourceComponents.user && sourceComponents.password){
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"Credentials provided via the URL but IAM API key was provided, discarding URL credentials.");
        }
        CDTIAMSessionCookieInterceptor * cookieInterceptor = [[CDTIAMSessionCookieInterceptor alloc] initWithAPIKey:IAMAPIKey];
        [self addInterceptor:cookieInterceptor];
        
        sourceComponents.user = nil;
        sourceComponents.password = nil;
        
        _source = sourceComponents.URL;
        _target = target;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    CDTPullReplication *copy = [super copyWithZone:zone];
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
            [self class], TDCleanURLtoString(self.source), self.target.name, self.optionalHeaders, self.httpInterceptors,
            self.filter, self.filterParams];
}

// This is method is overridden and this code placed here so we can provide a better error message
- (BOOL)validateRemoteDatastoreURL:(NSURL *)url error:(NSError *__autoreleasing *)error
{
    if (url == nil) {
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT,
                @"CDTPullReplication -dictionaryForReplicatorDocument Error: source is nil.");

        if (error) {
            NSString *msg = @"Cannot sync data. Local data source not specified.";
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : NSLocalizedString(msg, nil)};
            *error = [NSError errorWithDomain:CDTReplicationErrorDomain
                                         code:CDTReplicationErrorUndefinedSource
                                     userInfo:userInfo];
        }
        return NO;
    }

    return [super validateRemoteDatastoreURL:url error:error];
}

@end
