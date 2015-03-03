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

#import "CDTPushReplication.h"
#import "CDTDatastore.h"
#import "TDMisc.h"
#import "CDTLogging.h"

@interface CDTPushReplication ()
@property (nonatomic, strong, readwrite) NSURL *target;
@property (nonatomic, strong, readwrite) CDTDatastore *source;
@end

@implementation CDTPushReplication

+ (instancetype)replicationWithSource:(CDTDatastore *)source target:(NSURL *)target
{
    return [[self alloc] initWithSource:source target:target];
}

- (instancetype)initWithSource:(CDTDatastore *)source target:(NSURL *)target
{
    if (self = [super init]) {
        _source = source;
        _target = target;
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
    NSMutableDictionary *dictionary = [[self dictionaryForReplicatorDocument:nil] mutableCopy];
    dictionary[@"target"] = TDCleanURLtoString(self.target);
    return [NSString stringWithFormat:@"%@: %@", [self class], dictionary];
}

- (NSDictionary *)dictionaryForReplicatorDocument:(NSError *__autoreleasing *)error
{
    NSError *localError;
    if (![self validateRemoteDatastoreURL:self.target error:&localError]) {
        if (error) {
            *error = localError;
        }
        return nil;
    }

    NSDictionary *superdoc = [super dictionaryForReplicatorDocument:&localError];
    if (superdoc == nil) {
        if (error) {
            *error = localError;
        }
        return nil;
    }

    NSMutableDictionary *doc = [NSMutableDictionary dictionaryWithDictionary:superdoc];

    [doc setObject:self.target.absoluteString forKey:@"target"];

    if (self.source) {
        [doc setObject:self.source.name forKey:@"source"];
        [doc setObject:[self.source copyEncryptionKeyRetriever] forKey:@"encryptionKeyRetriever"];
    } else {
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT,
                   @"CDTPullReplication -dictionaryForReplicatorDocument Error: source is nil.");

        if (error) {
            NSString *msg = @"Cannot sync data. Local data source not specified.";
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : NSLocalizedString(msg, nil)};
            *error = [NSError errorWithDomain:CDTReplicationErrorDomain
                                         code:CDTReplicationErrorUndefinedSource
                                     userInfo:userInfo];
        }
        return nil;
    }

    if (self.filterParams) {
        [doc setObject:self.filterParams ?: @{} forKey:@"query_params"];
    }

    return doc;
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
