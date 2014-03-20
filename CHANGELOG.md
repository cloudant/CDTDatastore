# CDTDatastore CHANGELOG

## 0.0.5 (Unreleased)

- FIX The rare queries that return deleted documents no longer
  crash an application.
- FIX Replicating a database with documents containing attachments
  no longer causes a crash. (No API for accessing attachments yet).
- CHANGE Deleting a document now returns the new revision.

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
