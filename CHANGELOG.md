# CDTDatastore CHANGELOG

## 0.12.0 (2014-11-24)

- [NEW] CDTDatastore gains a -compact function, run this to remove
  old revision content and attachments.
- [CHANGE] Each replication runs its own thread, rather than running all
  replications on a single thread. This removes the -start method from
  CDTReplicatorFactory: the class is now purely a factory for replicator
  objects.
- [FIX] Logging macros and constants now have a CDT-prefix to avoid naming
  collisions.

## 0.11.0 (2014-11-11)

- [FIX] Incompatibility with CocoaLumberjack 2.0.0-beta4. Also pin to beta4.
- [FIX] Downloading attachments from HTTP endpoints in CDTSavedHTTPAttachment,
  where only the first one in a run of the app would be downloaded.

The following were actually released but not documented in the 0.10.1 release,
overlooked in getting out a release to fix builds:

- [NEW] Allow setting custom HTTP headers for replications. Use the
  CDTAbstractReplication's `optionalHeaders` property to add headers. See
  the help note for headers which can't be set (because the library
  overwrites them).
- [FIX] Some build issues created in an attempt to have the library version
  defined in a single place.

## 0.10.1 (2014-11-10)

- Pin CocoaLumberjack to 2.0.0-beta3 as our logging macros depend on deprecated
  macros. This should fix builds for anyone running pod install/update.

## 0.10.0 (2014-10-20)

- [CHANGE] Index updates are deferred until query time. This avoids excessive
  indexing load during replication.

## 0.9.0 (2014-10-09)

- [NEW] Logging now uses Cocoa Lumberjack.
- [FIX] Pushing resurrected documents.
- [FIX] Ensure replication callbacks are called.
- [FIX] Significant improvements to replication state machine management.
- [FIX] Issues building example app with newer cocoapods versions.
- [FIX] CDTReplicator object getting deallocated during callback to itself.

## 0.8.0 (2014-09-29)

- [FIX] Fix indexes not updating correctly when using new CRUD API, introduced
  in 0.7.0.
- [NEW] Allow using NSPredicates when querying for documents.
- [NEW] Use CDTMutableDocumentRevision during conflict resolution (breaking change).
- [NEW] Removal of deprecated APIs. See doc/api-migration.md for the list of remove
  APIs and how to migrate away from them.
- [FIX] Several fixes to how CDTReplicator reports state changes.

## 0.7.0 (2014-08-18)

- NEW CRUD and Attachments API. See doc/crud.md for docs on both CRUD and
  attachments, along with a cookbook on using the new API.
- DEPRECATED Existing attachments and CRUD APIs. These will be removed before
  1.0.
- When a replication fails, the error message is properly propagated through
  the error callback on a CDTReplicator object.

## 0.0.6 (2014-07-29)

- NEW Conflicts API, a developer can resolve a conflicted document
  by selecting one of the conflicts as the winner.
- NEW Filtered pull and push replication.
- NEW Datastores can now be deleted through the API.
- BETA Attachments support (see CDTDatastore+Attachments.h). The API for
  this is still in flux, right now you can't modify attachment content
  and JSON content at the same time.
- CHANGE Indexes now stay up to date as the datastore is modifed.
- CHANGE CDTDocumentBody objects can no longer be passed underscore
  prefixed fields, for example _id. They were inconsistently used,
  so ripe to cause bugs in applications.
- MISC Add example of how to use indexing and query to the
  sample application.
- MISC _replicator database removed for managing attachments. Should be
  transparent to users of CDTReplicator classes.
- FIX Replicating attachments with revpos > doc generation.
- FIX Recover from a certain subset of HTTP 412 errors when replicating.

## 0.0.5 (2014-03-20)

- CHANGE Deleting a document now returns the new revision.
- FIX The rare queries that return deleted documents no longer
  crash an application.
- FIX Replicating a database with documents containing attachments
  no longer causes a crash. (No API for accessing attachments yet).
- FIX Executing a -compact works (update for newer FMDB API).

## 0.0.4 (2014-02-27)

- FIX Make sure all accesses to CDTDatastore's internal TD_Database
  property cause the underlying database to be opened correctly.
- FIX Break out extensions directory into one per database. This
  will mean existing extensions (i.e., indexes) need to recreate
  their data.
- FIX Example application can now log replication success without
  crashing.
- Add ReplicationAcceptance project.

## 0.0.3 (2014-02-17)

Initial release.
