# Encrypt databases

This is an experimental feature, use with caution.

CDTDatastore is able to create encrypted databases. To do so, first edit your
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
- (NSData *)encryptionKey;
```

Alternatively, you can use the class
[CDTEncryptionKeychainProvider][CDTEncryptionKeychainProvider]. It already
implements this protocol which handles generating a strong key from a
user-provided password and stores it safely in the keychain. However, if you
decide to code your own class (and use this one as a reference), keep in mind
that if the method returns nil, the database won't be encrypted regardless of
the subspec defined in your `Podfile`.

To end, call `CDTDatastoreManager:datastoreNamed:withEncryptionKeyProvider:error:`
to create `CDTDatastores` with encrypted databases (datastores and indexes are
encrypted but not attachments and extensions)

[CDTEncryptionKeyProvider]: ../Classes/common/Encryption/CDTEncryptionKeyProvider.h
[CDTEncryptionKeychainProvider]: ../Classes/common/Encryption/Keychain/CDTEncryptionKeychainProvider.h
