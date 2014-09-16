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

#import "GTMNSData+zlib.h"
#import "TDBase64.h"
#import "TD_Database.h"

@implementation CDTAttachment

-(instancetype) initWithName:(NSString*)name
                        type:(NSString*)type
                        size:(NSInteger)size
{
    self = [super init];
    if (self) {
        _name = name;
        _type = type;
        _size = size;
    }
    return self;
}

-(NSData *)dataFromAttachmentContent
{
    // subclasses should override
    return nil;
}

@end

@interface CDTSavedAttachment ()

// Used to allow the input stream to be opened.
@property (nonatomic,strong,readonly) NSString *filePath;

@end

@implementation CDTSavedAttachment

-(instancetype) initWithPath:(NSString*)filePath
                        name:(NSString*)name
                        type:(NSString*)type
                        size:(NSInteger)size
                      revpos:(NSInteger)revpos
                    sequence:(SequenceNumber)sequence
                         key:(NSData*)keyData
                    encoding:(TDAttachmentEncoding)encoding;
{
    self = [super initWithName:name
                          type:type
                          size:size];
    if (self) {
        _filePath = filePath;
        _revpos = revpos;
        _sequence = sequence;
        _key = keyData;
        _encoding = encoding;
    }
    return self;
}

- (NSData*)dataFromAttachmentContent
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.filePath]) {
        LogTo(CDTAttachment, 
              @"When creating stream for saved attachment %@, no file at %@, "
              @"-dataFromAttachmentContent failed.",
              self.name,
              self.filePath);
        return nil;
    }
    
    if (self.encoding == kTDAttachmentEncodingNone) {
        return [NSData dataWithContentsOfFile:self.filePath
                                      options:NSDataReadingMappedIfSafe
                                        error:nil];
    } else if (self.encoding == kTDAttachmentEncodingGZIP) {
        NSData *gzippedData = [NSData dataWithContentsOfFile:self.filePath
                                                     options:NSDataReadingMappedIfSafe
                                                       error:nil];
        NSData *inflatedData = [NSData gtm_dataByInflatingData:gzippedData];
        return inflatedData;
    } else {
        Warn(@"Unknown attachment encoding %i, returning nil", self.encoding);
        return nil;
    }
    
}

@end

@interface CDTUnsavedDataAttachment () 

@property (nonatomic,strong,readonly) NSData* data;

@end

@implementation CDTUnsavedDataAttachment

-(instancetype) initWithData:(NSData*)data
                        name:(NSString*)name
                        type:(NSString*)type
{
    if (data ==nil) {
        LogTo(CDTAttachment, 
              @"When creating %@, data was nil, init failed.",
              name);
        return nil;
    }
    
    self = [super initWithName:name
                          type:type
                          size:data.length];
    if (self) {
        _data = data;
    }
    return self;
}

- (NSData*)dataFromAttachmentContent
{
    return self.data;
}

@end

@interface CDTUnsavedFileAttachment ()

// Used to allow the input stream to be opened.
@property (nonatomic,strong,readonly) NSString *filePath;

@end

@implementation CDTUnsavedFileAttachment

-(instancetype) initWithPath:(NSString*)filePath
                        name:(NSString*)name
                        type:(NSString*)type
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        LogTo(CDTAttachment, 
              @"When creating %@, no file at %@, init failed.",
              name,
              filePath);
        return nil;
    }
    
    self = [super initWithName:name
                          type:type
                          size:-1];
    if (self) {
        _filePath = filePath;
    }
    return self;
}

- (NSData*)dataFromAttachmentContent
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.filePath]) {
        LogTo(CDTAttachment, 
              @"When creating stream for %@, no file at %@, -getInputStream failed.",
              self.name,
              self.filePath);
        return nil;
    }
    
    return [NSData dataWithContentsOfFile:self.filePath
                                  options:NSDataReadingMappedIfSafe
                                    error:nil];
}

@end

@interface CDTRemoteAttachment ()

@property  NSData * attachmentData;
@property (readonly) NSURL * attachmentURL;

@end

@implementation CDTRemoteAttachment

+(CDTRemoteAttachment *)createAttachmentForName:(NSString *)name
                                   withJSONData:(NSDictionary *) jsonData
                                    forDocument:(NSURL*)document
                                          error:(NSError * __autoreleasing *) error
{
    NSNumber * stub = [jsonData objectForKey:@"stub"];
    NSNumber * length = [jsonData objectForKey:@"length"];
    NSString * digest = [jsonData objectForKey:@"digest"];
    NSNumber * revpos = [jsonData objectForKey:@"revpos"];
    NSString * contentType = [jsonData objectForKey:@"content_type"];
    NSString * data = [jsonData objectForKey:@"data"];
    NSData * decodedData = nil;
    
    if(![stub boolValue]){
        decodedData =  [TDBase64 decode:data];
        
        if(!decodedData){
            *error = TDStatusToNSError(kTDStatusAttachmentError, nil);
            return nil;
        }
    }
    
    return [[CDTRemoteAttachment alloc]initWithDocumentURL:document name:name type:contentType size:[length integerValue] data:decodedData];
}

-(id)initWithDocumentURL:(NSURL*)document name:(NSString *)name type:(NSString *)type size:(NSInteger)size data:(NSData*)data
{
    self = [super initWithName:name type:type size:size];
    
    if(self){
        _attachmentData = data;
        _attachmentURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"./%@",name]
                                         relativeToURL:document];
    }
    
    return self;
}

-(NSData*)dataFromAttachmentContent
{
    if(!self.attachmentData){
        self.attachmentData = [NSData dataWithContentsOfURL:self.attachmentURL];
    }

     return self.attachmentData;
}

@end

