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

Objective-C:

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
Swift:

```swift
do {
    // Create a CDTDatastoreManager using application internal storage path
    let fileManager = NSFileManager.defaultManager()
    let documentsDir = fileManager.URLsForDirectory(.DocumentDirectory,
         inDomains: .UserDomainMask).last!
    let storeURL = documentsDir.URLByAppendingPathComponent("cloudant-sync-datastore")
    let path = storeURL.path
    let manager = try CDTDatastoreManager(directory: path)
} catch {
    print(error)
}
```

Once you've a manager set up, it's straightforward to create datastores:

Objective-C:

```objc
CDTDatastore *ds = [manager datastoreNamed:@"my_datastore"
                                     error:&error];
CDTDatastore *ds2 = [manager datastoreNamed:@"other_datastore"
                                      error:&error];
```
Swift:

```swift
let ds = try manager.datastoreNamed("my_datastore")
let ds2 = try manager.datastoreNamed("other_datastore")
```

These datastores are persisted to disk between application runs.

The `CDTDatabaseManager` handles creating and initialising non-existent
datastores, so the object returned is ready for reading and writing.

To delete a datastore and all associated data (i.e., attachments and
extension data such as indexes (see [query.md](query.md)):

Objective-C:

```objc
BOOL success = [manager deleteDatastoreNamed:@"my_datastore"
                                       error:&error];
```
Swift:

```swift
try manager.deleteDatastoreNamed("my_datastore")
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

Create a document revision object with an ID, set its body and attachments
and then call `-createDocumentFromRevision:error:` to add it to the datastore:


Objective-C:

```objc
CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"
                                            error:&error];
NSError *error;

// Create a document
CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
rev.body = [@{
    @"description": @"Buy milk",
    @"completed": @NO,
    @"type": @"com.cloudant.sync.example.task"
} mutableCopy];
CDTDocumentRevision *revision = [datastore createDocumentFromRevision:rev
                                                                error:&error];
```
Swift:

```swift
let datastore = try manager.datastoreName("my_datastore")
let rev = CDTDocumentRevision(docId: "doc1")
rev.body = ["description":"Buy Milk",
            "completed": false,
            "type":"com.cloudant.sync.example.task"
]
let revision = try datastore.createDocumentFromRevision(rev)
```

The only mandatory property to set before calling
`-createDocumentFromRevision:error:` is the `body`. An ID will be generated
for documents which don't have `docId` set.

### Retrieve

Once you have created one or more documents, retrieve them by ID:

Objective-C:

```objc
NSString *docId = revision.docId;
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:docId
                                                        error:&error];
```
Swift:

```swift
let docId = revision.docId
let retrieved = try datastore.getDocumentWithId(docId)
```

You can make updates to `retrieved` which can then be saved to the datastore
as an update.

### Update

To update a document, just make your changes to the revision and save the
document:

Objective-C:

```objc
retrieved.body[@"completed"] = @YES;  // Or assign a new NSMutableDictionary
CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:retrieved
                                                               error:&error];
```
Swift:

```swift
retrieved.body["completed"] = true
let updated = try datastore.updateDocumentFromRevision(retrieved)
```

### Delete

To delete a document, you need the current revision:

Objective-C:

```objc
BOOL deleted = [datastore deleteDocumentFromRevision:updated
                                               error:&error];
```
Swift:

```swift
try datastore.deleteDocumentFromRevision(updated)
```

## Indexing

You don't need to know the ID of the document to retrieve it. CDTDatastore
provides ways to index and search the fields of your JSON documents.
For more, see [query.md](query.md).

## Conflicts

As can be seen above, the `-updateDocumentFromRevision:error:`
and `-deleteDocumentFromRevision:error:` methods both
require the revision of the version of the document currently in the datastore
to be passed as an argument. This is to prevent data being overwritten, for
example if a replication had changed the document since it had been read from
the local datastore by the applicaiton.

The update and delete methods may fail because the revision you passed in isn't
the current revision of that document. See [conflicts.md](conflicts.md) for
more information about this.

## Getting all documents

The `-getAllDocuments` method allows iterating through all documents in the
database:

Objective-C:

```objc
// Read all documents in one go
NSArray *documentRevisions = [datastore getAllDocuments];
```
Swift:

```swift
let documentRevisions = datastore.getAllDocuments()
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

