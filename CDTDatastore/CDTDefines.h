//
//  CDTDefines.h
//  CDTDatastore
//
//  Created by Rhys Short on 21/01/2016.
//  Copyright © 2016 IBM. All rights reserved.
//


/**
 * Defines Custom types, Enums etc that are required in different classes thoughout
 * CDTDatastore. This makes it easier to build CDTDatastore as framework by seperating 
 * the touchDb classes from the CDT* classes which are the user's interaction point with 
 * the lib.
 */
#ifndef CDTDefines_h
#define CDTDefines_h

/** Database sequence ID */
typedef SInt64 SequenceNumber;

/** Types of encoding/compression of stored attachments. */
typedef enum { kTDAttachmentEncodingNone, kTDAttachmentEncodingGZIP } TDAttachmentEncoding;


#endif /* CDTDefines_h */
