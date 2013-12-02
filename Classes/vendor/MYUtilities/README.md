# MYUtilities ##

## Objective-C utilities for Cocoa programming on Mac OS X and iPhone

by Jens Alfke <jens@mooseyard.com>

These are useful things I've built over the years and can't live without. This Git repo is basically a mirror of the original Mercurial repo at [Bitbucket.org](https://bitbucket.org/snej/myutilities/src).

The core parts are:

### CollectionUtils

A grab-bag of shortcuts for working with Foundation classes, mostly collections. If you've ever been envious of how simple it is to construct an array or hash in Ruby, Python or PHP, give these a try.

### Logging

Everyone seems to build their own logging utility; this is mine. The main nice feature is that you can log different categories of messages, and individually enable/disable output for each category by setting user defaults or command-line arguments. There's also a separate Warn() function that you can set a breakpoint on, which is itself a lifesaver during development.

### Test

My own somewhat oddball unit test system. I like being able to put unit tests in the same source file as the code they test. The tests run at launch time (if a command-line flag is set) not in a separate build phase. You can set dependencies between tests to get some control over the order in which they run. The output is IMHO easier to read than SenTest's.