Objective-C:

```objc
// Create a new document:
CDTDocumentRevision *rev = [CDTDocumentRevision revision];
// or get an existing one:
CDTDocumentRevision *rev = [datastore getDocumentWithId:@"mydoc"
                                                  error:&error];

rev.body = [@{ ... } mutableCopy];
CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                  initWithPath:@"/path/to/image.jpg"
                          name:@"cute_cat.jpg"
                          type:@"image/jpeg"]];

// As with the document body, you can replace all attachments:
rev.attachments = [@{ att1.name: att1 } mutableCopy];

// Or just add or update a single one:
rev.attachments[att1.name] = att1;

CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev
                                                             error:&error];
```
Swift:

```swift
// Create a new document
let rev = CDTDocumentRevision()
// or get an existing one:
let rev = try datastore.getDocumentWithId("mydoc")

rev.body = [....]

let att1 = CDTUnsavedFileAttachment(path: "/path/to/image.jpg",
    name: "cute_cat.jpg",
    type: "image/jpeg")

// As with the document body, you can replace all the attachments:
rev.attachments = [att1.name : att1]
// or just add or update a single one:
rev.attachments[att1.name] = att1

let saved = try datastore.createDocumentFromRevision(rev)

```

When creating new attachments, use `CDTUnsavedFileAttachment` for data you
already have on disk. Use `CDTUnsavedDataAttachment` when you have an `NSData`
object with the data.

Objective-C:

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

CDTDocumentRevision *rev = [CDTDocumentRevision revision];
rev.attachments = [@{ att1.name: att1, att2.name: att2 } mutableCopy];
CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev
                                                             error:&error];
```
Swift:

```swift
let att1 = CDTUnsavedFileAttachment(path: "/path/to/image.jpg",
    name: "cute_cat.jpg",
    type: "image/jpeg")

let imageData = NSData(contentsOfFile: "/path/to/image.jpg")
let att2 = CDTUnsavedDataAttachment(data: imageData,
    name: "cute_cat.jpg",
    type: "image/jpeg")

let rev = CDTDocumentRevision()
rev.attachments = [att1.name: att1, att2.name: att2]
let saved = try datastore.createDocumentFromRevision(rev)
```

To read an attachment, get the `CDTSavedAttachment` from the `attachments`
dictionary. Then use `-dataFromAttachmentContent` to read the data:

Objective-C:

```objc
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:@"mydoc"
                                                        error:&error];
CDTAttachment *att = retrieved.attachments[@"cute_cat.jpg"];
NSData *imageData = [att dataFromAttachmentContent];
```
Swift:

```swift
let retrieved = try datastore.getDocumentWithId("mydoc")
let att = retrieved.attachments["cute_cat.jpg"]
let imageData = att.dataFromAttachmentContent
```

To remove an attachment, remove it from the `attachments` dictionary:

Objective-C:

```objc
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:@"mydoc"
                                                        error:&error];
[retrieved.attachments removeObjectForKey:@"cute_cat.jpg"];
CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:retrieved
                                                               error:&error];

