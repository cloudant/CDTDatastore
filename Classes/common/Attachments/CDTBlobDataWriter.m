//
//  CDTBlobDataWriter.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 14/05/2015.
//  Copyright (c) 2015 IBM Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>

#import "CDTBlobDataWriter.h"

#import "CDTLogging.h"

#import "TDMisc.h"

NSString *const CDTBlobDataWriterErrorDomain = @"CDTBlobDataWriterErrorDomain";

@interface CDTBlobDataWriter ()

@property (strong, nonatomic) NSData *data;

// Overide property defined in CDTBlobWriter
@property (strong, nonatomic) NSData *sha1Digest;

@end

@implementation CDTBlobDataWriter

#pragma mark - CDTBlobWriter methods
- (void)useData:(NSData *)data
{
    self.data = data;
    self.sha1Digest = (data ? TDSHA1Digest(data) : nil);
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error
{
    BOOL success = YES;
    NSError *thisError = nil;

    if (success) {
        success = (self.data != nil);
        if (!success) {
            thisError = [CDTBlobDataWriter errorNoData];
        }
    }

    if (success) {
        success = (path && ([path length] > 0));
        if (!success) {
            thisError = [CDTBlobDataWriter errorNoPath];
        }
    }

    if (success) {
        NSDataWritingOptions options = NSDataWritingAtomic;
#if TARGET_OS_IPHONE
        options |= NSDataWritingFileProtectionCompleteUnlessOpen;
#endif

        success = [self.data writeToFile:path options:options error:&thisError];
        if (!success) {
            CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Could not write data to file %@: %@", path,
                        thisError);
        }
    }

    if (!success && error) {
        *error = thisError;
    }

    return success;
}

#pragma mark - Public class methods
+ (instancetype)writer { return [[[self class] alloc] init]; }

#pragma mark - Private class methods
+ (NSError *)errorNoData
{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey :
            NSLocalizedString(@"No data to write to file", @"No data to write to file")
    };

    return [NSError errorWithDomain:CDTBlobDataWriterErrorDomain
                               code:CDTBlobDataWriterErrorNoData
                           userInfo:userInfo];
}

+ (NSError *)errorNoPath
{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey : NSLocalizedString(@"Inform a file path", @"Inform a file path")
    };

    return [NSError errorWithDomain:CDTBlobDataWriterErrorDomain
                               code:CDTBlobDataWriterErrorNoPath
                           userInfo:userInfo];
}

@end
