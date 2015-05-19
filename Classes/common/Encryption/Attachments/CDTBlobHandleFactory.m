//
//  CDTBlobHandleFactory.m
//  CloudantSync
//
//  Created by Enrique de la Torre Fernandez on 19/05/2015.
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

#import "CDTBlobHandleFactory.h"

#import "CDTBlobDataReader.h"
#import "CDTBlobDataWriter.h"
#import "CDTBlobDataMultipartWriter.h"

#import "CDTBlobEncryptedDataReader.h"
#import "CDTBlobEncryptedDataWriter.h"
#import "CDTBlobEncryptedDataMultipartWriter.h"

@interface CDTBlobHandleFactory ()

@property (strong, nonatomic, readonly) CDTEncryptionKey *encryptionKeyOrNil;

@end

@implementation CDTBlobHandleFactory

#pragma mark - Init object
- (instancetype)init { return [self initWithEncryptionKeyProvider:nil]; }

- (instancetype)initWithEncryptionKeyProvider:(id<CDTEncryptionKeyProvider>)provider
{
    Assert(provider, @"Key provider is mandatory. Supply a CDTNilEncryptionKeyProvider instead.");

    self = [super init];
    if (self) {
        _encryptionKeyOrNil = [provider encryptionKey];
    }

    return self;
}

#pragma mark - Public methods
- (id<CDTBlobReader>)readerWithPath:(NSString *)path
{
    return (
        self.encryptionKeyOrNil
            ? [CDTBlobEncryptedDataReader readerWithPath:path encryptionKey:self.encryptionKeyOrNil]
            : [CDTBlobDataReader readerWithPath:path]);
}

- (id<CDTBlobWriter>)writer
{
    return (self.encryptionKeyOrNil
                ? [CDTBlobEncryptedDataWriter writerWithEncryptionKey:self.encryptionKeyOrNil]
                : [CDTBlobDataWriter writer]);
}

- (id<CDTBlobMultipartWriter>)multipartWriter
{
    return (self.encryptionKeyOrNil ? [CDTBlobEncryptedDataMultipartWriter
                                          multipartWriterWithEncryptionKey:self.encryptionKeyOrNil]
                                    : [CDTBlobDataMultipartWriter multipartWriter]);
}

#pragma mark - Public class methods
+ (instancetype)factoryWithEncryptionKeyProvider:(id<CDTEncryptionKeyProvider>)provider
{
    return [[[self class] alloc] initWithEncryptionKeyProvider:provider];
}

@end
