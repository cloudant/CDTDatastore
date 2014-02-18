# Cloudant Sync Replication Tests

This project is a standalone user of CDTDatastore whose perpose in compilation is
to test the replication of CDTDatastore.

It also has some good example code, in that it shows how to create, update and delete
documents, along with how to replicate those to and from remote databases.

## Getting started

Install CouchDB using Homebrew. These tests run using a local couchdb by
default for performance purposes.

First, `pod install` to create the workspace for the tests:

```
cd /path/to/CDTDatastore
cd ReplicationAcceptance
pod install
```

Unlike the main Tests project, this creates a standalone workspace, 
`ReplicationAcceptance.xcworkspace`.

Even if you want to run the tests from the command line (recommended) you'll
need to open to workspace in Xcode at least once. Do that now.

Now you can run, using xcpretty if you want:

```
xcodebuild -workspace ReplicationAcceptance.xcworkspace -scheme RA_Tests -destination "platform=OS X" test

xcodebuild -workspace ReplicationAcceptance.xcworkspace -scheme RA_Tests -destination "platform=iOS Simulator,OS=latest,name=iPhone Retina (3.5-inch)" test
```

Unfortunately you need an iPhone app to run this on the device, so no device testing yet.

You can also do this from within Xcode.

These tests take a long time, so be patient.