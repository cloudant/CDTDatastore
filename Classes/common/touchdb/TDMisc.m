//
//  TDMisc.m
//  TouchDB
//
//  Created by Jens Alfke on 1/13/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.

#import "TDMisc.h"

#import "CollectionUtils.h"
#import <errno.h>

#ifdef GNUSTEP
#import <openssl/sha.h>
#import <uuid/uuid.h>  // requires installing "uuid-dev" package on Ubuntu
#else
#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#endif

NSString* TDCreateUUID()
{
#ifdef GNUSTEP
    uuid_t uuid;
    uuid_generate(uuid);
    char cstr[37];
    uuid_unparse_lower(uuid, cstr);
    return [[[NSString alloc] initWithCString:cstr encoding:NSASCIIStringEncoding] autorelease];
#else

    CFUUIDRef uuid = CFUUIDCreate(NULL);
#ifdef __OBJC_GC__
    CFStringRef uuidStrRef = CFUUIDCreateString(NULL, uuid);
    NSString* uuidStr = (NSString*)uuidStrRef;
    CFRelease(uuidStrRef);
#else
    NSString* uuidStr = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, uuid);
#endif
    CFRelease(uuid);
    return uuidStr;
#endif
}

NSData* TDSHA1Digest(NSData* input)
{
    unsigned char digest[SHA_DIGEST_LENGTH];
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    SHA1_Update(&ctx, input.bytes, input.length);
    SHA1_Final(digest, &ctx);
    return [NSData dataWithBytes:&digest length:sizeof(digest)];
}

NSData* TDSHA256Digest(NSData* input)
{
    unsigned char digest[SHA256_DIGEST_LENGTH];
    SHA256_CTX ctx;
    SHA256_Init(&ctx);
    SHA256_Update(&ctx, input.bytes, input.length);
    SHA256_Final(digest, &ctx);
    return [NSData dataWithBytes:&digest length:sizeof(digest)];
}

NSString* TDHexSHA1Digest(NSData* input)
{
    unsigned char digest[SHA_DIGEST_LENGTH];
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    SHA1_Update(&ctx, input.bytes, input.length);
    SHA1_Final(digest, &ctx);
    return TDHexFromBytes(&digest, sizeof(digest));
}

NSString* TDHexFromBytes(const void* bytes, size_t length)
{
    char hex[2 * length + 1];
    char* dst = &hex[0];
    for (size_t i = 0; i < length; i += 1)
        dst += sprintf(dst, "%02x", ((const uint8_t*)bytes)[i]);  // important: generates lowercase!
    return [[NSString alloc] initWithBytes:hex length:2 * length encoding:NSASCIIStringEncoding];
}

NSData* TDHMACSHA1(NSData* key, NSData* data)
{
    UInt8 hmac[SHA_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, key.bytes, key.length, data.bytes, data.length, &hmac);
    return [NSData dataWithBytes:hmac length:sizeof(hmac)];
}

NSData* TDHMACSHA256(NSData* key, NSData* data)
{
    UInt8 hmac[SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, data.bytes, data.length, &hmac);
    return [NSData dataWithBytes:hmac length:sizeof(hmac)];
}

NSComparisonResult TDSequenceCompare(SequenceNumber a, SequenceNumber b)
{
    SInt64 diff = a - b;
    return diff > 0 ? 1 : (diff < 0 ? -1 : 0);
}

NSString* TDEscapeID(NSString* docOrRevID)
{
#ifdef GNUSTEP
    docOrRevID = [docOrRevID stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    docOrRevID = [docOrRevID stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
    docOrRevID = [docOrRevID stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
    return docOrRevID;
#else
    CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)docOrRevID, NULL, (CFStringRef) @"?&/", kCFStringEncodingUTF8);
#ifdef __OBJC_GC__
    return NSMakeCollectable(escaped);
#else
    return (__bridge_transfer NSString*)escaped;
#endif

#endif
}

NSString* TDEscapeURLParam(NSString* param)
{
#ifdef GNUSTEP
    param = [param stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    param = [param stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
    return param;
#else
    CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)param, NULL, (CFStringRef) @"&", kCFStringEncodingUTF8);
#ifdef __OBJC_GC__
    return NSMakeCollectable(escaped);
#else
    return (__bridge_transfer NSString*)escaped;
#endif
#endif
}

NSString* TDQuoteString(NSString* param)
{
    NSMutableString* quoted = [param mutableCopy];
    [quoted replaceOccurrencesOfString:@"\\"
                            withString:@"\\\\"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, quoted.length)];
    [quoted replaceOccurrencesOfString:@"\""
                            withString:@"\\\""
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, quoted.length)];
    [quoted insertString:@"\"" atIndex:0];
    [quoted appendString:@"\""];
    return quoted;
}

