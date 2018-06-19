# Contributing

## Issues

Please [read these guidelines](http://ibm.biz/cdt-issue-guide) before opening an issue.
If you still need to open an issue then we ask that you complete the template as
fully as possible.

## Pull requests

We welcome pull requests, but ask contributors to keep in mind the following:

* Only PRs with the template completed will be accepted
* We will not accept PRs for user specific functionality

### Developer Certificate of Origin

In order for us to accept pull-requests, the contributor must sign-off a
[Developer Certificate of Origin (DCO)](DCO1.1.txt). This clarifies the
intellectual property license granted with any contribution. It is for your
protection as a Contributor as well as the protection of IBM and its customers;
it does not change your rights to use your own Contributions for any other purpose.

Please read the agreement and acknowledge it by ticking the appropriate box in the PR
 text, for example:

- [x] Tick to sign-off your agreement to the Developer Certificate of Origin (DCO) 1.1

## General information

### Getting started with the project

The main workspace is `CDTDatastore.xcworkspace` in the root of the
checkout. This contains everything needed to develop and test the
library - by changing the target it is possible to build different
variants of the library or run various unit test suites.

```bash
# Close the Xcode workspace before doing this!
pod update
```

Open up `CDTDatastore.xcworkspace`.

```bash
open CDTDatastore.xcworkspace
```

This workspace is where you should do all your work. `CDTDatastore.xcworkspace`
contains the following groups (the order is not significant):

Firstly, under the `CDTDatastore` project:

* `CDTDatastore`: the source code for CDTDatastore. If you are
  contributing to the library then this group will be of most
  relevance.

* `CDTDatastoreTests`: unit and integration tests for CDTDatastore. If
  you are contributing a new feature or making large modifications to
  an existing one, you may need to add or modify tests here.

* `CDTDatastoreReplicationAcceptanceTests`: longer-running regression
  tests which are run to ensure correctness of the replication
  implementation.

* `CDTDatastoreEncryptionTests`: unit and integration tests for the
  encryption-enabled build of CDTDatastore.

Additionally, under the `Pods` project:

* This project contains the various groups of source code files needed
  to build the third-party dependencies used by CDTDatastore.

At this point, run both the tests from the Tests project and the example app
to make sure you're setup correctly. To run the tests, change the Scheme to
either `CDTDatastoreTests` or `CDTDatastoreTestsOSX` using the dropdown in the top left. It'll
probably be the `CDTDatastore` scheme to start with. Once you've changed the
scheme, `cmd-u` should run the tests on your preferred platform.

The sample app shows how an developer might use the library in their
own application. The workspace for this is located in
`Project/Project.xcworkspace/`. In order to build and run this app you
will need to run `pod update` in the `Project` directory before
opening the workspace.

### Adding and removing files

First, make sure you add them to the right group within the `CDTDatastore` group:

* `vendor` for any libraries that can't be brought in via cocoapods.
* most files will be part of a discrete subsystem and will belong to a
  group for that subsystem, eg `Attachments`.
* some files are added directly to the top level of the
  `CDTDatastore`, but this will be a small number of files
  which are important or general-purpose in nature and do not belong
  to a subsystem.

When adding files to the workspace, make sure to keep the groups in the
workspace up to date with the file locations on the file system.

### Coding guidelines

The house style is [documented](doc/style-guide.md). There's information there on using
`clang-format` to automatically use the right format.

## Requirements

### Setting up your environment

You have probably got most of these set up already, but starting from scratch
you'll need:

* Xcode
* Xcode command line tools
* Cocoapods (minimum version 1.0.0 beta 2)
* Homebrew (optional, but useful)
* xcpretty (optional)

First, download Xcode from the app store or [ADC][adc].

When this is installed, install the command line tools. The simplest way is:

```bash
xcode-select --install
```

Install homebrew using the [guide on the homebrew site][homebrew].

Install cocoapods using the [guide on their site][cpinstall].

Note that we currently require a pre-release version of cocoapods, so
your install options will look something like this:

```bash
sudo gem install cocoapods --pre
```

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

## Building

### With Encryption

Add the `ENCRYPT_DATABASE=1` environment variable.

### Documentation

Install [appledocs][appledocs].

Use `rake docs` to build the docs and install into Xcode.

As the `appledocs` docs themselves are down, here's a
[good introduction to the format](http://www.cocoanetics.com/2011/11/amazing-apple-like-documentation/).

[appledocs]: http://gentlebytes.com/appledoc/

## Testing

### Tests and encryption tests

It is possible to combine `CDTDatastore` with [SQLCipher][SQLCipher] to generate
encrypted databases. More exactly, `CDTDatastore` relies on [FMDB][FMDB] to
access SQLite databases and FMDB is able to do that using the standard iOS
library for SQLite or SQLCipher.

If SQLCipher is not included but a `CDTDatastore` is created with an
encryption key (an instance that conforms to protocol
[CDTEncryptionKeyProvider][CDTEncryptionKeyProvider]), the operation
will fail.

The `CDTDatastore` and `CDTDatastoreOSX` targets can be used to build
the library with SQLCipher support. To enable SQLCipher support in the project
`pod update` needs to run the with environment variable `encrypted` set to `yes`,
to run the tests with encryption support, use the rakefile.

[SQLCipher]: https://www.zetetic.net/sqlcipher/
[FMDB]: https://github.com/ccgus/fmdb
[CDTEncryptionKeyProvider]: Classes/common/Encryption/CDTEncryptionKeyProvider.h

### Using xcodebuild and xcpretty to run the tests

Run the following at the command line:

```
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'CDTDatastoreTests' test | xcpretty -c
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'CDTDatastoreTestsOSX' test | xcpretty -c

# encrypted
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'CDTDatastoreTests' GCC_PREPROCESSOR_DEFINITIONS='${inherited} ENCRYPT_DATABASE=1' test | xcpretty -c
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'CDTDatastoreTestsOSX' GCC_PREPROCESSOR_DEFINITIONS='${inherited} ENCRYPT_DATABASE=1' test | xcpretty -c
```

To test on a specific device you need to specify `-destination`:

```
// iOS
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'CDTDatastoreTests' -destination 'platform=iOS Simulator,OS=latest,name=iPhone 4S' test | xcpretty -c

// Mac OS X
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'CDTDatastoreTestsOSX' -destination 'platform=OS X' test | xcpretty
```

Xcodebuild references:

* [man page](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcodebuild.1.html)

Miss out the `| xcpretty` if you didn't install that.

### Configuring ReplicationAcceptance Tests

These tests are executed via the various
`CDTDatastoreReplicationAcceptanceTests` targets (these targets vary
by platform - iOS and OSX, encryption is enabled the same way as for the main project)

The tests can be configured by using a series of environment variables. The environment variables are as follows:

Environment Variable | Purpose | Default
------------ | ------------- | ------------- | -------------
`TEST_COUCH_HOST` | CouchDB hostname | `localhost`
`TEST_COUCH_PORT` | Port couchdb is listening on | `5984`
`TEST_COUCH_HTTP` | http protocol to use, either http or https | `http`
`TEST_COUCH_USERNAME` | CouchDB account username |
`TEST_COUCH_PASSWORD` | CouchDB account Password |

Example

```bash

$ export TEST_COUCH_HOST=couchdbhost
$ export TEST_COUCH_PORT=8080
$ export TEST_COUCH_HTTP=http
$ export TEST_COUCH_USERNAME=auser
$ export TEST_COUCH_PASSWORD=apassword
$ xcodebuild -workspace ReplicationAcceptance.xcworkspace -scheme RA_Tests_OSX -destination 'platform=OS X' test | xcpretty

```
