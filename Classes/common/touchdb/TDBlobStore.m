//
//  TDBlobStore.m
//  TouchDB
//
//  Created by Jens Alfke on 12/10/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "TDBlobStore.h"
#import "TDBase64.h"
#import "TDMisc.h"
#import <ctype.h>

#import "TDStatus.h"


#ifdef GNUSTEP
#define NSDataReadingMappedIfSafe NSMappedRead
#define NSDataWritingAtomic NSAtomicWrite
#endif

#define kFileExtension "blob"


@implementation TDBlobStore

- (id) initWithPath: (NSString*)dir error: (NSError**)outError {
    Assert(dir);
    self = [super init];
    if (self) {
        _path = [dir copy];
        BOOL isDir;
        if (![[NSFileManager defaultManager] fileExistsAtPath: dir isDirectory: &isDir] || !isDir) {
            if (![[NSFileManager defaultManager] createDirectoryAtPath: dir
                                           withIntermediateDirectories: NO
                                                            attributes: nil
                                                                 error: outError]) {
                return nil;
            }
        }
    }
    return self;
}




+ (TDBlobKey) keyForBlob: (NSData*)blob {
    NSCParameterAssert(blob);
    TDBlobKey key;
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    SHA1_Update(&ctx, blob.bytes, blob.length);
    SHA1_Final(key.bytes, &ctx);
    return key;
}

+ (NSData*) keyDataForBlob: (NSData*)blob {
    TDBlobKey key = [self keyForBlob: blob];
    return [NSData dataWithBytes: &key length: sizeof(key)];
}


@synthesize path=_path;


- (NSString*) pathForKey: (TDBlobKey)key {
    char out[2*sizeof(key.bytes) + 1 + strlen(kFileExtension) + 1];
    char *dst = &out[0];
    for( size_t i=0; i<sizeof(key.bytes); i+=1 )
        dst += sprintf(dst,"%02X", key.bytes[i]);
    strlcat(out, ".", sizeof(out));
    strlcat(out, kFileExtension, sizeof(out));
    NSString* name =  [[NSString alloc] initWithCString: out encoding: NSASCIIStringEncoding];
    NSString* path = [_path stringByAppendingPathComponent: name];
    return path;
}


+ (BOOL) getKey: (TDBlobKey*)outKey forFilename: (NSString*)filename {
    if (filename.length != 2*sizeof(TDBlobKey) + 1 + strlen(kFileExtension))
        return NO;
    if (![filename hasSuffix: @"."kFileExtension])
        return NO;
    if (outKey) {
        uint8_t* dst = &outKey->bytes[0];
        for (unsigned i=0; i<sizeof(TDBlobKey); ++i) {
            unichar digit1 = [filename characterAtIndex: 2*i];
            unichar digit2 = [filename characterAtIndex: 2*i+1];
            if (!isxdigit(digit1) || !isxdigit(digit2))
                return NO;
            *dst++ = (uint8_t)( 16*digittoint(digit1) + digittoint(digit2) );
        }
    }
    return YES;
}


- (NSData*) blobForKey: (TDBlobKey)key {
    NSString* path = [self pathForKey: key];
    return [NSData dataWithContentsOfFile: path options: NSDataReadingMappedIfSafe error: NULL];
}

- (NSInputStream*) blobInputStreamForKey: (TDBlobKey)key
                                  length: (UInt64*)outLength
{
    NSString* path = [self pathForKey: key];
    if (outLength) {
        NSDictionary* info = [[NSFileManager defaultManager] attributesOfItemAtPath: path
                                                                              error: NULL];
        if (!info)
            return nil;
        *outLength = [info fileSize];
    }
    return [NSInputStream inputStreamWithFileAtPath: path];
}

- (BOOL) storeBlob: (NSData*)blob
       creatingKey: (TDBlobKey*)outKey
{
    *outKey = [[self class] keyForBlob: blob];
    NSString* path = [self pathForKey: *outKey];
    if ([[NSFileManager defaultManager] isReadableFileAtPath: path])
        return YES;
    NSError* error;
    if (![blob writeToFile: path
                   options: NSDataWritingAtomic
#if TARGET_OS_IPHONE
                            | NSDataWritingFileProtectionCompleteUnlessOpen
#endif
                     error: &error]) {
        Warn(@"TDBlobStore: Couldn't write to %@: %@", path, error);
        return NO;
    }
    return YES;
}

