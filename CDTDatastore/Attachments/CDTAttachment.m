//
//  CDTAttachment.m
//
//
//  Created by Michael Rhodes on 24/03/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTAttachment.h"

#import <GoogleToolboxForMac/GTMNSData+zlib.h>
#import "TDBase64.h"
#import "TD_Database.h"
#import "CDTLogging.h"

@implementation CDTAttachment

- (instancetype)initWithName:(NSString *)name type:(NSString *)type size:(NSInteger)size
{
    self = [super init];
    if (self) {
        _name = name;
        _type = type;
        _size = size;
    }
    return self;
}

- (NSData *)dataFromAttachmentContent
{
    // subclasses should override
    return nil;
}

@end

@interface CDTSavedAttachment ()

// Used to allow the input stream to be opened.
@property (nonatomic, strong, readonly) id<CDTBlobReader> blob;

@end

@implementation CDTSavedAttachment

- (instancetype)initWithBlob:(id<CDTBlobReader>)blob
                        name:(NSString *)name
                        type:(NSString *)type
                        size:(NSInteger)size
                      revpos:(NSInteger)revpos
                    sequence:(SequenceNumber)sequence
                         key:(NSData *)keyData
                    encoding:(TDAttachmentEncoding)encoding
{
    self = [super initWithName:name type:type size:size];
    if (self) {
        _blob = blob;
        _revpos = revpos;
        _sequence = sequence;
        _key = keyData;
        _encoding = encoding;
    }
    return self;
}

- (NSData *)dataFromAttachmentContent
{
    NSData *data = nil;
    NSError *error = nil;

    if (self.encoding == kTDAttachmentEncodingNone) {
        data = [self.blob dataWithError:&error];
    } else if (self.encoding == kTDAttachmentEncodingGZIP) {
        NSData *gzippedData = [self.blob dataWithError:&error];
        data = (gzippedData ? [NSData gtm_dataByInflatingData:gzippedData] : nil);
    } else {
        CDTLogWarn(CDTDOCUMENT_REVISION_LOG_CONTEXT,
                   @"Unknown attachment encoding %i, returning nil", self.encoding);
    }

    if (!data && error) {
        CDTLogWarn(CDTDOCUMENT_REVISION_LOG_CONTEXT, @"Data for attachment not retrieved: %@",
                   error);
    }

    return data;
}

@end

@interface CDTUnsavedDataAttachment ()

@property (nonatomic, strong, readonly) NSData *data;

@end

@implementation CDTUnsavedDataAttachment

- (instancetype)initWithData:(NSData *)data name:(NSString *)name type:(NSString *)type
{
    if (data == nil) {
        CDTLogInfo(CDTDOCUMENT_REVISION_LOG_CONTEXT, @"When creating %@, data was nil, init failed.",
                name);
        return nil;
    }

    self = [super initWithName:name type:type size:data.length];
    if (self) {
        _data = data;
    }
    return self;
}

- (NSData *)dataFromAttachmentContent { return self.data; }

@end

@interface CDTUnsavedFileAttachment ()

// Used to allow the input stream to be opened.
@property (nonatomic, strong, readonly) NSString *filePath;

@end

@implementation CDTUnsavedFileAttachment

- (instancetype)initWithPath:(NSString *)filePath name:(NSString *)name type:(NSString *)type
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        CDTLogInfo(CDTDOCUMENT_REVISION_LOG_CONTEXT, @"When creating %@, no file at %@, init failed.",
                name, filePath);
        return nil;
    }

    self = [super initWithName:name type:type size:-1];
    if (self) {
        _filePath = filePath;
    }
    return self;
}

- (NSData *)dataFromAttachmentContent
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.filePath]) {
        CDTLogInfo(CDTDOCUMENT_REVISION_LOG_CONTEXT,
                @"When creating stream for %@, no file at %@, -getInputStream failed.", self.name,
                self.filePath);
        return nil;
    }

    return
        [NSData dataWithContentsOfFile:self.filePath options:NSDataReadingMappedIfSafe error:nil];
}

@end
