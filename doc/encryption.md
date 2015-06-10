# Encrypt datastores

CDTDatastore is able to create encrypted datastores. To do so, first edit your
`Podfile` and replace:

```
pod "CDTDatastore"
```

With:

```
pod "CDTDatastore/SQLCipher"
```

Then, implement a class that conforms to protocol
[CDTEncryptionKeyProvider][CDTEncryptionKeyProvider]. This protocol only
defines one method:

```
- (CDTEncryptionKey *)encryptionKey;
```

See that the method returns a [CDTEncryptionKey][CDTEncryptionKey] instance. The
main purpose of this class is to ensure that the key has the right size
(256 bits).

Alternatively, you can use the class
[CDTEncryptionKeySimpleProvider][CDTEncryptionKeySimpleProvider]. This class
implements the protocol `CDTEncryptionKeyProvider` and  it is initialised with a
raw key of the size mentioned before. Its behaviour is quite simple: whenever
the method `CDTEncryptionKeyProvider:encryptionKey` is called, it returns the
key. However, in this case you are responsible for creating a strong key and
storing it safely. If you do not want to worry about this, you can use
[CDTEncryptionKeychainProvider][CDTEncryptionKeychainProvider]. This class
handles generating a strong key from a user-provided password and stores it
safely in the keychain.

If you finally decide to implement your own class, keep in mind that if
`CDTEncryptionKeyProvider:encryptionKey` returns nil, the datastore won't be
encrypted regardless of the subspec defined in your `Podfile`.

To end, call `CDTDatastoreManager:datastoreNamed:withEncryptionKeyProvider:error:`
to create encrypted datastores.

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
