# Contributing to CDTDatastore

## Contributor License Agreement

In order for us to accept pull-requests, the contributor must first complete
a Contributor License Agreement (CLA). This clarifies the intellectual 
property license granted with any contribution. It is for your protection as a 
Contributor as well as the protection of IBM and its customers; it does not 
change your rights to use your own Contributions for any other purpose.

This is a quick process: one option is signing using Preview on a Mac,
then sending a copy to us via email. Signing this agreement covers both
[CDTDatastore](https://github.com/cloudant/CDTDatastore) and 
[sync-android](https://github.com/cloudant/sync-android).

You can download the CLAs here:

 - [Individual](http://cloudant.github.io/cloudant-sync-eap/cla/cla-individual.pdf)
 - [Corporate](http://cloudant.github.io/cloudant-sync-eap/cla/cla-corporate.pdf)

If you are an IBMer, please contact us directly as the contribution process is
slightly different.

## Setting up your environment

You have probably got most of these set up already, but starting from scratch
you'll need:

* Xcode
* Xcode command line tools
* Cocoapods
* Homebrew (optional, but useful)
* xcpretty (optional)

First, download Xcode from the app store or [ADC][adc].

When this is installed, install the command line tools. The simplest way is:

```bash
xcode-select --install
```

Install homebrew using the [guide on the homebrew site][homebrew].

Install cocoapods using the [guide on their site][cpinstall].

Finally, if you want to build from the command line, install [xcpretty][xcpretty],
which makes the `xcodebuild` output more readable.

It's a gem:

```bash
sudo gem install xcpretty
```

[adc]: http://developer.apple.com/
[xcpretty]: https://github.com/mneorr/XCPretty
[homebrew]: http://brew.sh
[cpinstall]: http://guides.cocoapods.org/using/index.html

## Coding guidelines

The house style is [documented](doc/style-guide.md). There's information there on using
`clang-format` to automatically use the right format.

## Getting started with the project

The main workspace is `CDTDatastore.xcworkspace` in the root of the checkout.
There is also another workspace called `EncryptionTests.xcworkspace` in
`EncryptionTests` folder. Before the projects inside will run, you need to use
Cocoapods to get the dependencies set up correctly for each project. The `Podfiles`
are actually inside the `Tests` and `EncryptionTests` folders:

```bash
# Close the Xcode workspace before doing this!

cd Tests
pod install
cd ../EncryptionTests
pod install
cd ..
```

Open up `CDTDatastore.xcworkspace`.

```bash
open CDTDatastore.xcworkspace
```

This workspace is where you should do all your work. If you intend to work with
database encryption, you will need to include test cases in
`EncryptionTests.xcworkspace` (the only purpose of this workspace is to run
tests, do not include anything else but test cases). `CDTDatastore.xcworkspace`
contains:

* The CDTDatastore source code, following the folder structure in `Classes`.
* The test project, `Tests`.
* The example application, `Project`.
* `Pods` where the test and example app dependencies are built (including
  CDTDatastore itself).

If things don't work, you probably skipped over the bit above where the
dependencies are set up.

As you edit the source code in the `CDTDatastore` group, the Pods project will
be rebuilt when you run the tests as it references the code in `Classes`.

At this point, run both the tests from the Tests project and the example app
to make sure you're setup correctly. To run the tests, change the Scheme to
either `Tests iOS` or `Tests OSX` using the dropdown in the top left. It'll
probably be the `Project` scheme to start with. Once you've changed the
scheme, `cmd-u` should run the tests on your preferred platform.

### Adding and removing files

First, make sure you add them to the right folder within the `Classes` structure:

* `common` for most new files.
  * Use a subfolder of `common` for discrete subsystems.
* `vendor` for any libraries that can't be brought in via cocoapods.

**If you add or remove files, run `pod update` in `Tests` to get them into
the build. Then add them to the workspace, under the CDTDatastore group.**

_Note_: `rake podupdate` will update all projects' workspaces, which is a useful
shortcut.

When adding files to the workspace, make sure to keep the groups in the
workspace up to date with the file locations on the file system.

### Tests and encryption tests

It is possible to combine `CDTDatastore` with [SQLCipher][SQLCipher] to generate
encrypted databases. More exactly, `CDTDatastore` relies on [FMDB][FMDB] to
access SQLite databases and FMDB is able to do that using the standard iOS
library for SQLite or SQLCipher.

If SQLCipher is not included but you try to create a `CDTDatastore` with a
encryption key (providing an instance that conforms to protocol
[CDTEncryptionKeyProvider][CDTEncryptionKeyProvider]), the operation will fail
given that we lack the code to cipher the database. But it will succeed if the
pod for SQLCipher is in the workspace.

This is the reason why we need two different workspaces. The code does not
change, however the behaviour is different depending of the libraries included.
The `Podfile` in `EncryptionTests` is configured to import FMDB with SQLCipher
while `CDTDatastore.xcworkspace` uses the default version of FMDB.
`EncryptionTests.xcworkspace` has a sub-set of the tests in
`CDTDatastore.xcworkspace`, the tests in the former are expected to succeed
when a key is provided while the tests in the second have to fail.

If you want CDTDatastore to cipher the databases, you do not need to include
SQLCipher as a pod in your `Podfiles`, replace:

```
pod "CDTDatastore"
```

With:

```
pod "CDTDatastore/SQLCipher"
```

[SQLCipher]: https://www.zetetic.net/sqlcipher/
[FMDB]: https://github.com/ccgus/fmdb
[CDTEncryptionKeyProvider]: Classes/common/Encryption/CDTEncryptionKeyProvider.h

### Documentation

Install [appledocs][appledocs].

Use `rake docs` to build the docs and install into Xcode.

As the `appledocs` docs themselves are down, here's a
[good introduction to the format](http://www.cocoanetics.com/2011/11/amazing-apple-like-documentation/).

[appledocs]: http://gentlebytes.com/appledoc/

### Using xcodebuild and xcpretty to run the tests

Run the following at the command line:

```
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests iOS' test | xcpretty -c
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests OSX' test | xcpretty -c
xcodebuild -workspace EncryptionTests/EncryptionTests.xcworkspace -scheme 'Encryption Tests' test | xcpretty -c
xcodebuild -workspace EncryptionTests/EncryptionTests.xcworkspace -scheme 'Encryption Tests OSX' test | xcpretty -c
```

To test on a specific device you need to specify `-destination`:

```
// iOS
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests iOS' -destination 'platform=iOS Simulator,OS=latest,name=iPhone 4S' test | xcpretty

// Mac OS X
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests OSX' -destination 'platform=OS X' test | xcpretty
```

Xcodebuild references:

* [man page](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcodebuild.1.html)

Miss out the `| xcpretty` if you didn't install that.

### Configuring ReplicationAcceptance Tests

ReplicationAcceptance are a set of tests which tests the replication function of CDTDatastore, the tests are found in the ReplicationAcceptance.xcworkspace in the ReplicationAcceptance directory in CDTDatastore. 

The tests can be configured by using a series of environment variables. The environment variables are as follows:

Environment Variable | Purpose | Default
------------ | ------------- | ------------- | -------------
`TEST_COUCH_HOST` | CouchDB hostname | `localhost`
`TEST_COUCH_PORT` | Port couchdb is listening on | `5984`
`TEST_COUCH_HTTP` | http protocol to use, either http or https | `http`
`TEST_COUCH_USERNAME` | CouchDB account username | 
`TEST_COUCH_PASSWROD` | CouchDB account Password | 


Example

```bash

$ export TEST_COUCH_HOST=couchdbhost
$ export TEST_COUCH_PORT=8080
$ export TEST_COUCH_HTTP=http
$ export TEST_COUCH_USERNAME=auser
$ export TEST_COUCH_PASSWORD=apassword
$ xcodebuild -workspace ReplicationAcceptance.xcworkspace -scheme RA_Tests_OSX -destination 'platform=OS X' test | xcpretty

```

## Contributing your changes

We follow a fairly standard proceedure:

* Fork the CDTDatastore repo into your own account, clone to your machine.
* Create a branch with your changes on (`git checkout -b my-new-feature`)
  * Make sure to update the CHANGELOG and CONTRIBUTORS before sending a PR.
  * All contributions must include tests.
  * Try to follow the style of the code around the code you
    are adding -- the project contains source code from a few places with
    slightly differing styles.
* Commit your changes (`git commit -am 'Add some feature'`)
* Push to the branch (`git push origin my-new-feature`)
* Issue a PR for this to our repo.
