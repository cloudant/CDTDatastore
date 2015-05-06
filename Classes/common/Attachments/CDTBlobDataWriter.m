//
//  CDTBlobDataWriter.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 06/05/2015.
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

#import "CDTBlobDataWriter.h"

#import "CDTLogging.h"

@interface CDTBlobDataWriter ()

@property (strong, nonatomic, readonly) NSFileHandle *outFileHandle;

@end

@implementation CDTBlobDataWriter

#pragma mark - Init object
- (instancetype)init { return [self initWithPath:nil]; }

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        _outFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!_outFileHandle) {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"No handler created with path <%@>", path);

            self = nil;
        }
    }

    return self;
}

#pragma mark - CDTBlobWriter methods
- (void)appendData:(NSData *)data { [self.outFileHandle writeData:data]; }

- (void)closeFile { [self.outFileHandle closeFile]; }

#pragma mark - Public class methods
+ (instancetype)dataWriterWithPath:(NSString *)path
{
    return [[[self class] alloc] initWithPath:path];
}

@end
