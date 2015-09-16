# Migrating to new APIs

## 0.17.1 &rarr; 0.18.0

This change removes `CDTMutableDocumentRevision`. In a sense, it's the next
logical step from the `0.8` transition, further streamlining document create,
read, update and delete operations. It also makes the operation of the
revision objects more similar to other systems, like CoreData.

The key changes are:

- Remove `CDTMutableDocumentRevision` class.
- Instead, `CDTDocumentRevision` is now a mutable class which can be used to
  update documents.

### Update process

1. Remove use of `mutableCopy` to create `CDTMutableDocumentRevision` objects.
1. If required, use `copy` on `CDTDocumentRevision` to create copies of
   revisions (say if you are relying on the original object not changing for
   use in UIs etc.).
1. Update code to use `CDTDocumentRevision` objects everywhere.
   - In particular, where assigning `NSDictionary` objects to either
     `body` or `attachments`, you now must use `NSMutableDictionary` objects.
   - For most CRUD operations this is hopefully simple; the API for
     `CDTDocumentRevision` and `CDTMutableDocumentRevision` is similar and
     the same methods on `CDTDatastore` objects are used.
   - For conflict resolution, use of the `copy` method may be useful.
1. Hopefully, see a simplification in your codebase.

Below are examples of using the new API.

#### Creating a document

Instead of using an `CDTMutableDocumentRevision` object, just create a
`CDTDocumentRevision`, make your changes and ask the datastore to create a
document from the revision:

```objc
// `rev` is created without a revision ID.
CDTDocumentRevision *rev = [CDTDocumentRevision revisionWithDocId:@"docId"];
rev.body = [@{@"key":@"value"} mutableCopy];

rev1 = [datastore createDocumentFromRevision:rev
                                      error:&error];
// `rev1` will now have a revision ID. Note `rev1` is a different object to rev
```

A key change is that the `body` and `attachment` attributes on
`CDTDocumentRevision` classes now must be a mutable dictionary. Previously,
it could be either. This change was made to enable use of `body` as a real
property, which makes interacting with the datastore in Swift easier.

#### Updating a document

Instead of creating a `CDTMutableDocumentRevision` from a retrieved revision,
just make changes on the retrieved revision and update it:

```objc
rev1 = [datastore createDocumentFromRevision:rev
                                      error:&error];
rev1[@"newKey"] = @"newValue";

CDTDocumentRevision * newRev = [datastore updateDocumentFromRevision:rev1
                                                               error:&error];
```

#### Deleting a document

This hasn't changed, just call delete with an existing revision:

```objc
rev1 = [datastore createDocumentFromRevision:rev
                                      error:&error];
[datastore deleteDocumentFromRevision:rev1 error:&error];
```

## 0.7 &rarr; 0.8

This change introduces `CDTMutableDocumentRevision` to fix problems when
creating, updating and removing documents. For example, you can now modify
both document content and attachments in a single update.

With the release of 0.7 some methods were deprecated, and then in another release 0.8.0,
they were removed this will guide you through the differences and how to migrate to the new API.


### Deprecated Methods

#### Attachments

* `attachmentNamed:(NSString*)name forRev:error:`
* `updateAttachments:forRev:error:`
* `removeAttachments:fromRev:error:`

### Documents

* `createDocumentWithId:ody:error:`
* `createDocumentWithBody:error:`
* `updateDocumentWithId:prevRev:body:error:`
* `deleteDocumentWithId:rev:error:`

### Deprecated Classes

* `CDTDocumentBody`

### Creating a document

Pre-0.7 the API required the creation of a `CDTDocumentBody` object which held the information
to store in the body of the document. This was deprecated and replaced with ```CDTMutableDocumentRevision```
as a result document creation is more streamlined.

```objc
CDTMutableDocumentRevision * mutable = [CDTMutableDocumentRevision revision];
mutableRevision.body = @{@"key":@"value"};
mutableRevision.docId = @"docID"

CDTDocumentRevision * rev = [datastore createDocumentFromRevision:rev
															error:&error];
```

### Updating a document

Previously updating a document required the creation of a new `CDTDocumentBody` and passing
directly the revision of which it is replacing and its doc id. This information is extracted from
the `CDTDocumentRevision` object.

The updates to the API mean you no longer extract this information from a `CDTDocumentRevision`
instead call ```mutableCopy``` and update the properties on the returned object.

```objc
CDTMutableDocumentRevision * mutable = [rev mutableCopy];
[mutable.body setObject:@"newValue" forKey:@"newKey"];

CDTDocumentRevision * newRev = [datastore updateDocumentFromRevision:mutable
															   error:&error];

```

### Deleting a document

The new API streamlines document deletion by accepting  the `CDTDocumentRevision` object as parameter
which represents the revision you wish to delete.

```objc
CDTRevision * deleted = [datastore deleteDocumentFromRevision:rev error:&error];

```

### Adding attachments

Adding attachments in the old API created new revision for a document.
With the new API it is possible to add the  body
and attachments for the document in the same revision

```objc
CDTAttachment * attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:attachmentName
                                                                          type:@"image/jpg"];

CDTMutableDocumentRevision * mutableRev = [CDTMutableDocumentRevision revision];
mutableRev.body = @{@"aKey":@"aValue"};

mutableRev.attachments = @{attachment.name : attachment};
CDTDocumentRevision * rev = [datastore createDocumentFromRevision:mutableRev error:&error];

```

Note: Updating attachments follows a similar process, see Document [CRUD](./crud.md)

### Removing attachments

Removing attachments from documents can also be completed in conjunction with updating the document body

```objc
CDTMutableDocumentRevision * mutableRevision = [rev mutableCopy];

[mutableRevision.attachments removeObjectForKey:attachmentNameToRemove];

CDTDocumentRevision * updatedRev = [datastore updateDocumentForRevision:mutableRevision error:&error];
```

