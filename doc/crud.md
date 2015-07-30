## Datastore and DatastoreManager objects

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
NSError *error = nil;
NSFileManager *fileManager= [NSFileManager defaultManager];

NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                           inDomains:NSUserDomainMask] lastObject];
NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"cloudant-sync-datastore"];
NSString *path = [storeURL path];

CDTDatastoreManager *manager =
[[CDTDatastoreManager alloc] initWithDirectory:path
                                         error:&error];
```

Once you've a manager set up, it's straightforward to create datastores:

```objc
CDTDatastore *ds = [manager datastoreNamed:@"my_datastore"
                                     error:&error];
CDTDatastore *ds2 = [manager datastoreNamed:@"other_datastore"
                                      error:&error];
```

These datastores are persisted to disk between application runs.

The `CDTDatabaseManager` handles creating and initialising non-existent
datastores, so the object returned is ready for reading and writing.

To delete a datastore and all associated data (i.e., attachments and
extension data such as indexes (see [index-query.md](doc/index-query.md)):

```objc
BOOL success = [manager deleteDatastoreNamed:@"my_datastore"
                                       error:&error];
```

It's important to note that this doesn't check there are any active
`CDTDatastore` objects for this datastore. The behaviour of active
`CDTDatastore` objects after their underlying files have been deleted is
undefined.

## Document CRUD APIs

Once you have a `CDTDatastore` instance, you can use it to create, update and
delete documents.


### Create

Documents are represented as a set of revisions. To create a document, you
set up the initial revision of the document and save that to the datastore.

Create a mutable document revision object, set its body, ID and attachments
and then call `-createDocumentFromRevision:error:` to add it to the datastore:

```objc
CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"
                                            error:&error];
NSError *error;

// Create a document
CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
rev.docId = @"doc1";  // Or don't assign the docId property, we'll generate one
rev.body = [@{
    @"description": @"Buy milk",
    @"completed": @NO,
    @"type": @"com.cloudant.sync.example.task"
} mutableCopy];
CDTDocumentRevision *revision = [datastore createDocumentFromRevision:rev
                                                                error:&error];
```

The only mandatory property to set before calling
`-createDocumentFromRevision:error:` is the `body`. An ID will be generated
for documents which don't have `docId` set.

### Retrieve

Once you have created one or more documents, retrieve them by ID:

```objc
NSString *docId = revision.docId;
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:docId
                                                        error:&error];
```

You get an immutable revision back from this method call. To make changes to
the document, you need to call `-mutableCopy` on the revision and save it
back to the datastore, as shown below.

### Update

To update a document, call `mutableCopy` on the original document revision,
make your changes and save the document:

```objc
CDTMutableDocumentRevision *update = [retrieved mutableCopy];
update.body[@"completed"] = @YES;  // Or assign a new NSDictionary
CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                               error:&error];
```

### Delete

To delete a document, you need the current revision:

```objc
BOOL deleted = [datastore deleteDocumentFromRevision:saved
                                               error:&error];
```

## Indexing

You don't need to know the ID of the document to retrieve it. CDTDatastore
provides ways to index and search the fields of your JSON documents.
For more, see [index-query.md](doc/index-query.md).

## Conflicts

As can be seen above, the `-updateDocumentFromRevision:error:`
and `-deleteDocumentFromRevision:error:` methods both
require the revision of the version of the document currently in the datastore
to be passed as an argument. This is to prevent data being overwritten, for
example if a replication had changed the document since it had been read from
the local datastore by the applicaiton.

The update and delete methods may fail because the revision you passed in isn't
the current revision of that document. See [conflicts.md](doc/conflicts.md) for
more information about this.

## Getting all documents

The `-getAllDocuments` method allows iterating through all documents in the
database:

```objc
// Read all documents in one go
NSArray *documentRevisions = [datastore getAllDocuments];
```

## Using attachments

You can associate attachments with the JSON documents in your datastores.
Attachments are blobs of binary data, such as photos or short sound snippets.
They should be of small size -- maximum a few MB -- because they are
replicated to and from the server in a way which doesn't allow for resuming
an upload or download.

Attachments are stored in the `attachments` property on a CDTDocumentRevision
object. This is a dictionary of attachments, keyed by attachment name.

To add an attachment to a document, just add (or overwrite) the attachment
in the `attachments` dictionary:

```objc
// Create a new document
CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
// or get an existing one and create a mutable copy
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:@"mydoc"
                                                        error:&error];
