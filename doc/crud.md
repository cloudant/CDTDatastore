### Datastore and DatastoreManager objects

A `CDTDatastore` object manages a set of JSON documents, keyed by ID.

A `CDTDatastoreManager` object manages a directory where `CDTDatastore` objects
store their data. It's a factory object for named `CDTDatastore` instances. A
named datastore will persist its data between application runs. Names are
arbitrary strings, with the restriction that the name must match
`^[a-zA-Z]+[a-zA-Z0-9_]*`.

It's best to give a `CDTDatastoreManager` a directory of its own, and to make the
manager a singleton within an application. The content of the directory is
simple folders and SQLite databases if you want to take a peek.

Therefore, start by creating a `CDTDatastoreManager` to manage datastores for
a given directory:

```objc
#import <CloudantSync.h>

// Create a CDTDatastoreManager using application internal storage path
NSError *outError = nil;
NSFileManager *fileManager= [NSFileManager defaultManager];

NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                           inDomains:NSUserDomainMask] lastObject];
NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"cloudant-sync-datastore"];
NSString *path = [storeURL path];

CDTDatastoreManager *manager =
[[CDTDatastoreManager alloc] initWithDirectory:path
                                         error:&outError];
```

Once you've a manager set up, it's straightforward to create datastores:

```objc
CDTDatastore *ds = [manager datastoreNamed:@"my_datastore"
                                     error:&outError];
CDTDatastore *ds2 = [manager datastoreNamed:@"other_datastore"
                                      error:&outError];
```

The `CDTDatabaseManager` handles creating and initialising non-existent
datastores, so the object returned is ready for reading and writing.

To delete a datastore:

```objc
// TODO: not implemented yet
```

It's important to note that this doesn't check there are any active
`CDTDatastore` objects for this datastore. The behaviour of active `CDTDatastore`
objects after their underlying files have been deleted is undefined.

### Document CRUD APIs

Once you have a `CDTDatastore` instance, you can use it to create, update and
delete documents.

```objc
CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"
                                            error:&outError];

// Create a document
NSDictionary *doc = @{
    @"description": @"Buy milk",
    @"completed": @NO,
    @"type": @"com.cloudant.sync.example.task"
};
CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];

NSError *error;
CDTDocumentRevision *revision = [datastore createDocumentWithBody:body
                                                            error:&error];

// Read a document
NSString *docId = revision.docId;
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:docId
                                                        error:&error];

// Update a document
NSDictionary *doc = @{
    @"description": @"Buy milk",
    @"completed": @YES,
    @"type": @"com.cloudant.sync.example.task"
};
CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];
[datastore updateDocumentWithId:revision.docId
                        prevRev:revision.revId
                           body:body
                          error:&error];

// Delete a document
BOOL deleted = [datastore deleteDocumentWithId:docId
                                           rev:ob.revId
                                         error:&error];
```

As can be seen above, the `-updateDocumentWithId:prevRev:body:error:` and `-deleteDocumentWithId:rev:error:` methods both
require the revision of the version of the document currently in the datastore
to be passed as an argument. This is to prevent data being overwritten, for
example if a replication had changed the document since it had been read from
the local datastore by the applicaiton.

The `-getAllDocuments` method allows iterating through all documents in the
database:

```objc
// read all documents in one go
NSArray *documentRevisions = [datastore getAllDocuments];
```
