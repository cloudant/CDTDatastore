# Encrypt datastores

CDTDatastore is able to create encrypted datastores. 

## Step-by-step instructions

To do so, first edit your `Podfile` and replace:

```ruby
pod "CDTDatastore"
```

With:

```ruby
pod "CDTDatastore/SQLCipher"
```

This change will bring in the [SQLCipher][sqlcipher] library, which is used
to encrypted the SQLite databases used to store JSON and index data.

Once you've re-run `pod install`, you're able to create encrypted datastores.

To create an encrypted datastore, you initialise a datastore with a class
conforming to the [CDTEncryptionKeyProvider][CDTEncryptionKeyProvider]
protocol. We include conforming classes with the library (see below), or you can
implement your own if the included classes are unsuitable. The protocol
defines a single method:

```objc
- (CDTEncryptionKey *)encryptionKey;
```

This method should return a [CDTEncryptionKey][CDTEncryptionKey] instance. The
main purpose of the `CDTEncryptionKey` class is to ensure that the key has the 
right size (256 bits).

### CDTEncryptionKeyProviders included with the library

We include two classes conforming to `CDTEncryptionKeyProvider` with the library.

* [CDTEncryptionKeychainProvider][CDTEncryptionKeychainProvider]. This is the
  recommended key provider. It handles generating a strong, 256-bit key from a 
  user-provided password and stores it safely in the keychain, encrypted with
  a key generated from a provided password using PBKDF2.
* [CDTEncryptionKeySimpleProvider][CDTEncryptionKeySimpleProvider]. This class
  implements the protocol `CDTEncryptionKeyProvider` and  it is initialised with a
  raw key of 256-bits. Its behaviour is quite simple: whenever
  the method `CDTEncryptionKeyProvider:encryptionKey` is called, it returns the
  key. However, in this case you are responsible for creating a strong key and
  storing it safely. 

If you decide to implement your own class, keep in mind that if
`CDTEncryptionKeyProvider:encryptionKey` returns `nil`, the datastore won't be
encrypted regardless of the subspec defined in your `Podfile`.

Once you have a key provider, call 
`CDTDatastoreManager:datastoreNamed:withEncryptionKeyProvider:error:` to create encrypted 
datastores. Datastores created in this manner behave identically to unencrypted
datastores from the perspective of the API.

## Example code

Below is an example of creating an encrypted and unencrypted datastore using the encryption-enabled
podspec.

```objc
#import "AppDelegate.h"

#import <CloudantSync.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // Create a CDTDatastoreManager using application internal storage path
    NSError *error = nil;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"cloudant-sync-datastore"];
    NSString *path = [storeURL path];
    
    CDTDatastoreManager *manager =
    [[CDTDatastoreManager alloc] initWithDirectory:path
                                             error:&error];
    
    // To create an encrypted datastore, create your datastore using an object
    // implementing the CDTKeyProvider protocol
    CDTEncryptionKeychainProvider *provider = [CDTEncryptionKeychainProvider 
                                               providerWithPassword:@"blahblah" 
                                               forIdentifier:@"default"];
    CDTDatastore *encrypted = [manager datastoreNamed:@"encrypted_datastore"
                            withEncryptionKeyProvider:provider
                                                error:&error];
    
    // To create an *un*encrypted datastore, just leave out the CDTKeyProvider
    CDTDatastore *unencrypted = [manager datastoreNamed:@"unencrypted_datastore"
                                                  error:&error];
    
    // Use the encrypted store just the same as an unencrypted datastore
    CDTMutableDocumentRevision *rev = [CDTMutableDocumentRevision revision];
    rev.docId = @"doc1";  // Or don't and get an ID generated for you
    rev.body = @{@"description": @"Buy milk",
                 @"completed": @NO,
                 @"type": @"com.cloudant.sync.example.task"
                 };
    
    // Save the document to the database
    CDTDocumentRevision *revision = [encrypted createDocumentFromRevision:rev
                                                                    error:&error];
    
    // Read a document
    NSString *docId = revision.docId;
    CDTDocumentRevision *retrieved = [encrypted getDocumentWithId:docId
                                                            error:&error];
    
    NSLog(@"%@", retrieved);
    
    return YES;
}

@end
```

## Encryption details

Data in Cloudant Sync is stored in two formats:

1.	In SQLite databases, for JSON data and Query indexes.
2.	In binary blobs on disk, for document attachments.

Both of these are encrypted using AES in CBC mode. We currently only support 
using 256-bit keys. SQLite databases are encrypted using [SQLCipher][sqlcipher]. 
Attachment data is encrypted using Apple’s CommonCrypto library, built into iOS 
and OS X.

Our implementation is not currently FIPS 140-2 compliant.

## License

We use [Common Crypto][Common Crypto] library to encrypt the attachments before
saving to disk. Databases are automatically encrypted with
[SQLCipher][SQLCipher], this library requires to include its
[BSD-style license][BSD-style license] and copyright in your application and
documentation.

Thefore, if you use the subspec `CDTDatastore/SQLCipher`, please follow the
instructions mentioned [here](https://www.zetetic.net/sqlcipher/open-source/).

[SQLCipher]: https://www.zetetic.net/sqlcipher/
[Common Crypto]:https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man3/Common%20Crypto.3cc.html
[BSD-style license]:https://www.zetetic.net/sqlcipher/license/
[CDTEncryptionKey]: ../Classes/common/Encryption/CDTEncryptionKey.h
[CDTEncryptionKeyProvider]: ../Classes/common/Encryption/CDTEncryptionKeyProvider.h
[CDTEncryptionKeychainProvider]: ../Classes/common/Encryption/Keychain/CDTEncryptionKeychainProvider.h
[CDTEncryptionKeySimpleProvider]: ../Classes/common/Encryption/CDTEncryptionKeySimpleProvider.h
[sqlcipher]: https://www.zetetic.net/sqlcipher/