CDTMutableDocumentRevision *rev = [retrieved mutableCopy];

rev.body = [@{ ... } mutableCopy];
CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                  initWithPath:@"/path/to/image.jpg"
                          name:@"cute_cat.jpg"
                          type:@"image/jpeg"]];

// As with the document body, you can replace all attachments:
rev.attachments = @{ att1.name: att1 };

// Or just add or update a single one:
rev.attachments[att1.name] = att1;

CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev
                                                             error:&error];
```

When creating new attachments, use `CDTUnsavedFileAttachment` for data you
already have on disk. Use `CDTUnsavedDataAttachment` when you have an `NSData`
object with the data.

```objc
CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                  initWithPath:@"/path/to/image.jpg"
                          name:@"cute_cat.jpg"
                          type:@"image/jpeg"]];

NSData *imageData = [NSData dataWithContentsOfFile:@"/path/to/image.jpg"];
CDTUnsavedDataAttachment *att2 = [[CDTUnsavedDataAttachment alloc]
                  initWithData:imageData
                          name:@"cute_cat.jpg"
                          type:@"image/jpeg"]];

CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
rev.attachments = [@{ att1.name: att1, att2.name: att2 } mutableCopy];
CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev
                                                             error:&error];
```

To read an attachment, get the `CDTSavedAttachment` from the `attachments`
dictionary. Then use `-dataFromAttachmentContent` to read the data:

```objc
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:@"mydoc"
                                                        error:&error];
CDTAttachment *att = retrieved.attachments[@"cute_cat.jpg"];
NSData *imageData = [att dataFromAttachmentContent];
```

To remove an attachment, remove it from the `attachments` dictionary:

```objc
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:@"mydoc"
                                                        error:&error];
CDTMutableDocumentRevision *update = [retrieved mutableCopy];
[update.attachments removeObjectForKey:@"cute_cat.jpg"];
CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                               error:&error];

```

To remove all attachments, set the `attachments` property to an empty dictionary
or `nil`:

```objc
update.attachments = nil;
```

## Cookbook

This section shows all the ways (that I could think of) that you can update,
modify and delete documents.

### Creating a new document

This is the simplest case as we don't need to worry about previous revisions.

1. Add a document with body, but not attachments or ID. You'll get an
   autogenerated ID.
    ```objc
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.body = [@{ ... } mutableCopy];

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    ```

1. Add a new document to the store with a body and ID, but without attachments.
    ```objc
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.docId = @"doc1";
    rev.body = [@{ ... } mutableCopy];

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev
                                                                 error:&error];
    ```

1. Add a new document to the store with attachments.
    ```objc
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.docId = @"doc1";
    rev.body = [@{ ... } mutableCopy];

    CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                      initWithPath:@"path"
                              name:@"filename"
                              type:@"image/jpeg"]]
    rev.attachments = @{ att1.name:att1 };

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    ```

1. Add a document with body and attachments, but no ID. You'll get an
   autogenerated ID.
    ```objc
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.body = [@{ ... } mutableCopy];

    CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                      initWithPath:@"path"
                              name:@"filename"
                              type:@"image/jpeg"]]
    rev.attachments[att1.name] = att1;

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    ```

1. You can't create a document without a body (body is the only required property).
    ```objc
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.docId = @"doc1";

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    // Fails, saved is nil
    ```

### Updating a document

To update a document, call `mutableCopy` on the original document revision,
make your changes and save the document.

For the first set of examples the original document is set up with a body
and no attachments:

```objc
CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
rev.docId = @"doc1";
rev.body = [@{ ... } mutableCopy];

CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
```

We also assume an attachment ready to be added:

```objc
CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                  initWithPath:@"/path/to/image.jpg"
                          name:@"cute_cat.jpg"
                          type:@"image/jpeg"]];
