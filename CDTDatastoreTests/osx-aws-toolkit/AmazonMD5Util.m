/*
 * Copyright 2010-2011 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 *
 * Modifications Copyright 2014 Cloudant, Inc.
 *  - Removed -base64md5FromData: for this release.
 *  - Changed -base64md5FromStream: to return NSData for this release.
 *
 */

#import "AmazonMD5Util.h"
#import <CommonCrypto/CommonDigest.h>
//#import "AmazonAuthUtils.h"


#define BUFFER_SIZE    4096


@implementation AmazonMD5Util


+(NSData *)base64md5FromStream:(NSInputStream *)inputStream
{
    if ( [inputStream streamStatus] == NSStreamStatusOpen) {
        CC_MD5_CTX hashObject;
        CC_MD5_Init(&hashObject);

        uint8_t buffer[BUFFER_SIZE];
        while ( [inputStream hasBytesAvailable]) {
            NSInteger result = [inputStream read:buffer maxLength:BUFFER_SIZE];

            if (result == -1) {
                @throw [NSException exceptionWithName : @"StreamException" reason : @"Unable to properly read stream." userInfo : nil];
            }

            CC_MD5_Update(&hashObject, (const void *)buffer, (CC_LONG)result);
        }

        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(digest, &hashObject);

        NSData *md5 = [[NSData alloc] initWithBytes:digest length:CC_MD5_DIGEST_LENGTH];
        return md5;
    }

    return nil;
}

@end
