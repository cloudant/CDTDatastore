# CDTDatastore CHANGELOG

## Unreleased

- [NEW] Added replication policies, allowing users to easily create policies such as "Replicate
   every 2 hours, only when on Wifi". See the [Replication Policies User Guide](doc/replication-policies.md).
- [IMPROVED] Replications will use session cookies to authenticate rather than
   using Basic Auth for every request.

## 1.0.0 (2015-11-6)

- [BREAKING] CDTMutableDocumentRevision removed. CDTDocumentRevision objects
  are now mutable -- you can change them and pass to
  `updateDocumentFromRevision:error:` to make document updates. See
  [doc/api-migration.md](doc/api-migration.md).

## 0.19.2 (2015-11-3)
- [FIX] Replications using multipart attachment uploads would hang ([Issue #211](https://github.com/cloudant/CDTDatastore/issues/211))
- [FIX] Skip not found documents when performing allDocsQuery ([Issue #207](https://github.com/cloudant/CDTDatastore/issues/207))


## 0.19.1 (2015-10-9)
- [FIX] CDTSessionCookieInterceptableSession works now; we used GET rather than
   POST in error.

## 0.19.0 (2015-09-15)
- [IOS] Minimum iOS version now iOS 7. We now use NSURLSession.
- [OSX] Minimum OSX version now OSX 10.9. We now use NSURLSession.
- [NEW] HTTP Interceptor API. See [Http Interceptors](https://github.com/cloudant/CDTDatastore/blob/master/doc/httpinterceptors.md) for details.

## 0.18.0 (2015-09-07)

- [FIX] Can build with Xcode 7.
- [NEW] Added query support for the `$size` operator.
- [NEW] CDTFetchChanges class now has `resultsLimit` and `moreComing`
    properties.
- [NEW] `getAllDocumentIds` on CDTDatastore.
- [FIX] Fixed issue where at least one index had to be created before a query
    would execute.  You can now query for documents without the existence of
    any indexes.
- [FIX] A bug where getAllDocuments could get confused when there were
    conflicts within the datastore created in a certain order.
- [REMOVED] Removed deprecated method `start` on CDTReplicator, use
    `startWithError` instead.

## 0.17.1 (2015-06-24)

- [FIX] Allow using encrypted datastores and FTS together.
- [CHANGE] Include `CloudantSyncEncryption.h` to access encryption features,
  in addition to `CloudantSync.h`.
  We found the previous preprocessor approach didn't work in Swift.
- [FIX] Pin SQLCipher version to one we've tested with.
- [FIX] Under some circumstances unneeded attachment blobs were not
  cleaned up.
- [FIX] Empty array fields we not indexed, which would cause some queries to
  unexpectedly fail.

## 0.17.0 (2015-06-11)

- [NEW] Encryption of all data is now supported using 256-bit AES:
  JSON documents, Query indexes and attachments. See
  [encryption documentation][17-1]
  for details.
- [NEW] Added query text search support.  See
  [query documentation][17-2]
  for details.
- [NEW] Query now supports the `$mod` operator.
- [REMOVED] Legacy indexing code removed, replaced with Query. See doc/query-migration.md.
- [IMPROVED] Allow cancelling CDTFetchChanges operations.
- [FIXED] Some issues with creating remote URLs for attachments.

[17-1]: https://github.com/cloudant/CDTDatastore/blob/master/doc/encryption.md
[17-2]: https://github.com/cloudant/CDTDatastore/blob/master/doc/query.md

## 0.16.0 (2015-04-09)

- [NEW] We've migrated the Cloudant Query for iOS code which
  used to live in the CloudantQueryObjc repository into
  CDTDatastore itself. Please be sure to remove references
  to the CloudantQueryObjc repository from your Podfiles.
  Including CloudantSync.h will include all necessary
  Cloudant Query code. See doc/query.md in this repo for documentation.
  We hope you enjoy using Query!
- [FIX] Both Query and the old indexing code had a bug where
  resolved conflicts could cause documents not to be indexed.
  This is now fixed.
- [PREVIEW] CloudKit-inspired changes fetcher, see commit
  65fa9a63281c1fa4063f64e1df9dfe5b8d69384d or CDTFetchChanges.h.

## 0.15.0 (2015-03-24)

- [FIX] Previously, we overwrote the `winner` field of CDT-notification emitted
  on datastore changes when translating from TouchDB's event.  We now copy over
  the `source` field correctly to the new notification.
- [NOTE] Bump CocoaLumberjack to 2.0.0

## 0.14.0 (2015-02-13)

- [FIX] Accept CouchDB 2.0 and Cloudant Local's array-based sequence numbers.
- [FIX] Writing final remote checkpoint document during replication.

## 0.13.0 (2015-01-16)

- [NEW] CDTDatastoreManager has an -allDatastores which returns the names of
  all the datastores in the folder it's manges.
- [NEW] Reading the _changes feed now uses NSURLConnection rather than
  CFNetworking calls. This hopefully starts to map our way forward to
  NSURLSession.
- [FIX] Passwords are now obscured in log messages during replication.
- [FIX] The behavior and documentation regarding the CDTReplicator's
  fire-and-forget it have been updated. At the moment, CDTReplicator
  is not fire-and-forget. Strong references to CDTReplicators must be
  retained in order for replication to complete. Premature deallocation
  will stop replication and call it's delegate's -replicatorDidError method.
  See the example application for details on using the CDTReplicator.
- [FIX] A crash during push replication if the local database disappears.
- [NOTE] CocoaLumberjack is bumped to 2.0.0-rc

## 0.12.1 (2014-12-10)

- [FIX] Using CDTChangeLogLevel now sets log levels across the library
  correctly.
- [FIX] Calling -mutableCopy on CDTMutableDocumentRevision objects now
  works.

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
