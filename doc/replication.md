## Replicating Data Between Many Devices

Replication is used to synchronise data between the local datastore and a
remote database, either a CouchDB instance or a Cloudant database. Many
datastores can replicate with the same remote database, meaning that
cross-device syncronisation is acheived by setting up replications from each
device to the remote database.

### Setting Up For Sync

Currently, the replication process requires a remote database to exist already.
To avoid exposing credentials for the remote system on each device, we recommend
creating a web service to authenticate users and set up databases for client
devices. This web service needs to:

* Handle sign in/sign up for users.
* Create a new remote database for a new user.
* Grant access to the new database for the new device (e.g., via [API keys][keys]
  on Cloudant or the `_users` database in CouchDB).
* Return the database URL and credentials to the device.

[keys]: https://cloudant.com/for-developers/faq/auth/

### Replication on the Device

From the device side, replication is straightforward. You can replicate from a
local datastore to a remote database, from a remote database to a local
datastore, or both ways to implement synchronisation.

Replicating a local datastore to a remote database:

***Warning***: When you create a CDTReplicator object, you have the only strong
reference to that object. If you do not maintain that reference, the object
will be deallocated and replication will stop prematurely.

```objc
#import <CloudantSync.h>

// Create and start the replicator -- -start is essential!
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
NSError *error;
CDTReplicator *replicator = [replicatorFactory oneWay:pushReplication error:&error];

// Check replicator isn't nil, if so check error

// Start the replication and wait for it to complete
[replicator start];
while (replicator.isActive) {
    [NSThread sleepForTimeInterval:1.0f];
    NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
}
```

And getting data from a remote database to a local one:

```objc
#import <CloudantSync.h>

// Create and start the replicator -- start is essential!
CDTReplicatorFactory *replicatorFactory =
[[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];

// username/password can be Cloudant API keys
NSString *s = @"https://username:password@username.cloudant.com/my_database";
NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"];

// Create a replicator that replicates changes from a remote
// database to the local one.
CDTPullReplication *pullReplication = [CDTPullReplication replicationWithSource:remoteDatabaseURL
                                                                         target:datastore];
NSError *error;
CDTReplicator *replicator = [replicatorFactory oneWay:pullReplication error:&error];

// Check replicator isn't nil, if so check error

// Start the replication and wait for it to complete
[replicator start];
while (replicator.isActive) {
    [NSThread sleepForTimeInterval:1.0f];
    NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
}
```

#### Using a replication delegate

Once you've created a `CDTReplicator` object, you probably don't want your main 
thread to go into the loop shown above, as it'll block your user interface.
Instead, the `CDTReplicator` object can be given a delegate conforming to the
[`CDTReplicatorDelegate`](https://github.com/cloudant/CDTDatastore/blob/master/Classes/common/CDTReplicator/CDTReplicatorDelegate.h) protocol.

This protocol has four methods, all optional:

```objc
/**
* Called when the replicator changes state.
*/
-(void) replicatorDidChangeState:(CDTReplicator*)replicator;

/**
* Called whenever the replicator changes progress
*/
-(void) replicatorDidChangeProgress:(CDTReplicator*)replicator;

/**
* Called when a state transition to COMPLETE or STOPPED is
* completed.
*/
- (void)replicatorDidComplete:(CDTReplicator*)replicator;

/**
* Called when a state transition to ERROR is completed.
*/
- (void)replicatorDidError:(CDTReplicator*)replicator info:(NSError*)info;
```

To use, just assign to the `delegate` property of the replicator object. **Note:**
this is a `weak` property, so the delegate needs to be strongly retained elsewhere,
as otherwise its methods won't be called.

You must keep a strong reference to the CDTReplicator object or it will
be deallocated and your delegate methods will never be called. 

```objc
// For this example, self retains the delegate and the CDTReplicator.
self.replicationDelegate = /* alloc/init a sync delegate, or share one */;

CDTPushReplication *pushReplication = [CDTPushReplication replicationWithSource:datastore
                                                                         target:remoteDatabaseURL];
NSError *error;
self.replicator = [replicatorFactory oneWay:pushReplication error:&error];
self.replicator.delegate = self.replicatorDelegate;
[self.replicator start];
```
