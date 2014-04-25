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

-(NSData *)getInputStream
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
{
    self = [super initWithName:name
                          type:type
                          size:size];
    if (self) {
        _filePath = filePath;
        _revpos = revpos;
        _sequence = sequence;
        _key = keyData;
    }
    return self;
}

-(NSInputStream *)getInputStream
{
    return [NSInputStream inputStreamWithFileAtPath:self.filePath];
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

-(NSInputStream *)getInputStream
{
    return [NSInputStream inputStreamWithData:self.data];
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

-(NSInputStream *)getInputStream
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.filePath]) {
        return nil;
    }
    
    return [NSInputStream inputStreamWithFileAtPath:self.filePath];
}

@end