```
Swift:

```swift
let retrieved = try datastore.getDocumentWithId("mydoc")
retrieved.attachments.removeValueForKey("cute_cat.jpg")
let updated = try datastore.updateDocumentFromRevision(retrieved)
```

To remove all attachments, set the `attachments` property to an empty dictionary
or `nil`:

Objective-C:

```objc
update.attachments = nil;
```
Swift:

```swift
update.attachments = nil
```

## Cookbook

This section shows all the ways (that I could think of) that you can update,
modify and delete documents.

### Creating a new document

This is the simplest case as we don't need to worry about previous revisions.

1. Add a document with body, but not attachments or ID. You'll get an
   autogenerated ID.

   Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{ ... } mutableCopy];

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision()
    rev.body = [....]
    let saved = try datastore.createDocumentFromRevision(rev)
    ```

1. Add a new document to the store with a body and ID, but without attachments.

    Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
    rev.body = [@{ ... } mutableCopy];

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev
                                                                 error:&error];
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision("doc1")
    rev.body = [....]
    let saved = try datastore.createDocumentFromRevision(rev)
    ```

1. Add a new document to the store with attachments.

    Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
    rev.body = [@{ ... } mutableCopy];

    CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                      initWithPath:@"path"
                              name:@"filename"
                              type:@"image/jpeg"]]
    rev.attachments = [@{ att1.name:att1 } mutableCopy];

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision("doc1")
    rev.body = [....]

    let att1 = CDTUnsavedFileAttachment(path: "path",
        name: "filename",
        type: "image/jpeg")
    rev.attachments = [att1.name : att1]

    let saved = try datastore.createDocumentFromRevision(rev)
    ```

1. Add a document with body and attachments, but no ID. You'll get an
   autogenerated ID.

   Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.body = [@{ ... } mutableCopy];

    CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                      initWithPath:@"path"
                              name:@"filename"
                              type:@"image/jpeg"]]
    rev.attachments = [@{ att1.name:att1 } mutableCopy];

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision()
    rev.body = [....]

    let att1 = CDTUnsavedFileAttachment(path: "path",
        name: "filename",
        type: "image/jpeg")
    rev.attachments = [att1.name : att1]

    let saved = try datastore.createDocumentFromRevision(rev)
    ```

1. You can't create a document without a body (body is the only required property).

    Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revision];
    rev.docId = @"doc1";

    CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
    // Fails, saved is nil
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision("doc1")
    let saved = try datastore.createDocumentFromRevision(rev)
    // failed error has been thrown
    ```

### Updating a document

To update a document, call `mutableCopy` on the original document revision,
make your changes and save the document.

For the first set of examples the original document is set up with a body
and no attachments:

Objective-C:

```objc
CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
rev.body = [@{ ... } mutableCopy];

CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
```
Swift:

```swift
let rev = CDTDocumentRevision("doc1")
rev.body = [....]

let saved = try datastore.createDocumentFromRevision(rev)
```

We also assume an attachment ready to be added:

Objective-C:

```objc
CDTUnsavedFileAttachment *att1 = [[CDTUnsavedFileAttachment alloc]
                  initWithPath:@"/path/to/image.jpg"
                          name:@"cute_cat.jpg"
                          type:@"image/jpeg"]];
```
Swift:

```swift
let att1 = CDTUnsavedFileAttachment(path: "/path/to/image/jpg",
    name: "cute_cat.jpg",
    type: "image/jpeg")
```

1. Update body for doc that has no attachments, keeping no attachments

    Objective-C:

    ```objc
    saved.body = [@{ ... } mutableCopy];
    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.body = [....]
    let updated = try datastore.updateDocumentForRevision(saved)
    ```

1. Update body for doc with no attachments, adding attachments.

    Objective-C:

    ```objc
    saved.body[@"hello"] = @"world";
    saved.attachments[@att1.name] = att1;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.body["hello"] = "world"
    saved.attachments[att1.name] = att1

    let updated = try datastore.updateDocumentForRevision(saved)
    ```

