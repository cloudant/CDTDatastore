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

## Coding guidelines

The house style is [documented](doc/style-guide.md). There's information there on using
`clang-format` to automatically use the right format.

## Getting started with the project

The main workspace is `CDTDatastore.xcworkspace` in the root of the checkout.
Before the projects inside will run, you need to use Cocoapods to get the
dependencies set up correctly for each project. The `Podfile` is actually
inside the `Tests` folder:

```bash
# Close the Xcode workspace before doing this!

cd Tests
pod install
cd ..
```

Open up `CDTDatastore.xcworkspace`. This workspace is where you should do all
your work. 

```bash
open CDTDatastore.xcworkspace
```

The workspace contains:

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

### Documentation

Install [appledocs][appledocs].

Use `rake docs` to build the docs and install into Xcode.

As the `appledocs` docs themselves are down, here's a
[good introduction to the format](http://www.cocoanetics.com/2011/11/amazing-apple-like-documentation/).

[appledocs]: http://gentlebytes.com/appledoc/

### Using xcodebuild and xcpretty to run the tests

Run the following at the command line:

```
xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests' test | xcpretty -c
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
