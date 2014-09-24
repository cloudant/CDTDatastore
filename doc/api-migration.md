## Migrating to the new API

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