- (BOOL) storeBlobFromStream: (NSInputStream*)inputStream
                 creatingKey: (TDBlobKey*)outKey
                  fileLength: (NSInteger*)outFileLength
                       error:(NSError * __autoreleasing *)outError
{
    if ([inputStream streamStatus] != NSStreamStatusOpen) {
        Warn(@"TDBlobStore: inputStream must be opened before calling"
             @"storeBlobFromStream:creatingKey:fileLength");
        
        if (outError) {
            NSString *desc = NSLocalizedString(@"Input stream not open.", 
                                               nil);
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: desc};
            *outError = [NSError errorWithDomain:TDHTTPErrorDomain
                                            code:kTDStatusAttachmentStreamError
                                        userInfo:userInfo];
        }
        
        return NO;
    }
    
    // Open a temporary file in the store's temporary directory
    NSString* filename = [TDCreateUUID() stringByAppendingPathExtension: @"blobtmp"];
    NSString* tmpPath = [[self.tempDir stringByAppendingPathComponent: filename] copy];
    if (!tmpPath) {
        return NO;
    }
    
    // write to the temp file, sha-ing as we go
    uint8_t buf[4096];
    int bufSize = 4096;
    NSInteger bytesRead, totalLength = 0;
    BOOL errorWritingFileFromStream = NO;
    
    NSOutputStream *oStream = [[NSOutputStream alloc] initToFileAtPath:tmpPath append:NO];
    [oStream open];
    
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    
    while ([inputStream hasBytesAvailable]) {
        if ([oStream hasSpaceAvailable]) {
            bytesRead = [inputStream read:buf maxLength:bufSize];
            if (bytesRead > 0) {
                [oStream write:buf maxLength:bytesRead];
                CC_SHA1_Update(&ctx, buf, (CC_LONG)bytesRead); // max is 4096, safe to lose precision
                totalLength += bytesRead;
            }
        } else {
            // Disk ran out of space
            Warn(@"TDBlobStore: Couldn't write to %@: no space left on destination device", tmpPath);
            errorWritingFileFromStream = YES;
            
            if (outError) {
                NSString *desc = NSLocalizedString(@"Not enough space on disk for attachment.", 
                                                   nil);
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey: desc};
                *outError = [NSError errorWithDomain:TDHTTPErrorDomain
                                                code:kTDStatusAttachmentDiskSpaceError
                                            userInfo:userInfo];
            }
            
            break;
        }
    }
    
    CC_SHA1_Final((*outKey).bytes, &ctx);
    
    [oStream close];
    oStream = nil;
    
    *outFileLength = totalLength;
    
    //
    // Move the downloaded file to the right place
    //
    
    NSFileManager* fm = [NSFileManager defaultManager];
    
    void (^removeTmpFile)(void) = ^{ 
        // Non-fatal so we don't return the error
        NSError* error;
        if (![fm removeItemAtPath:tmpPath error:&error]) {
            Warn(@"TDBlobStore: remove temp file at %@: %@", tmpPath, error);
        } 
    };
    
    if (errorWritingFileFromStream) {
        removeTmpFile();
        return NO;
    }
    
    // move to the right place
    NSString* finalPath = [self pathForKey: *outKey];
    
    if ([fm isReadableFileAtPath: finalPath]) {  // we already have this file
        removeTmpFile();
        return YES;
    }
    
    BOOL moveSuccess = [fm moveItemAtPath:tmpPath
                                   toPath:finalPath
                                    error:outError];
    if (!moveSuccess) {
        Warn(@"TDBlobStore: Couldn't move from %@ to %@: %@", tmpPath, finalPath, *outError);
        removeTmpFile();
        return NO;
    }
    
#if TARGET_OS_IPHONE
    NSDictionary* attrs = @{ NSFileProtectionKey: NSFileProtectionCompleteUnlessOpen };
    BOOL attrSuccess = [fm setAttributes:attrs
                            ofItemAtPath:finalPath
                                   error:outError];
    if (!attrSuccess) {  // don't fail on this
        Warn(@"TDBlobStore: Non-fatal, couldn't set file protection on %@: %@", 
             finalPath, *outError);
    }
#endif
    
    return YES;
}


- (NSArray*) allKeys {
    NSArray* blob = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: _path
                                                                            error: NULL];
    if (!blob)
        return nil;
    return [blob my_map: ^(id filename) {
        TDBlobKey key;
        if ([[self class] getKey: &key forFilename: filename])
            return [NSData dataWithBytes: &key length: sizeof(key)];
        else
            return (id)nil;
    }];
}


- (NSUInteger) count {
    NSUInteger n = 0;
    NSFileManager* fmgr = [NSFileManager defaultManager];
    for (NSString* filename in [fmgr contentsOfDirectoryAtPath: _path error: NULL]) {
        if ([[self class] getKey: NULL forFilename: filename])
            ++n;
    }
    return n;
}


- (UInt64) totalDataSize {
    UInt64 total = 0;
    NSFileManager* fmgr = [NSFileManager defaultManager];
    for (NSString* filename in [fmgr contentsOfDirectoryAtPath: _path error: NULL]) {
        if ([[self class] getKey: NULL forFilename: filename]) {
            NSString* itemPath = [_path stringByAppendingPathComponent: filename];
            NSDictionary* attrs = [fmgr attributesOfItemAtPath: itemPath error: NULL];
            if (attrs)
                total += attrs.fileSize;
        }
    }
    return total;
}