1. Update body for doc with no attachments, removing attachments dictionary
   entirely.

    Objective-C:

    ```objc
    saved.body[@"hello"] = @"world";
    saved.attachments = nil;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.body["hello"] = "world"
    saved.attachments = nil

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Update the attachments without changing the body, add attachments to a doc
   that had none.

   Objective-C:

    ```objc
    saved.attachments[@att1.name] = att1;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.attachments[att1.name] = att1

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Update attachments by copying from another revision.

    Objective-C:

    ```objc
    CDTDocumentRevision *anotherDoc = [datastore getDocumentForId:@"anotherId"];
    saved.attachments = anotherDoc.attachments;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    let anotherDoc = datastore.getDocumentForId("anotherId")
    saved.attachments = anotherDoc.attachments

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Updating a document using an outdated source revision causes a conflict

    Objective-C:

    ```objc
    saved.body = [@{ ... } mutableCopy];
    [datastore updateDocumentFromRevision:saved];

    // Note this is the old revision!
    saved.body = @{ ... ... };

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    // Updated should be nil, and error should be set/exception thrown
    ```
    Swift:

    ```swift
    saved.body = [....]
    try datastore.updateDocumentFromRevision(saved)

// Note this is the old revision!
    saved.body = [....]
    let updated = try datastore.updateDocumentFromRevision(saved)

    // scope will change since an error will have been thrown
    ```


For the second set of examples the original document is set up with a body and
several attachments:

Objective-C:

```objc
CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
rev.body = [@{ ... } mutableCopy];

CDTUnsavedFileAttachment *att1 = /* blah */
/* set up more attachments */
rev.attachments = [@{ att1.name:att1, att2.name:att2, att3.name:att3 } mutableCopy];

CDTDocumentRevision *saved = [datastore createDocumentFromRevision:rev];
```
Swift:

```swift
let rev = CDTDocumentRevision("doc1")
rev.body = [....]
let att1 = CDTUnsavedFileAttachment(/* blah */)
/* set up more attachments */
rev.attachments = [att1.name:att1, att2.name:att2, att3.name:att3]

let saved = datastore.createDocumentFromRevision(rev)
```

1. Update body without changing attachments

    Objective-C:

    ```objc
    saved.body[@"hello"] = @"world";

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    // Should have the same attachments
    ```
    Swift:

    ```swift
    saved.body["hello"] = "world"

    let updated = try datastore.updateDocumentFromRevision(saved)

    // Should have the same attachments
    ```

1. Update the attachments without changing the body, remove attachments

    Objective-C:
    
    ```objc
    [saved.attachments removeObjectForKey:att1.name];

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.attachments.removeValueForKey(att1.name)

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Update the attachments without changing the body, add attachments

    Objective-C

    ```objc
    // Create att100 attachment
    saved.attachments[att100.name] = att100;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    // Create att100 attachment
    saved.attachments[att100.name] = att100

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Update the attachments without changing the body, remove all attachments
   by setting `nil` for attachments dictionary.

   Objective-C:

    ```objc
    saved.attachments = nil;

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.attachments = nil

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Update the attachments without changing the body, remove all attachments
   by setting an empty dictionary.
    ```objc
    saved.attachments = [@{} mutableCopy];

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    saved.attachments = []

    let updated = try datastore.updateDocumentFromRevision(saved)
    ```

1. Copy an attachment from one document to another.

    Objective-C:

    ```objc
    // Create a revision with attachments
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
    rev.body = [@{ ... } mutableCopy];
    CDTUnsavedFileAttachment *att1 = /* blah */
    rev.attachments = [@{ att1.name: att1 } mutableCopy];
    CDTDocumentRevision *revWithAttachments = [datastore createDocumentFromRevision:rev
                                                                              error:&error];

    // Add attachment to "saved" from "revWithAttachments"
    CDTAttachment *savedAttachment = revWithAttachments.attachments[@"nameOfAttachment"];
    saved.attachments = @{savedAttachment.name: savedAttachment};

    CDTDocumentRevision *updated = [datastore updateDocumentFromRevision:saved
                                                                   error:&error];
    ```
    Swift:

    ```swift
    //Create a revision with attachments
    let rev = CDTDocumentRevision("doc1")
    rev.body = [....]
    let att1 = CDTUnsavedFileAttachment(/* blah */)
    rev.attachments = [att1.name : att1]
    let revWithAttachments = try datastore.createDocumentFromRevision(saved)

    // Add attachment to "saved" from "revWithAttachments"
    let savedAttachment = revWithAttachments.attachments["nameOfAttachment"]
    saved.attachments = [savedAttachment.name:savedAttachment]

    let updated = try datastore.updateDocumentForRevision(saved)
    ```


