Logging with CocoaLumberJack 
============================

As of version 0.9.0, CDTDatasture uses the [CocoaLumberJack](https://github.com/CocoaLumberjack/CocoaLumberjack) framework. Using CocoaLumberJack provides more flexibility on where log entries are stored and a number of other attributes.

### Log contexts

A *log context* is a simple integer passed to CocoaLumberJack to allow logs to be separated by component. CDTDatastore further splits its logs into separate context to allow easier debugging.

**CDTDatastore uses log contexts 10 - 16**. Your application should avoid using these context identifiers.

These contexts are broad areas of functionality in the library, and enable logging levels to be selectively changed for these areas. They are:

Constant | Logs relate to
------------- | -------------
`CDTINDEX_LOG_CONTEXT`  | Index and querying (e.g., index already exists warning)
`CDTREPLICATION_LOG_CONTEXT`  | High level replication information (errors etc.)
`CDTDATASTORE_LOG_CONTEXT`  | Mostly around CRUD operation (e.g., missing attachment, SQLite errors)
`CDTDOCUMENT_REVISION_LOG_CONTEXT`  | Revisions and attachments (e.g., bad JSON)
`CDTTD_REMOTE_REQUEST_CONTEXT`  | Details of HTTP requests made
`CDTTD_JSON_CONTEXT`  | Very low level JSON parsing issues


### Switching Log Levels

By default the logging level for each component is set to `Off`. To raise and lower the log level for CDTDatastore use the macro `CDTChangeLogLevel`.  All component logging levels are defined in `CDTLogging.h`. For example, to change the log level for the Indexing component:

```objc
#import <CDTLogging.h>

CDTChangeLogLevel(CDTINDEX_LOG_CONTEXT,DDLogLevelInfo);
``` 
To turn off logging for a component:

```objc
CDTChangeLogLevel(CDTINDEX_LOG_CONTEXT,DDLogLevelOff);
```

### Configuring Loggers

By default CocoaLumberJack does not have any default loggers set. To enable logging, a logger needs to be configured and added. For development development on CDTDatastore, add the `DDTTYLogger` to the list of loggers to use.  This will show log statementsin the Xcode console.

```objc
[DDLog addLogger:[DDTTYLogger sharedInstance]];
```

To remove loggers, either remove all loggers:

```objc
[DDLog removeAllLoggers];
```
Or remove a specific logger:

```objc
[DDLog removeLogger:[DDTTYLogger sharedInstance]];
```

Each logger can have its own formatter/filter. These filters can remove unwanted log messages; for example, removing CDTDatastore logs from your application's logs. To do this a custom formatter needs to be created (see [Writing Custom Log Handlers & Formatters](#writing-custom-log-handlers--formatters)). A filter can discard log messages by returning `nil`.

```objc
appLogger = [[DDFileLogger alloc] init];

[appLogger setLogFormatter:[MyContextFilter filterWith:1]];

[DDLog addLogger:appLogger];
```


### Writing Custom Log Handlers & Formatters

Like Log4j, CocoaLumberJack allows the definition of custom log handlers. CocoaLumberJack includes a number of built in Log handlers such as `DDTTYLogger` and `DDASLLogger` (Apple System Logger, logs appear in Console.app on OS X).  To create a custom log handler, follow the documentation from [CocoaLumberJack](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomLoggers.md). In addition to custom handlers, custom formatters can also be defined. These are described in [Custom Formatters](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomFormatters.md ) and [Custom Context](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomContext.md).

### Adding new log statements

When adding log statements to CDTDatastore itself, be careful to use appropriate log levels and contenxts.

CDTDatastore has 5 levels of logging. These are:

- Error
- Warn
- Info
- Debug
- Verbose 
 
They map to their respective log functions, such as `CDTLogError(CDTINDEX_LOG_CONTEXT, @"A log message")`

All log statements in `CDTLogging.h` follow the same conventions as DDLog and NSLog. There is a key difference however: the first parameter is the context for which this log is in. The rest of the arguments follow NSLog (format then args).
