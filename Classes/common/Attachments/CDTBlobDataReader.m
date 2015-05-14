//
//  CDTBlobDataReader.m
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

#import "CDTBlobDataReader.h"

#import "CDTLogging.h"

@interface CDTBlobDataReader ()

@property (strong, nonatomic, readonly) NSString *path;

@end

@implementation CDTBlobDataReader

#pragma mark - Init object
- (instancetype)init { return [self initWithPath:nil]; }

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        if (path && ([path length] > 0)) {
            _path = path;
        } else {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"A non-empty path is mandatory");

            self = nil;
        }
    }

    return self;
}

#pragma mark - CDTBlobReader methods
- (NSData *)dataWithError:(NSError **)error
{
    NSError *thisError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.path
                                          options:NSDataReadingMappedIfSafe
                                            error:&thisError];
    if (!data) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"Data object could not be created with file %@: %@",
                    self.path, thisError);

        if (error) {
            *error = thisError;
        }
    };

    return data;
}

- (NSInputStream *)inputStreamWithOutputLength:(UInt64 *)outputLength
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    BOOL isDirectory = YES;
    if (![defaultManager fileExistsAtPath:self.path isDirectory:&isDirectory] || isDirectory) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"No file found in %@", self.path);

        return nil;
    }

    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:self.path];

    if (inputStream && outputLength) {
        NSError *error = nil;
        NSDictionary *info = [defaultManager attributesOfItemAtPath:self.path error:&error];
        if (info) {
            *outputLength = [info fileSize];
        } else {
            CDTLogDebug(CDTDATASTORE_LOG_CONTEXT,
                        @"Attributes for file %@ could not be obtained: %@", self.path, error);

            inputStream = nil;
        }
    }

    return inputStream;
}

#pragma mark - Public class methods
+ (instancetype)readerWithPath:(NSString *)path { return [[[self class] alloc] initWithPath:path]; }

@end
