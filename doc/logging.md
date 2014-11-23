Logging with CocoaLumberJack 
============================

CDTDatastore has upgraded the logging capabilities with version 0.9.0. 
Logging now uses the [CocoaLumberJack](https://github.com/CocoaLumberjack/CocoaLumberjack) framework.
Using CocoaLumberJack provides more flexibility on where log entries are stored and a number of other attributes.

###Log contexts

Log context is a simple integer passed to CocoaLumberJack to allow the logs to be separated by component. This separation removes CDTDatastore logs from your logs allowing you to see app errors clearly, rather than hiding amongst library logs. Log contexts can be filtered by the formatter. To do this, a custom formatter needs to be implemented see: [Writing Custom Log Handlers & Formatters](#writing-custom-log-handlers--formatters).

Note: CDTDatastore uses log contexts 10 - 16 therefore your application should avoid using these levels if your application also uses CocoaLumberJack


### Switching Log Levels

By default the logging level for each component is set to Off. To raise and lower the log level for CDTDatastore use the macro `CDTChangeLogLevel`.  All component logging levels are located in the CDTLogging.h header file. For example to change the log level for the Indexing component:

```objc
CDTChangeLogLevel(CDTINDEX_LOG_CONTEXT,DDLogLevelInfo);
``` 
To turn off logging for a component:

```objc
CDTChangeLogLevel(CDTINDEX_LOG_CONTEXT,DDLogLevelOff);
```

### Configuring Loggers

By default CocoaLumberJack does not have any default loggers set. CDTDatastore chooses to keep this default and does not add ANY loggers on start up. To enable logging, a logger needs to be configured and added. For development development on CDTDatastore, you will want to add the `DDTTYLogger` to the list of loggers to use.  This will enable log statements to appear in the XCode console when available.

```objc
[DDLog addLogger:[DDTTYLogger sharedInstance]];
```
Removing loggers is just as easy, by calling either:

```objc
[DDLog removeAllLoggers];
```
to remove all loggers or to remove a specific logger

```objc
[DDLog removeLogger:[DDTTYLogger sharedInstance]];
```

Each logger can have their own formatter/filter, these filters can remove unwanted log messages, for example, removing CDTDatastore logs from your app's logs. To do this a custom formatter needs to be created (see [Writing Custom Log Handlers & Formatters](#writing-custom-log-handlers--formatters)). A filter can discard log messages by returning `nil`.

```objc
appLogger = [[DDFileLogger alloc] init];

[appLogger setLogFormatter:[MyContextFilter filterWith:1]];

[DDLog addLogger:appLogger];

```


###Writing Custom Log Handlers & Formatters

Like Log4j CocoaLumberJack allows the definition of custom log handlers. CocoaLumberJack includes a number of built in Log handlers such as `DDTTYLogger` and `DDASLLogger` (Apple system logger, logs appear in Console.app on OS X).  To create a custom log handler, it is advised that you follow the documentation from [CocoaLumberJack](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomLoggers.md). In addition to custom handlers, custom formatters can also be defined, custom formatters are described in [Custom Formatters](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomFormatters.md ) and [Custom Context](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomContext.md).

Example of a filter removing log messages:

```objc

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    if (logMessage->logContext == contextToLog)
        return logMessage->logMsg; //return raw log message
    else
        return nil;
}

```

### Adding new log statements

CDTDatastore has 5 levels of logging. These are:

- Error
- Warn
- Info
- Debug
- Verbose 
 
They map to their respective log functions such as `CDTLogError(CDTINDEX_LOG_CONTEXT, @"A log message")`

Log statements have 7 contexts. These contexts are broad areas of functionality in the library, and enable logging levels to be selectively changed for these areas.

- CDTINDEX_LOG_CONTEXT 
- CDTREPLICATION_LOG_CONTEXT 
- CDTDATASTORE_LOG_CONTEXT 
- CDTDOCUMENT_REVISION_LOG_CONTEXT 
- CDTTD_REMOTE_REQUEST_CONTEXT 
- CDTTD_JSON_CONTEXT 
- CDTTD_VIEW_CONTEXT 

All log statements in CDTLogging.h follow the same conventions are DDLog and NSLog. There is a key difference however, the first parameter is the context for which this log is in, the rest of the arguments follow NSLog (format then args).
