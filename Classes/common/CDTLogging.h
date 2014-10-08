//
//  CDTLogging.h
//  
//
//  Created by Rhys Short on 01/10/2014.
//
//

#import "DDLog.h"

#ifndef _CDTLogging_h
#define _CDTLogging_h

/*

 Macro defintions for custom logger contexts, this allows different parts of CDTDatastore
 to seperate their log messages and have different levels.
 
 Each componant should set their log level using a static variable in the name <componant>LogLevel
 the macros will then perform correctly at compile time.
 
 */
#define INDEX_LOG_CONTEXT 10
#define REPLICATION_LOG_CONTEXT 11
#define DATASTORE_LOG_CONTEXT 12
#define DOCUMENT_REVISION_LOG_CONTEXT 13
#define TD_REMOTE_REQUEST_CONTEXT 14
#define TD_JSON_CONTEXT 15
#define TD_VIEW_CONTEXT 16


#define START_CONTEXT INDEX_LOG_CONTEXT
#define END_CONTEXT TD_VIEW_CONTEXT

static int CDTLoggingLevels[] = {[0 ... END_CONTEXT - START_CONTEXT ] = LOG_LEVEL_WARN};

#define LogError(context, frmt, ...) SYNC_LOG_OBJC_MAYBE(CDTLoggingLevels[context - START_CONTEXT], LOG_FLAG_ERROR, context, frmt, ##__VA_ARGS__)
#define LogWarn(context, frmt, ...) ASYNC_LOG_OBJC_MAYBE(CDTLoggingLevels[context - START_CONTEXT], LOG_FLAG_WARN, context, frmt, ##__VA_ARGS__)
#define LogInfo(context, frmt, ...) ASYNC_LOG_OBJC_MAYBE(CDTLoggingLevels[context - START_CONTEXT], LOG_FLAG_INFO, context, frmt, ##__VA_ARGS__)
#define LogDebug(context, frmt, ...) ASYNC_LOG_OBJC_MAYBE(CDTLoggingLevels[context - START_CONTEXT], LOG_FLAG_DEBUG, context, frmt, ##__VA_ARGS__)
#define LogVerbose(context, frmt, ...) ASYNC_LOG_OBJC_MAYBE(CDTLoggingLevels[context - START_CONTEXT], LOG_FLAG_VERBOSE, context, frmt, ##__VA_ARGS__)
#define ChangeLogLevel(context, logLevel) levels[context- START_CONTEXT]=logLevel

#endif

