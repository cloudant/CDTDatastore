# Replication Policies

## iOS replication policies

Replication policies on iOS run in a background task to allow them to run independently of the rest of your application
and to enable them to continue even when the app is suspended or terminated.

It is also possible to configure periodic replication of data whilst the app is in the background. It is important
to realise that iOS imposes restrictions on background data transfer and these apply to replication policies. In
particular, iOS limits the time during which data transfers can occur while the app is in the background to 30
seconds. Also, although a minimum background fetch interval can be specified, this is the absolute minimum period
between performing background data transfers and the actual interval may be significantly different to the minimum
interval specified.

### Configuring background execution

To configure background execution, it is necessary to:
* enable the Background fetch option for the Background modes section of the Capabilites tab in your Xcode project (you
  can also enable this support by including the `UIBackgroundModes` key with the `fetch` value in your app's `Info.plist`
  file).
* implement an app delegate method `application:performFetchWithCompletionHandler:` to initiate the replications. Once
  replications are complete, this method must execute the provided completion handler block, passing a result that
  indicates whether content was available.
* set the minimum background fetch interval by calling `setMinimumBackgroundFetchInterval:` on the application's
  `UIApplication` object. The value given to `setMinimumBackgroundFetchInterval:` is advisory only and the actual
  time between background replications may vary considerably from the value set.

You should note that enabling background fetch does not guarantee that iOS will give your app any time to perform
background fetches as iOS will attempt to balance your app's need to fetch content with the needs of the system and
of other apps.

### Example

Lets assume we wish to configure a replication policy as follows:

* We only ever want replications to occur when the device is connected to a WiFi network.
* We want to do sync replications (pull and push).
* When the app is not displaying data to the user we want replications to occur once every 24 hours to keep the data on the device fairly fresh.
* When the app is displaying data to the user we want replications to occur every 5 minutes so the data displayed to the user is only ever a few minutes out of date if we're on Wifi.
* When the app is displaying data to the user we want to refresh the UI to display the new data when the pull replication has completed.
* After the device has rebooted, we want replications to continue in the same way as prior to the reboot.

Note that there is a full example implementing a policy similar to the above in the example project in the
`Project` directory.

#### Configuring app capabilities

On the `Capabilities` tab of your Xcode project turn on `Background Modes` and select `Background fetch`.

#### Configure your replications

Configure your replications following the guidance in the [Replication guide](replication.md).

Note however, that in the following example we'll use the `startWithTaskGroup:error:` method of
`CDTReplicator` instead of `startWithError:` so that we can batch the replication tasks and wait
for the completion of all of them.

For example:
```objc
/** Start both a push and pull replication.
 *
 *  @param taskGroup A dispatch_group_t to allow us to wait for replications to complete.
 */
- (void)startReplications:(dispatch_group_t)taskGroup
{
    // Create the replicator factory
    CDTReplicatorFactory *replicatorFactory =
       [[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];

    // username/password can be Cloudant API keys
    NSString *s = @"https://username:password@username.cloudant.com/my_database";
    NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
    CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"];

    // Create a replicator that replicates changes from the local
    // datastore to the remote database.
    CDTPushReplication *pushReplication = [CDTPushReplication replicationWithSource:datastore
                                                                             target:remoteDatabaseURL];

    // Create a replicator that replicates changes from a remote
    // database to the local one.
    CDTPullReplication *pullReplication = [CDTPullReplication replicationWithSource:remoteDatabaseURL
                                                                             target:datastore];

    NSError *pushError;
    CDTReplicator *pushReplicator = [replicatorFactory oneWay:pushReplication
                                        sessionConfigDelegate:self
                                                        error:&error];

    NSError *pullError;
    CDTReplicator *pullReplicator = [replicatorFactory oneWay:pullReplication
                                        sessionConfigDelegate:self
                                                        error:&error];

    // Start the push replication
    if (![pushReplicator startWithTaskGroup:taskGroup error:&error]){
        //handle error
    }

    // Start the pull replication
    if (![pullReplicator startWithTaskGroup:taskGroup error:&error]){
        //handle error
    }
}
```

Create a method to start replications and wait for their completion (on a background thread).

```objc
-(void)syncInBackgroundWithCompletionHandler:(void (^)())completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_group_t backgroundTasks = dispatch_group_create();

        UIBackgroundTaskIdentifier taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];

        [self startReplications:backgroundTasks];

        dispatch_group_wait(backgroundTasks, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

        if (completionHandler) {
            completionHandler();
        }

        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    });
}
```

Setup an NSURLSessionConfigurationDelegate to customise the NSURLSession as you require:

```objc
- (NSURLSessionConfiguration*)customiseNSURLSessionConfiguration:(nonnull NSURLSessionConfiguration *)config {
    config.allowsCellularAccess = NO; // Wifi only.
    config.sessionSendsLaunchEvents = YES;
    return config;
}
```

#### Setting up the App Delegate

In your `UIApplicationDelegate` add the following to your `application:didFinishLaunchingWithOptions:` method:

```objc
int backgroundInterval24hrs = 24*60*60;
[[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:backgroundInterval24hrs];
```

Implement the `application:performFetchWithCompletionHandler:` method - e.g.:
```objc
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self.myReplicator syncInBackgroundWithCompletionHandler:^{
        // Do whatever you want when replication is complete (e.g. refresh the UI)

        // Call the completion handler once the sync has finished.
        completionHandler(UIBackgroundFetchResultNewData);
    }];
}
```

#### Configure replication when a particular screen is visible

In your screen's view controller, add methods to start and stop the timer performing replications:

```objc
@property (nonatomic, strong) NSTimer *timer;

- (void)startTimer:(id)sender {
    _timer = [NSTimer scheduledTimerWithTimeInterval:30
                                              target:self
                                            selector:@selector(periodicReplication:)
                                            userInfo:nil
                                             repeats:YES];
}

- (void)stopTimer:(id)sender {
    [_timer invalidate];
    _timer = nil;
}

- (void)periodicReplication:(NSTimer *)timer
{
    [self.todoReplicator syncInBackgroundWithCompletionHandler:^{
        // Do whatever you want when replication is complete (e.g. refresh the UI)
    }];
}
```

Add the following to the View Controller's `viewWillAppear:animated` method:

```objc
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopTimer:) name:UIApplicationWillResignActiveNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startTimer:) name:UIApplicationWillEnterForegroundNotification object:nil];
```


