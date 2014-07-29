# CDTDatastore CHANGELOG

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
