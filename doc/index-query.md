## Finding documents within Cloudant Sync

Cloudant Sync provides simple and powerful ways to index and query
your documents, allowing your applications to make the most of the
data they store.

For those familiar with Cloudant, these indexes are closer to Cloudant's
Search feature than its Views feature. This is because they allow 
you to define indexes and execute ad hoc queries across those indexes.
It's important to note, however, that the indexing is _not_ based on
Lucene so lacks powerful full text search (though we're looking into 
that!).

Currently indexing and querying operate on full terms. That means that
if you index "Cloudant Sync", your query must be on "Cloudant Sync", that
is a precise match. We're working on improving this for free text
search scenarios and wildcard matching.

### Indexing

A datastore can have several indexes defined on it. Each index stores
a particular set of values for each document in the datastore and
allows fast look up of document IDs by those values (via a query).

The values that an index contains are specified by passing each document
through an _indexing function_, which take a document and return an
array of values. The returned array's values are indexed verbatim. Cloudant
Sync provides a number of prebuilt indexing functions or you can 
define your own, leading to powerful ways to index documents.

An index is typed to aid in querying. Currently there are two types:

- String, which allows queries for exactly matching values.
- Integer, which allows queries for matching values and values within a range.

#### Defining an index

The `CDTFieldIndexer` class allows indexing a document by a top-level
field (those existing at the root of the JSON document).

We'll use this document as our example:

```json
{
    "firstname": "John",
    "lastname": "Doe", 
    "age": 29
}
```

Indexes for a datastore are managed by the `CDTIndexManager` class. This
class allows creating, deleting and modifying indexes. You'd normally
create a single IndexManager object for each datastore. The `CDTIndexManager`
class is also used for queries. It's simple to create:

```objective-c
CDTIndexManager *indexManager = [[CDTIndexManager alloc]
                                 initWithDatastore:datastore error:nil];
```

To create an index on the `firstname` field using the `CDTFieldIndexer`,
we define the index using:

```objective-c
[indexManager ensureIndexedWithIndexName:@"default"
                               fieldName:@"firstname" error:nil];
```

The `ensureIndexedWithIndexName` method indexes all existing documents in the datastore
before returning, so for datastore with existing documents it may be 
run on a background thread.

The `ensureIndexedWithIndexName` function must be run every time a `CDTIndexManager` is
created so that the manager object recognises that index. The indexes 
themselves are persisted to disk and updated incrementally -- the 
`CDTIndexManager` just needs to be told about them at startup time.

`ensureIndexedWithIndexName:fieldName:error` is a convienience method to
create an index using a `CDTFieldIndexer` on the defined field that
is of type `CDTIndexTypeString`. A longer form is used for using your
own indexing functions, see below.

##### Deleting an Index

To remove the index we just created, ask the manager object to delete
the index:

```objective-c
[indexManager deleteIndexWithIndexName:@"default" error:nil];
```

##### Redefining an Index

To redefine an index, you need to delete and recreate the index:

```objective-c
// Before starting, "default" is a field index on "firstname"
[indexManager deleteIndexWithIndexName:@"default" error:nil];
[indexManager ensureIndexedWithIndexName:@"default"
                               fieldName:@"lastname" error:nil];
```

### Querying

Once one or more indexes have been created, you can query them using the `CDTIndexManager`
object. This is done by passing an `NSDictionary` containing the query to `queryWithDictionary:error`

Concretely:

```objective-c
// query on the "default" index:
CDTQueryResult *result = [indexManager queryWithDictionary:@{@"default": @"John"}
                                                     error:nil];
```

A query can use more than one index:

```objective-c
CDTQueryResult *result = [indexManager queryWithDictionary:@{@"default": @"John",
                                                             @"age": @{@"min": @26}}
                                                     error:nil];
```

The query result can then be iterated over to retrieve the documents:

```objective-c
for(CDTDocumentRevision *revision in result) {
    // do something
}
```

### Indexers

So far, we have described the `CDTFieldIndexer` for indexing top-level fields.

`CDTFieldIndexer` adopts the `CDTIndexer` protocol, which allows its instance to map a
document to the values that should be indexed for the document. The
`CDTIndexer` protocol defines a single method:

```objective-c
-(NSArray*)valuesForRevision:(CDTDocumentRevision*)revision
                   indexName:(NSString*)indexName;
```

For example, the included `CDTFieldIndexer` used earlier defines `valuesForRevision` as follows:

```objective-c
-(NSArray*)valuesForRevision:(CDTDocumentRevision*)revision
                   indexName:(NSString*)indexName;
{
    NSObject *value = [[[[revision td_rev] body] properties] valueForKey:_fieldName];
    // some type conversion omitted for clarity...
    return @[value];
}
```

The longer form of the `ensureIndexedWithIndexName` method allows you to provide
your own indexer, which is an instance of a class adopting the CDTIndexer protocol:

```objective-c
-(BOOL)ensureIndexedWithIndexName:(NSString*)indexName
                             type:(CDTIndexType)type
                          indexer:(NSObject<CDTIndexer>*)indexer
                            error:(NSError * __autoreleasing *)error;
```

For example, to use this long form to define the field index on `firstname`
used earlier:

```objective-c
CDTFieldIndexer *fi = [[CDTFieldIndexer alloc]
                       initWithFieldName:@"firstname" type:CDTIndexTypeString];
[indexManager ensureIndexedWithIndexName:@"default"
                                    type:CDTIndexTypeString indexer:fi error:nil];
```

As before, `ensureIndexedWithIndexName` must be called each time the `CDTIndexManager` object
is created, but of course the indexed values are persisted to disk, also
as you'd expect.

### Extended example

This example uses Cloudant Sync's indexing function to display
collection of documents, in this case songs from particular albums.

Assume all the songs are in the following format:

```json
{
    "name": "Life in Technicolor",
    "album": "Viva la Vida",
    "artist": "Coldplay",
    ...
}

{
    "name": "Viva la Vida",
    "album": "Viva la Vida",
    "artist": "Coldplay",
    ...
}


{
    "name": "Square One",
    "album": "X&Y",
    "artist": "Coldplay",
    ...
}

{
    "name": "What If",
    "album": "X&Y",
    "artist": "Coldplay",
    ...
}

```

First build the indexes on "album" and "artist" using the `CDTFieldIndexer`:


```objective-c
CDTIndexManager *indexManager = [[CDTIndexManager alloc]
                                 initWithDatastore:datastore error:nil];
[indexManager ensureIndexedWithIndexName:@"album" fieldName:@"album" error:nil];
[indexManager ensureIndexedWithIndexName:@"artist" fieldName:@"artist" error:nil];
```

Then you can get the songs from Viva la Vida:

```objective-c
CDTQueryResult *result = [indexManager queryWithDictionary:@{@"artist": @"Coldplay",
                                                             @"album": @"Viva la Vida"}
                                                     error:nil];
for(CDTDocumentRevision *revision in result) {
    NSLog([[[[revision td_rev] body] properties] valueForKey:@"name"]);
}

// prints:
//   Life in Technicolor
//   Viva la Vida
```

Note that `CDTFieldIndexer` doesn't transform the values, so queries
need to use the exact term and case (e.g., you can't use "coldplay" or
"cold").
