//
//  CDTAbstractReplication.m
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
#import "TD_DatabaseManager.h"
#import "CDTLogging.h"

NSString* const CDTReplicationErrorDomain = @"CDTReplicationErrorDomain";

@implementation CDTAbstractReplication

/**
 This method sets all of the common replication parameters. The subclasses,
 CDTPushReplication and CDTPullReplication add source, target and filter. 
 */
-(NSDictionary*) dictionaryForReplicatorDocument:(NSError * __autoreleasing*)error
{
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Replicator Doc: %@",
            [self dictionaryForReplicatorDocument:nil]];
}

-(BOOL)validateRemoteDatastoreURL:(NSURL *)url error:(NSError * __autoreleasing*)error
{
    NSString *scheme = [url.scheme lowercaseString];
    NSArray *validSchemes = @[@"http", @"https"];
    if (![validSchemes containsObject:scheme]) {
        if (error) {
            LogWarn(REPLICATION_LOG_CONTEXT,@"%@ -validateRemoteDatastoreURL Error. "
                  @"Invalid scheme: %@", [self class], url.scheme);
            
            NSString *msg = @"Cannot sync data. Invalid Remote Database URL";
            
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(msg, nil)};
            *error = [NSError errorWithDomain:CDTReplicationErrorDomain
                                         code:CDTReplicationErrorInvalidScheme
                                     userInfo:userInfo];
        }
        return NO;

    }
    
    // username and password must be supplied together
    BOOL usernameSupplied = url.user != nil && ![url.user isEqualToString:@""];
    BOOL passwordSupplied = url.password != nil && ![url.password isEqualToString:@""];
    
    if ( (!usernameSupplied && passwordSupplied) ||
         (usernameSupplied && !passwordSupplied)) {
        if (error) {
            LogWarn(REPLICATION_LOG_CONTEXT,@"%@ -validateRemoteDatastoreURL Error. "
                  @"Must have both username and password, or neither. ", [self class]);
            
            NSString *msg = [NSString stringWithFormat:@"Cannot sync data. Missing %@",
                             usernameSupplied ? @"password" : @"username"];
            
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(msg, nil)};
            *error = [NSError errorWithDomain:CDTReplicationErrorDomain
                                         code:CDTReplicationErrorIncompleteCredentials
                                     userInfo:userInfo];
        }
        return NO;
    }
    
    
    return YES;
}

@end