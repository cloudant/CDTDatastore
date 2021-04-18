# CDTDatastore

CDTDatastore provides Cloudant Sync to store, index and query local JSON data on a device and to synchronise data between many devices. For more details about the CDTDatastore please refer to the [CDTDatastore docs](https://github.com/cloudant/CDTDatastore#cdtdatastore).


## Table of contents
* [Overview](#Overview)
* [Installation](#Installation)
* [File Protection](#File-Protection-Levels)
* [Usage](#Usage)
* [License](#License)

## Theraforge frameworks
* [OTFToolBox](https://github.com/HippocratesTech/StarDust)
* [OTFTemplateBox](https://github.com/HippocratesTech/MoonShine)
* [OTFCareKit](https://github.com/HippocratesTech/OTFCareKit)
* [OTFCloudantStore](https://github.com/HippocratesTech/OTFCloudantStore)
* [OTFCloudClientAPI](https://github.com/HippocratesTech/OTFCloudClientAPI)

## Overview
**The Theraforge CDTDatastore provides File protection for your application along with the basic cloudant CDTDatastore functionalities. The different types of file protection levels that you can apply on your files before starting and after finishing operations on the files.**

## Installation

Theraforge CDTDatastore is available through CocoaPods

TODO:  pod installation command

## File Protection Levels

There are different types of File protections available in iOS categorised by the key [NSFileProtectionType](https://developer.apple.com/documentation/foundation/nsfileprotectiontype). Using these file protections types in CDTDatastore framework Theraforge provides three types of Protection modes on the files that will help to set encryption with different behaviours. Setting any mode will ensure the file protection that you want to apply on your files before starting and after finishing any operation on the files. 

* mode1 - In this mode application is guaranteed to complete synchronization within 10 seconds. After 10 seconds application will not be able to access the files in the background.

* mode2 - In this mode application needs 20 seconds time for the synchronization. After 20 seconds application will not be able to access the files in the background.

* background - In this mode application need to periodically run in the background. It will give 30 seconds time frame to finish any operation in the background. After 30 seconds application will not be able to access the files.

## Usage
To access OTF protection levels in your existing application install [Theraforge CDTDatastore](#Installation) and then use below functions with the help of CDTDatastore object.


```
/// Call encryption function with the help of datastore object in OBJECTIVE C
# -(void)setProtectionLevel: (OTFProtectionLevel)level;'

/// Replace mode1 with any other available mode.
# [datastore setProtectionLevel: mode1];
```


```
/// Call encryption function with the help of datastore object in SWIFT -
# dataStore.setProtectionLevel(.level)

```

## License
TODO:  License
