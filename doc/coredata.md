## Using Core Data

> ***Warning***: This document assumes you are familiar with
> [Core Data].

From the [Apple documents][core data]:
>  The Core Data framework provides generalized and automated
>  solutions to common tasks associated with object life-cycle and
>  object graph management, including persistence.

It is this *"persistence"*, which is provided by the
[Persistent Store], that we wish to add `CDTDatastore` as a backing
store. The [Incremental Store] provides the hooks necessary to do
this.

Thankfully, the user does not need to know these details to exploit
`CDTDatastore` from an application that uses [Core Data].

### Example Application

There is an example application based on
[Apple's iPhoneCoreDataRecipes][recipe] and can be found in this
[git tree][gitrecipe].

### Getting started

A `CDTIncrementalStore` object is used to "link" everything
together. In order for [Core Data] to recognize
`CDTIncrementalStore` as a store, it must be initialized. This happens
automatically in OSX, but must be called manually in iOS, usually in
the `UIApplicationDelegate`, example:

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [CDTIncrementalStore initialize];
	...

```

> ***Note***: it is safe to call `+initialize` multiple times.

Then you may use [Core Data] as usual, however, now when you set up
your persistent store you request the `CDTIncrementalStore` in the
following manner, using `+type` static method to identify the correct
store type:

```objc
NSURL *storeURL = [NSURL URLWithString:databaseURI];
NSString *myType = [CDTIncrementalStore type];
NSPersistentStoreCoordinator *psc = ...
[psc addPersistentStoreWithType:myType
                  configuration:nil
                            URL:storeURL
                        options:nil
                          error:&error])];
```

The last component of `databaseURI` should be the name of your
database. If `databaseURI` has a host component, then that URL will be
used to specify the remote database where push, pull and sync
operations will target.

> ***Note***: the remote database details can be defined later in your
> code.

At this point you can use [Core Data] normally and your changes will
be saved in the local `CDTDatastore` image.

## Accessing your store object

At any time during your application you may decide to access the
remote `CDTDatastore`.  In order to do this from a [Core Data]
application, you need to access the `CDTIncrementalStore` object
instance you require.  Since [Core Data] can have multiple active
stores *and* even several `CDTIncrementalStore` objects, we can use
`+storesFromCoordinator:coordinator` to obtain these objects. If there
is only one `CDTIncrementalStore` object then this is simply:

```objc
// Get our stores
NSArray *stores = [CDTIncrementalStore storesFromCoordinator:psc];
// We know there is only one
CDTIncrementalStore *myIS = [stores firstObject];
```

If you have not already established the link when you added your
persistent store, you may do so by using `-linkReplicators:` and
`-linkReplicators`.

```objc
// link remote database
NSURL *linkURL = [NSURL URLWithString:databaseURI];
[myIS linkReplicators:linkURL];

// unlink current remote database
[myIS unlinkReplicators];
```

### Replication

The act of [replication] can be performed by the
`-pushToRemote:withProgress:` and
`-pullFromRemote:withProgress:`. These methods return immediately
reporting any initial error but do the actual work on another thread.
They employ [code blocks] to provide feedback to the application if
launched successfully.  Example use in iOS using `UIProgressView`:

```objc
NSError *err = nil;
UIProgressView * __weak weakProgress = // some UIProgressView object;
BOOL pull = [myIS pullFromRemote:&err
                    withProgress:^(BOOL end, NSInteger processed, NSInteger total, NSError *e) {
                        if (end) {
					        if (e) // ... deal with error
						    [weakProgress setProgress:1.0 animated:YES];
					    } else {
					        [weakProgress setProgress:(float)processed / (float)total animated:YES];
                        }
                    }];
if (!pull) // .. deal with error in `err`
```

> ***Note***: `withProgress` can be `nil`

Another example that just waits until the replicator is done:

```objc
NSError *err = nil;
NSError * __block pushErr = nil;
BOOL __block done = NO;
BOOL push = [is pushToRemote:&err withProgress:^(BOOL end, NSInteger processed, NSInteger total, NSError *e) {
    if (end) {
        if (e) pushErr = e;
        done = YES;
    } else {
        count = processed;
    }
}];

if (!push) // .. deal with error in `err`