- (NSInteger) deleteBlobsExceptWithKeys: (NSSet*)keysToKeep {
    NSFileManager* fmgr = [NSFileManager defaultManager];
    NSArray* blob = [fmgr contentsOfDirectoryAtPath: _path error: NULL];
    if (!blob)
        return 0;
    NSUInteger numDeleted = 0;
    BOOL errors = NO;
    NSMutableData* curKeyData = [NSMutableData dataWithLength: sizeof(TDBlobKey)];
    for (NSString* filename in blob) {
        if ([[self class] getKey: curKeyData.mutableBytes forFilename: filename]) {
            if (![keysToKeep containsObject: curKeyData]) {
                NSError* error;
                if ([fmgr removeItemAtPath: [_path stringByAppendingPathComponent: filename]
                                 error: &error])
                    ++numDeleted;
                else {
                    errors = YES;
                    Warn(@"%@: Failed to delete '%@': %@", self, filename, error);
                }
            }
        }
    }
    return errors ? -1 : numDeleted;
}


- (NSString*) tempDir {
    if (!_tempDir) {
        // Find a temporary directory suitable for files that will be moved into the store:
#ifdef GNUSTEP
        _tempDir = [NSTemporaryDirectory() copy];
#else
        NSError* error;
        NSURL* parentURL = [NSURL fileURLWithPath: _path isDirectory: YES];
        NSURL* tempDirURL = [[NSFileManager defaultManager]
                                                 URLForDirectory: NSItemReplacementDirectory
                                                 inDomain: NSUserDomainMask
                                                 appropriateForURL: parentURL
                                                 create: YES error: &error];
        _tempDir = [tempDirURL.path copy];
        Log(@"TDBlobStore %@ created tempDir %@", _path, _tempDir);
        if (!_tempDir)
            Warn(@"TDBlobStore: Unable to create temp dir: %@", error);
#endif
    }
    return _tempDir;
}


@end




@implementation TDBlobStoreWriter

@synthesize length=_length, blobKey=_blobKey;

- (id) initWithStore: (TDBlobStore*)store {
    self = [super init];
    if (self) {
        _store = store;
        SHA1_Init(&_shaCtx);
        MD5_Init(&_md5Ctx);

        // Open a temporary file in the store's temporary directory:
        NSString* filename = [TDCreateUUID() stringByAppendingPathExtension: @"blobtmp"];
        _tempPath = [[_store.tempDir stringByAppendingPathComponent: filename] copy];
        if (!_tempPath) {
            return nil;
        }
        NSDictionary* attributes = nil;
#if TARGET_OS_IPHONE
        attributes = @{NSFileProtectionKey: NSFileProtectionCompleteUnlessOpen};
#endif
        if (![[NSFileManager defaultManager] createFileAtPath: _tempPath
                                                     contents: nil
                                                   attributes: attributes]) {
            return nil;
        }
        _out = [NSFileHandle fileHandleForWritingAtPath: _tempPath];
        if (!_out) {
            return nil;
        }
    }
    return self;
}

- (void) appendData: (NSData*)data {
    [_out writeData: data];
    NSUInteger dataLen = data.length;
    _length += dataLen;
    SHA1_Update(&_shaCtx, data.bytes, dataLen);
    MD5_Update(&_md5Ctx, data.bytes, dataLen);
}

- (void) closeFile {
    [_out closeFile];
    _out = nil;
}

- (void) finish {
    Assert(_out, @"Already finished");
    [self closeFile];
    SHA1_Final(_blobKey.bytes, &_shaCtx);
    MD5_Final(_MD5Digest.bytes, &_md5Ctx);
}

- (NSString*) MD5DigestString {
    return [@"md5-" stringByAppendingString: [TDBase64 encode: &_MD5Digest
                                                       length: sizeof(_MD5Digest)]];
}

- (NSString*) SHA1DigestString {
    return [@"sha1-" stringByAppendingString: [TDBase64 encode: &_blobKey
                                                        length: sizeof(_blobKey)]];
}

- (BOOL) install {
    if (!_tempPath)
        return YES;  // already installed
    Assert(!_out, @"Not finished");
    // Move temp file to correct location in blob store:
    NSString* dstPath = [_store pathForKey: _blobKey];
    if ([[NSFileManager defaultManager] moveItemAtPath: _tempPath
                                                toPath: dstPath error:NULL]) {
        _tempPath = nil;
    } else {
        // If the move fails, assume it means a file with the same name already exists; in that
        // case it must have the identical contents, so we're still OK.
        [self cancel];
    }
    return YES;
}

- (void) cancel {
    [self closeFile];
    if (_tempPath) {
        [[NSFileManager defaultManager] removeItemAtPath: _tempPath error: NULL];
        _tempPath = nil;
    }
}

- (void) dealloc {
    [self cancel];      // Close file, and delete it if it hasn't been installed yet
}


@end
