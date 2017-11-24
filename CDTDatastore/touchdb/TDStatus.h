//
//  TDStatus.h
//  TouchDB
//
//  Created by Jens Alfke on 4/5/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* const TDInternalErrorDomain = @"TDInternalError";

typedef NS_ENUM(NSInteger, TDInternalErrors) {
    /**
     * TDReplicator: local database deleted during replication
     */
    TDReplicatorErrorLocalDatabaseDeleted  = 1001,
    TDReplicatorErrorNetworkOffline = 1002
};

/** TouchDB internal status/error codes. Superset of HTTP status codes. */
typedef NS_ENUM(NSInteger, TDStatus) {
    kTDStatusOK = 200,
    kTDStatusCreated = 201,
    kTDStatusAccepted = 206,
    kTDStatusNotModified = 304,
    kTDStatusBadRequest = 400,
    kTDStatusUnauthorized = 401,
    kTDStatusForbidden = 403,
    kTDStatusNotFound = 404,
    kTDStatusNotAcceptable = 406,
    kTDStatusConflict = 409,
    kTDStatusDuplicate = 412,  // Formally known as "Precondition Failed"
    kTDStatusUnsupportedType = 415,
    kTDStatusServerError = 500,
    kTDStatusInsufficientStorage = 507,

    // Non-HTTP errors:
    kTDStatusBadEncoding = 490,
    kTDStatusBadAttachment = 491,
    kTDStatusAttachmentNotFound = 492,
    kTDStatusBadJSON = 493,
    kTDStatusBadID = 494,
    kTDStatusBadParam = 495,
    kTDStatusDeleted = 496,                   // Document deleted
    kTDStatusUpstreamError = 589,             // Error from remote replication server
    kTDStatusDBError = 590,                   // SQLite error
    kTDStatusCorruptError = 591,              // bad data in database
    kTDStatusAttachmentError = 592,           // problem with attachment store
    kTDStatusCallbackError = 593,             // app callback (emit fn, etc.) failed
    kTDStatusException = 594,                 // Exception raised/caught
    kTDStatusAttachmentStreamError = 701,     // Error reading from stream when adding attachment
    kTDStatusAttachmentDiskSpaceError = 702,  // Not enough space on device for attachment
};

static inline bool TDStatusIsError(TDStatus status) { return status >= 300; }

int TDStatusToHTTPStatus(TDStatus status, NSString** outMessage);

NSError* TDStatusToNSError(TDStatus status, NSURL* url);
NSError* TDStatusToNSErrorWithInfo(TDStatus status, NSURL* url, NSDictionary* extraInfo);