while (!done) {
    [NSThread sleepForTimeInterval:1.0f];
}
```

Synchronization can be taken care of by some combination of push and
pull, see [replication] and [conflicts].

## Portability
Every effort is made to make resulting remote store as portable as
possible to other platforms and architectures.  To do this we try to
use more generic descriptions for the "meta" information.  Here we
describe some of the more difficult [Core Data] types.

### Time
The number of seconds from January 1, 1970 at 12:00 a.m. GMT.

### Binary Data
Binary data, where the programmer gives no indication of type is
described as "base64" and should be considered of mime-type
"application/octet-stream".

### Transformable Data
[Core Data] applications can provide a class that can transform an
object into some serialized form.  The name of this "Transformer
Class" and the mime-type is stored along with the base64 encoding of
the result.  The mime-type by default is "application/octet-stream".

To increase portability, it is recommended, where possible, that the
programmer add an additional class method called `+MIMEType` that
returns the mime-type of encoded result.  Example method for a class
that transforms to a PNG image.

```objc
+ (NSString *)MIMEType {
    return @"image/png";
}
```

### Arbitrary Decimal Numbers
The `NSDecimalNumber` is described by Apple as:
>  An instance can represent any number that can be expressed as
>  mantissa x 10^exponent where mantissa is a decimal integer up to 38
>  digits long, and exponent is an integer from –128 through 127.

This number is represented in the data-store as a string representation.
> ***Note***: unfortunately this means that you cannot really use this
> value for any predicate based fetches since proper comparison is
> currently impossible.

### Special Floating Point Values
The values `+/-infinity` and `NaN` cannot be expressed in a JSON based
store so they are tokenized accordingly.  In an effort to make
`+/-infinity` evaluated in your predicates, we give them a value of
`+/-MAX_FLT`. See the discussion on Doubles below.

### Double values
Depending on your JSON library, the string encoding and decoding of
doubles can lose some detail.

> ***Note***: This loss of detail may effect how your predicate
> evaluations work.

Regardless of this loss, it is important that the precise original
double value is restored for the [Core Data] objects.  In order to
deal with this inevitable corruption, we also store the IEEE 754
64-bit image as an integer number.

> ***Note***: Since we store the image as a number, there are ***no
> endian issues***.

<!-- refs -->

[core data]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreData/cdProgrammingGuide.html "Introduction to Core Data Programming Guide"

[persistent store]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreData/Articles/cdPersistentStores.html "Persistent Store Features"

[incremental store]: https://developer.apple.com/library/mac/documentation/DataManagement/Conceptual/IncrementalStorePG/Introduction/Introduction.html "About Incremental Stores"

[replication]: replication.md "Replicating Data Between Many Devices"
[conflicts]: conflicts.md "Handling conflicts"

[code blocks]: https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/WorkingwithBlocks/ "Working with Blocks"

[recipe]: https://developer.apple.com/library/ios/samplecode/iPhoneCoreDataRecipes/Introduction/Intro.html "iPhoneCoreDataRecipes"

[gitrecipe]: https://git.ibmbaas.com/jimix/iphonecoredatarecipes "Git Tree of iPhoneCoreDataRecipes"


<!--  LocalWords:  CDTDatastore CDTIncrementalStore OSX iOS objc BOOL
 -->
<!--  LocalWords:  UIApplicationDelegate UIApplication NSDictionary
 -->
<!--  LocalWords:  didFinishLaunchingWithOptions launchOptions NSURL
 -->
<!--  LocalWords:  storeURL URLWithString databaseURI NSString myType
 -->
<!--  LocalWords:  NSPersistentStoreCoordinator psc NSArray myIS md
 -->
<!--  LocalWords:  addPersistentStoreWithType storesFromCoordinator
 -->
<!--  LocalWords:  firstObject linkReplicators linkURL unlink NSError
 -->
<!--  LocalWords:  unlinkReplicators pushToRemote withProgress PNG
 -->
<!--  LocalWords:  pullFromRemote UIProgressView weakProgress pushErr
 -->
<!--  LocalWords:  NSInteger setProgress iPhoneCoreDataRecipes png
 -->
<!--  LocalWords:  gitrecipe NSThread MIMEType NSDecimalNumber NaN
 -->
<!--  LocalWords:  JSON tokenized IEEE endian
 -->
