//
//  TDBlobStore.h
//  TouchDB
//
//  Created by Jens Alfke on 12/10/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef GNUSTEP
#import <openssl/md5.h>
#import <openssl/sha.h>
#else
#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>
#endif


/** Key identifying a data blob. This happens to be a SHA-1 digest. */
typedef struct TDBlobKey {
    uint8_t bytes[SHA_DIGEST_LENGTH];
} TDBlobKey;


/** A persistent content-addressable store for arbitrary-size data blobs.
    Each blob is stored as a file named by its SHA-1 digest. */
@interface TDBlobStore : NSObject
{
    NSString* _path;
    NSString* _tempDir;
}

- (id) initWithPath: (NSString*)dir error: (NSError**)outError;

- (NSData*) blobForKey: (TDBlobKey)key;
- (NSInputStream*) blobInputStreamForKey: (TDBlobKey)key
                                  length: (UInt64*)outLength;

- (BOOL) storeBlob: (NSData*)blob
       creatingKey: (TDBlobKey*)outKey;

/**
 Read available bytes from an open stream into a
 file within the blob store.
 
 It is the caller's responsibility to make sure that the
 stream is opened and closed, and that the stream is at
 the right position to start reading from.
 
 If return value is NO, values for out parameters are 
 not usable.
 
 @param stream open stream to read from.
 @param outKey out parameter to receive the key generated
 @param outFileLength out parameter to receive total number of bytes read from the stream
 
 @return BOOL indicating whether the stream was successfully stored.
 */
- (BOOL) storeBlobFromStream: (NSInputStream*)stream
                 creatingKey: (TDBlobKey*)outKey
                  fileLength: (NSInteger*)outFileLength;

@property (readonly) NSString* path;
@property (readonly) NSUInteger count;
@property (readonly) NSArray* allKeys;
@property (readonly) UInt64 totalDataSize;

- (NSInteger) deleteBlobsExceptWithKeys: (NSSet*)keysToKeep;

+ (TDBlobKey) keyForBlob: (NSData*)blob;
+ (NSData*) keyDataForBlob: (NSData*)blob;

/** Returns the path of the file storing the attachment with the given key, or nil.
    DO NOT MODIFY THIS FILE! */
- (NSString*) pathForKey: (TDBlobKey)key;

@end



typedef struct {
    uint8_t bytes[MD5_DIGEST_LENGTH];
} TDMD5Key;


/** Lets you stream a large attachment to a TDBlobStore asynchronously, e.g. from a network download. */
@interface TDBlobStoreWriter : NSObject {
@private
    TDBlobStore* _store;
    NSString* _tempPath;
    NSFileHandle* _out;
    UInt64 _length;
    SHA_CTX _shaCtx;
    MD5_CTX _md5Ctx;
    TDBlobKey _blobKey;
    TDMD5Key _MD5Digest;
}

- (id) initWithStore: (TDBlobStore*)store;

/** Appends data to the blob. Call this when new data is available. */
- (void) appendData: (NSData*)data;

/** Call this after all the data has been added. */
- (void) finish;

/** Call this to cancel before finishing the data. */
- (void) cancel;

/** Installs a finished blob into the store. */
- (BOOL) install;

/** The number of bytes in the blob. */
@property (readonly) UInt64 length;

/** After finishing, this is the key for looking up the blob through the TDBlobStore. */
@property (readonly) TDBlobKey blobKey;

/** After finishing, this is the MD5 digest of the blob, in base64 with an "md5-" prefix.
    (This is useful for compatibility with CouchDB, which stores MD5 digests of attachments.) */
@property (readonly) NSString* MD5DigestString;
@property (readonly) NSString* SHA1DigestString;

@end
