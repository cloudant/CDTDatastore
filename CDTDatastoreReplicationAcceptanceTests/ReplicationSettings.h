//
//  ReplicationSettings.h
//  ReplicationAcceptance
//
//  Created by Rhys Short on 17/03/2015.
//
//

#import <Foundation/Foundation.h>

@interface ReplicationSettings : NSObject

@property (readonly) NSString* serverURI;

@property (readonly) NSString* authorization;

@property (readonly) NSNumber* nDocs;

@property (readonly) NSNumber* largeRevTreeSize;

@property (readonly) NSString* iamApiKey;

@property (readonly) NSNumber* raSmall;

/**
 * Note that the symbolic constants from DDLog.h can't be used in the plist file.
 * The following numbers should be used:
 * DDLogLevelOff = 0
 * DDLogLevelWarning = 1
 * DDLogLevelInfo = 3
 * DDLogLevelDebug = 7
 * DDLogLevelVerbose = 15
 */
@property (readonly) NSNumber* loggingLevel;

@end
