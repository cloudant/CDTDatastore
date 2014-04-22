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

-(NSData *)getInputStream
{
    // subclasses should override
    return nil;
}

+(CDTAttachment*)attachmentWithData:(NSData*)data
                               name:(NSString*)name
                               type:(NSString*)type
{
    CDTUnsavedDataAttachment *att = [[CDTUnsavedDataAttachment alloc] init];
    att.data = data;
    att.name = name;
    att.type = type;
    att.size = data.length;
    return att;
}

@end

@interface CDTSavedAttachment ()

// Used to allow the input stream to be opened.
@property (nonatomic,readonly) NSString *filePath;

@end

@implementation CDTSavedAttachment

-(instancetype) initWithFilePath:(NSString*)filePath
{
    self = [super init];
    if (self) {
        _filePath = filePath;
    }
    return self;
}

-(NSInputStream *)getInputStream
{
    return [NSInputStream inputStreamWithFileAtPath:self.filePath];
}

@end

@implementation CDTUnsavedDataAttachment

-(NSInputStream *)getInputStream
{
    return [NSInputStream inputStreamWithData:self.data];
}

@end