NSString* TDUnquoteString(NSString* param)
{
    if (![param hasPrefix:@"\""]) return param;
    if (![param hasSuffix:@"\""] || param.length < 2) return nil;
    param = [param substringWithRange:NSMakeRange(1, param.length - 2)];
    if ([param rangeOfString:@"\\"].length == 0) return param;
    NSMutableString* unquoted = [param mutableCopy];
    for (NSUInteger pos = 0; pos < unquoted.length;) {
        NSRange r = [unquoted rangeOfString:@"\\"
                                    options:NSLiteralSearch
                                      range:NSMakeRange(pos, unquoted.length - pos)];
        if (r.length == 0) break;
        [unquoted deleteCharactersInRange:r];
        pos = r.location + 1;
        if (pos > unquoted.length) return nil;
    }
    return unquoted;
}

BOOL TDIsOfflineError(NSError* error)
{
    NSString* domain = error.domain;
    NSInteger code = error.code;
    if ($equal(domain, NSURLErrorDomain))
        return code == NSURLErrorDNSLookupFailed || code == NSURLErrorNotConnectedToInternet
#ifndef GNUSTEP
               || code == NSURLErrorInternationalRoamingOff
#endif
            ;
    return NO;
}

BOOL TDIsFileExistsError(NSError* error)
{
    NSString* domain = error.domain;
    NSInteger code = error.code;
    return ($equal(domain, NSPOSIXErrorDomain) && code == EEXIST)
#ifndef GNUSTEP
           || ($equal(domain, NSCocoaErrorDomain) && code == NSFileWriteFileExistsError)
#endif
        ;
}

BOOL TDMayBeTransientError(NSError* error)
{
    NSString* domain = error.domain;
    NSInteger code = error.code;
    if ([domain isEqualToString:NSURLErrorDomain]) {
        return code == NSURLErrorTimedOut || code == NSURLErrorCannotConnectToHost ||
               code == NSURLErrorNetworkConnectionLost;
    } else if ([domain isEqualToString:TDHTTPErrorDomain]) {
        // Internal Server Error, Bad Gateway, Service Unavailable or Gateway Timeout:
        return code == 500 || code == 502 || code == 503 || code == 504;
    } else if ([domain isEqualToString:NSPOSIXErrorDomain]) {
        //connection reset by peer see errno.h
        return code == ECONNRESET;
    } else {
        return NO;
    }
}

NSURL* TDURLWithoutQuery(NSURL* url)
{
#ifdef GNUSTEP
    // No CFURL on GNUstep :(
    NSString* str = url.absoluteString;
    NSRange q = [str rangeOfString:@"?"];
    if (q.length == 0) return url;
    return [NSURL URLWithString:[str substringToIndex:q.location]];
#else
    // Strip anything after the URL's path (i.e. the query string)
    CFURLRef cfURL = (__bridge CFURLRef)url;
    CFRange range = CFURLGetByteRangeForComponent(cfURL, kCFURLComponentResourceSpecifier, NULL);
    if (range.length == 0) {
        return url;
    } else {
        CFIndex size = CFURLGetBytes(cfURL, NULL, 0);
        if (size > 8000) return url;  // give up
        UInt8 bytes[size];
        CFURLGetBytes(cfURL, bytes, size);
        NSURL* url = (__bridge_transfer NSURL*)CFURLCreateWithBytes(NULL, bytes, range.location - 1,
                                                                    kCFStringEncodingUTF8, NULL);
#ifdef __OBJC_GC__
        return NSMakeCollectable(url);
#else
        return url;
#endif
    }
#endif
}

NSURL* TDAppendToURL(NSURL* baseURL, NSString* toAppend)
{
    if (toAppend.length == 0 || $equal(toAppend, @".")) return baseURL;
    NSMutableString* urlStr = baseURL.absoluteString.mutableCopy;
    if (![urlStr hasSuffix:@"/"]) [urlStr appendString:@"/"];
    [urlStr appendString:toAppend];
    return [NSURL URLWithString:urlStr];
}

NSString* TDCleanURLtoString(NSURL* url)
{
    if ([url.password length] != 0) {
        NSString *cleanedURL = [NSString stringWithFormat:@"%@://%@:*****@%@",
                                url.scheme, url.user, url.host];
        
        if (url.port) {
            cleanedURL = [cleanedURL stringByAppendingFormat:@":%@", url.port];
        }

        if (url.path) {
            cleanedURL = [cleanedURL stringByAppendingString:url.path];
        }
        
        if (url.query) {
            cleanedURL = [cleanedURL stringByAppendingFormat:@"?%@", url.query];
        }

        if (url.fragment) {
            cleanedURL = [cleanedURL stringByAppendingFormat:@"#%@", url.fragment];
        }
        
        return cleanedURL;
    }
    else {
        return [url absoluteString];
    }
}

