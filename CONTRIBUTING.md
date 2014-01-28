# Contributing to CDTDatastore

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

## Getting started with the project

Open up `CDTDatastore.xcworkspace`. This workspace is where you should do all
your work. It contains:

* The CDTDatastore source code, following the folder structure in `Classes`.
* The test project, `Tests`.
* The example application, `Project`.
* `Pods` where the test and example app dependencies are built (including
  CDTDatastore itself).

Initially, the Pods project will be missing and the tests and example app
won't build or run.

To run the tests, install the dependencies using Cocoapods:

```bash
# Close the Xcode workspace before doing this!

cd Tests
pod install
```

To run the example project, you'll need to run `pod install` from the project
directory:

```bash
cd Project
pod install
```

This will create the Pods project and add CDTDatastore and its dependencies
to the projects. You can now run the tests and the example project from Xcode.

As you edit the source code in the `CDTDatastore` group, the Pods project will
be rebuilt when you run the tests as it references the code in `Classes`.

At this point, run both the tests from the Tests project and the example app
to make sure you're setup correctly.

### Documentation

Install [appledocs][appledocs].

Use `rake docs` to build the docs and install into Xcode.

[appledocs]: http://gentlebytes.com/appledoc/

### Using xcodebuild and xcpretty to run the tests

Run the following at the command line:

```
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests' test | xcpretty
```

Miss out the `| xcpretty` if you didn't install that.

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
