//
//  TDMultipartReader.m
//  TouchDB
//
//  Created by Jens Alfke on 1/30/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  http://tools.ietf.org/html/rfc2046#section-5.1
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.

#import "TDMultipartReader.h"

#import "CollectionUtils.h"
#import "Test.h"

// Values of the _state ivar:
enum {
    kAtStart,
    kInPrologue,
    kInBody,
    kInHeaders,
    kAtEnd,
    kFailed,
};

@interface TDMultipartReader ()
- (BOOL)parseContentType:(NSString*)contentType;
@end

static NSString* trim(NSString* str)
{
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@implementation TDMultipartReader

static NSData* kCRLFCRLF;

+ (void)initialize
{
    if (!kCRLFCRLF) kCRLFCRLF = [[NSData alloc] initWithBytes:"\r\n\r\n" length:4];
}

- (id)initWithContentType:(NSString*)contentType delegate:(id<TDMultipartReaderDelegate>)delegate
{
    self = [super init];
    if (self) {
        if (![self parseContentType:contentType]) {
            return nil;
        }
        _delegate = delegate;
        _buffer = [[NSMutableData alloc] initWithCapacity:1024];
        _state = kAtStart;
    }
    return self;
}

- (void)close
{
    _buffer = nil;
    _headers = nil;
    _boundary = nil;
}

- (BOOL)parseContentType:(NSString*)contentType
{
    // ContentType will look like "multipart/foo; boundary=bar"
    // But there may be other ';'-separated params, and the boundary string may be quoted.
    // This is really not a full MIME type parser, but should work well enough for our needs.
    BOOL first = YES;
    for (__strong NSString* param in [contentType componentsSeparatedByString:@";"]) {
        param = trim(param);
        if (first) {
            if (![param hasPrefix:@"multipart/"]) return NO;
            first = NO;
        } else {
            if ([param hasPrefix:@"boundary="]) {
                NSString* boundary = [param substringFromIndex:9];
                if ([boundary hasPrefix:@"\""]) {
                    if (boundary.length < 2 || ![boundary hasSuffix:@"\""]) return NO;
                    boundary = [boundary substringWithRange:NSMakeRange(1, boundary.length - 2)];
                }
                if (boundary.length < 1) return NO;
                boundary = [@"\r\n--" stringByAppendingString:boundary];
                _boundary = [boundary dataUsingEncoding:NSUTF8StringEncoding];
                break;
            }
        }
    }
    return (_boundary != nil);
}

@synthesize headers = _headers;

- (BOOL)parseHeaders:(NSString*)headersStr
{
    if (!headersStr) {
        self.error = @"Unparseable UTF-8 in headers";
        return NO;
    }
    _headers = [[NSMutableDictionary alloc] init];
    BOOL first = YES;
    for (NSString* header in [headersStr componentsSeparatedByString:@"\r\n"]) {
        if (first)
            first = NO;  // first line is just the whitespace between separator and its CRLF
        else {
            NSRange colon = [header rangeOfString:@":"];
            if (colon.length == 0) {
                self.error = @"Missing ':' in header line";
                return NO;
            }
            NSString* key = trim([header substringToIndex:colon.location]);
            NSString* value = trim([header substringFromIndex:NSMaxRange(colon)]);
            _headers[key] = value;
        }
    }
    return YES;
}

- (NSRange)searchFor:(NSData*)pattern from:(NSUInteger)start
{
    return [_buffer rangeOfData:pattern options:0 range:NSMakeRange(start, _buffer.length - start)];
}

- (void)deleteUpThrough:(NSRange)r
{
    [_buffer replaceBytesInRange:NSMakeRange(0, NSMaxRange(r)) withBytes:NULL length:0];
}

- (void)trimBuffer
{
    NSUInteger bufLen = _buffer.length;
    NSUInteger boundaryLen = _boundary.length;
    if (bufLen > boundaryLen) {
        // Leave enough bytes in _buffer that we can find an incomplete boundary string
        NSRange trim = NSMakeRange(0, bufLen - boundaryLen);
        [_delegate appendToPart:[_buffer subdataWithRange:trim]];
        [self deleteUpThrough:trim];
    }
}

- (NSString*)error { return _error; }

- (void)setError:(NSString*)error
{
    _state = kFailed;
    if (!_error) _error = [error copy];
    [self close];
}

- (void)appendData:(NSData*)data
{
    if (!_buffer) return;
    NSUInteger newDataLen = data.length;
    if (newDataLen == 0) return;
    [_buffer appendData:data];

    int nextState;
    do {
        nextState = -1;
        NSUInteger bufLen = _buffer.length;
        switch (_state) {
            case kAtStart: {
                // The entire message might start with a boundary without a leading CRLF.
                NSUInteger testLen = _boundary.length - 2;
                if (bufLen >= testLen) {
                    if (memcmp(_buffer.bytes, _boundary.bytes + 2, testLen) == 0) {
                        [_buffer replaceBytesInRange:NSMakeRange(0, testLen)
                                           withBytes:NULL
                                              length:0];
                        nextState = kInHeaders;
                    } else {
                        nextState = kInPrologue;
                    }
                }
                break;
            }
            case kInPrologue:
            case kInBody: {
                // Look for the next part boundary in the data we just added and the ending bytes of
                // the previous data (in case the boundary string is split across calls)
                if (bufLen < _boundary.length) break;
                NSInteger start = MAX(0, (NSInteger)(bufLen - newDataLen - _boundary.length));
                NSRange r = [self searchFor:_boundary from:start];
                if (r.length > 0) {
                    if (_state == kInBody) {
                        [_delegate
                            appendToPart:[_buffer subdataWithRange:NSMakeRange(0, r.location)]];
                        [_delegate finishedPart];
                    }
                    [self deleteUpThrough:r];
                    nextState = kInHeaders;
                } else {
                    [self trimBuffer];
                }
                break;
            }

            case kInHeaders: {
                // First check for the end-of-message string ("--" after separator):
                if (bufLen >= 2 && memcmp(_buffer.bytes, "--", 2) == 0) {
                    _state = kAtEnd;
                    [self close];
                    return;
                }
                // Otherwise look for two CRLFs that delimit the end of the headers:
                NSRange r = [self searchFor:kCRLFCRLF from:0];
                if (r.length > 0) {
                    NSString* headers = [[NSString alloc] initWithBytesNoCopy:(void*)_buffer.bytes
                                                                       length:r.location
                                                                     encoding:NSUTF8StringEncoding
                                                                 freeWhenDone:NO];
                    BOOL ok = [self parseHeaders:headers];
                    if (!ok) return;  // parseHeaders already set .error
                    [self deleteUpThrough:r];
                    [_delegate startedPart:_headers];
                    nextState = kInBody;
                }
                break;
            }

            default:
                self.error = @"Unexpected data after end of MIME body";
                return;
        }
        if (nextState > 0) _state = nextState;
    } while (nextState >= 0 && _buffer.length > 0);
}

- (BOOL)finished { return _state == kAtEnd; }

- (NSData*)boundary { return _boundary; }

@end