```


1. Update body for doc that has no attachments, keeping no attachments
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.body = [@{ ... } mutableCopy];
    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update body for doc with no attachments, adding attachments. Here we see
   that a mutableCopy of a document with no attachments has an
   `NSMutableDictionary` set for its `attachments` property.
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.body[@"hello"] = @"world";
    update.attachments[@att1.name] = att1;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update body for doc with no attachments, removing attachments dictionary
   entirely.
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.body[@"hello"] = @"world";
    update.attachments = nil;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update the attachments without changing the body, add attachments to a doc
   that had none.
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.attachments[@att1.name] = att1;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update attachments by copying from another revision.
    ```objc
    CDTMutableDocumentRevision *anotherDoc = [datastore getDocumentForId:@"anotherId"];
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.attachments = anotherDoc.attachments;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Updating a document using an outdated source revision causes a conflict
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.body = [@{ ... } mutableCopy];
    [datastore updateDocumentFromRevision:update];

    CDTMutableDocumentRevision *update2 = [saved mutableCopy];
    update2.body = [@{ ... ... } mutableCopy];

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    // Updated should be nil, and error should be set/exception thrown
    ```


For the second set of examples the original document is set up with a body and
several attachments:

```objc
CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
rev.docId = @"doc1";
rev.body = [@{ ... } mutableCopy];

CDTUnsavedFileAttachment *att1 = /* blah */
/* set up more attachments */
rev.attachments = @{ att1.name:att1, att2.name:att2, att3.name:att3 };

CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
```

1. Update body without changing attachments
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.body[@"hello"] = @"world";

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update];
    // Should have the same attachments
    ```

1. Update the attachments without changing the body, remove attachments
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    [update.attachments removeObjectForKey:att1.name];

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update the attachments without changing the body, add attachments
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    // Create att100 attachment
    update.attachments[att100.name] = att100;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update the attachments without changing the body, remove all attachments
   by setting `nil` for attachments dictionary.
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.attachments = nil;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Update the attachments without changing the body, remove all attachments
   by setting an empty dictionary.
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.attachments = [@{} mutableCopy];

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Copy an attachment from one document to another.
    ```objc
    // Create a revision with attachments
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.docId = @"doc1";
    rev.body = [@{ ... } mutablecopy];
    CDTUnsavedFileAttachment *att1 = /* blah */
    rev.attachments[att1.name] = att1;
    CDTDocumentRevision *revWithAttachments = [datastore createDocumentFromRevision:rev
                                                                              error:&error];

    // Add attachment to "saved" from "revWithAttachments"
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    CDTAttachment *savedAttachment = revWithAttachments.attachments[@"nameOfAttachment"];
    update.attachments = [@{savedAttachment.name: savedAttachment} mutableCopy];

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:update
                                                                   error:&error];
    ```

### Creating a document from a `mutableCopy`

It should be possible to create a new document from a `mutableCopy` of an existing document.


1. Add a document from a `mutableCopy`, with attachments
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.docId = @"doc2";
    update.body[@"hello"] = @"world";
    // Create att100 attachment
    update.attachments[att100.name] = att100;

    CDTDocumentRevision *updated = [datastore createDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Add a document from a `mutableCopy`, without attachments
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.docId = @"doc2";
    update.body = @{ ... };
    update.attachments = nil;

    CDTDocumentRevision *updated = [datastore createDocumentFromRevision:update
                                                                   error:&error];
    ```

1. Fail if the document ID is present in the datastore. Note this shouldn't
   fail if the document is being added to a different datastore.
    ```objc
    CDTMutableDocumentRevision *update = [saved mutableCopy];
    update.body[@"hello"] = @"world";

    CDTDocumentRevision *updated = [datastore createDocumentFromRevision:update
                                                                   error:&error];
    // Fails, saved is nil

    CDTDocumentRevision *updated = [other_datastore createDocumentFromRevision:update
                                                                         error:&error];
    // Succeeds
    ```


### Deleting a document

1. You should be able to delete a given revision (i.e., add a tombstone to the end of the branch).

       ```objc
       CDTDocumentRevision *saved = [datastore getDocumentForId:@"doc1"];
       CDTDocumentRevision *deleted = [datastore deleteDocumentFromRevision:saved
                                                                      error:&error];
       ```

       This would refuse to delete if `saved` was not a leaf node.

1. **Advanced** You should also be able to delete a document in its entirety by passing in an ID.

       ```objc
       CDTDocumentRevision *deleted = [datastore deleteDocumentWithId:"@doc1"
                                                                error:&error];
       ```

    This marks *all* leaf nodes deleted. Make sure to read
    [conflicts.md](doc/conflicts.md) before using this method as it can result
    in data loss (deleting conflicted versions of documents, not just the
    current winner).