### Creating a document by copying data

It should be possible to create a new document by copying data from another
document:

1. Copy a document with attachments, adding or modifying one attachment

    Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc2"];
    rev.body = [saved.body mutableCopy];
    rev.body[@"hello"] = @"world";
    // Create att100 attachment
    rev.attachments = [saved.attachments mutableCopy];
    rev.attachments[att100.name] = att100;

    CDTDocumentRevision *updated = [datastore createDocumentFromRevision:rev
                                                                   error:&error];
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision("doc2")
    rev.body = saved.body
    rev.body["hello"] = "world"
    // Create att100 attachment
    rev.attachments = saved.attachments
    rev.attachments[att100.name] = att100;

    let updated = try datastore.updateDocumentFromRevision(rev)
    ```

1. Copy a document's body to a new document, adding or changing a value,
   without also copying attachments

   Objective-C:

    ```objc
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc2"];
    rev.body = [saved.body mutableCopy];
    rev.body[@"hello"] = @"world";

    CDTDocumentRevision *updated = [datastore createDocumentFromRevision:rev
                                                                   error:&error];
    ```
    Swift:

    ```swift
    let rev = CDTDocumentRevision("doc2")
    rev.body = saved.body
    rev.body["hello"] = "world"

    let updated = try datastore.createDocumentFromRevision(rev)
    ```

1. Fail if the document ID is present in the datastore. Note this shouldn't
   fail if the document is being added to a different datastore.

   Objective-C:

    ```objc
    // Doc ID same as `saved`:
    CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"doc1"];
    rev.body[@"hello"] = @"world";

    CDTDocumentRevision *updated = [datastore createDocumentFromRevision:rev
                                                                   error:&error];
    // Fails, saved is nil

    CDTDocumentRevision *updated = [other_datastore createDocumentFromRevision:rev
                                                                         error:&error];
    // Succeeds
    ```
    Swift:

    ```swift
    // Doc ID same as `saved`
    let rev = CDTDocumentRevision("doc1")
    rev.body["hello"] = "world"

    let updated = try datastore.createDocumentFromRevision(rev)

    // Fails, error is thrown

    let updated = try other_datastore.createDocumentFromRevision(rev)
    // Succeeds
    ```


### Deleting a document

1. You should be able to delete a given revision (i.e., add a tombstone to the end of the branch).

        Objective-C:

       ```objc
       CDTDocumentRevision *saved = [datastore getDocumentForId:@"doc1"];
       CDTDocumentRevision *deleted = [datastore deleteDocumentFromRevision:saved
                                                                      error:&error];
       ```
       Swift:

       ```swift
       let saved = datastore.getDocumentForId("doc1")
       let deleted = try datastore.deleteDocumentFromRevision(saved)
       ```

       This would refuse to delete if `saved` was not a leaf node.

1. **Advanced** You should also be able to delete a document in its entirety by passing in an ID.

        Objective-C:

       ```objc
       CDTDocumentRevision *deleted = [datastore deleteDocumentWithId:"@doc1"
                                                                error:&error];
       ```
       Swift:

       ```swift
       let deleted = try datastore.deleteDocumentWithId("doc1")
       ```

    This marks *all* leaf nodes deleted. Make sure to read
    [conflicts.md](conflicts.md) before using this method as it can result
    in data loss (deleting conflicted versions of documents, not just the
    current winner).
