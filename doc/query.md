# Finding documents with Cloudant Sync

Cloudant Query is inspired by MongoDB's query implementation, so users of MongoDB should feel
at home using it in their mobile applications.

The aim is that the query you use on our cloud-based database works
for your mobile application.

## Usage

These notes assume familiarity with Cloudant Sync Datastore.

This query engine uses indexes explicitly defined over the fields in the document. Multiple
indexes can be created for use in different queries, the same field may end up indexed in
more than one index.

Query offers a powerful way to find documents within your datastore. There are a couple of restrictions on field names you need to be aware of before using query:

- A dollar sign (`$`) cannot be the first character of any field name.  This is because, when querying, a dollar sign tells the query engine to handle the object as a query operator and not a field.
- A field with a name that contains a period (`.`) cannot be indexed nor successfully queried.  This is because the query engine assumes dot notation refers to a sub-object.

These come from Query's MongoDB heritage where these characters are not allowed in field names, which we don't share. Hopefully we'll work around these restrictions in the future.

Querying is carried out by supplying a query in the form of a 
dictionary which describes the query.

For the following examples, assume two things.

Firstly, we set up a `CDTDatastore` object, `ds`, as follows:

```objc
#import <CloudantSync.h>

NSError *outError = nil;
NSString *path = /* a path within your app's file hierarchy */;

CDTDatastoreManager *manager =
[[CDTDatastoreManager alloc] initWithDirectory:path
                                         error:&outError];

CDTDatastore *ds = [manager datastoreNamed:@"my_datastore"
                                     error:&outError];
```

Secondly, these documents are in the datastore:

```objc
@{ @"name": @"mike", 
   @"age": @12, 
   @"pet": @{@"species": @"cat"},
   @"comment": @"Mike goes to middle school and likes reading books." };

@{ @"name": @"mike", 
   @"age": @34, 
   @"pet": @{@"species": @"dog"},
   @"comment": @"Mike is a doctor and likes reading books." };

@{ @"name": @"fred", 
   @"age": @23, 
   @"pet": @{@"species": @"cat"},
   @"comment": @"Fred works for a startup out of his home office." };
```

### Headers

By including `CloudantSync.h` you get full query capabilities:

```objc
#import <CloudantSync.h>
```

### The CDTDatastore+Query Category 

The `CDTDatastore+Query` category adds the ability to manage query indexes and execute queries directly on the `CDTDatastore` object.

### Creating indexes

In order to query documents, creating indexes over
the fields to be queried against will typically enhance query 
performance.  Currently we support two types of indexes.  The 
first, a JSON index, is used by query clauses containing 
comparison operators like `$eq`, `$lt`, and `$gt`.  Query clauses 
containing these operators are based on standard SQLite indexes to 
provide query results.  The second, a TEXT index, uses SQLite's 
full text search (FTS) engine.  A query clause containing a 
`$text` operator with a `$search` operator uses 
[SQLite FTS SQL syntax][ftsHome] along with a TEXT index to 
provide query results.

Basic querying of fields benefits but does _not require_ a JSON 
index. For example, `@{ @"name" : @{ @"$eq" : @"mike" } }` would 
benefit from a JSON index on the `name` field but would succeed 
even if there isn't an index on `name`. Text queries, by contrast, 
_require_ an index. Therefore `@{ @"$text" : @{ @"$search" : @"doctor books" } }` would need a TEXT index on the `comment` 
field (based on the content of the above documents).  A TEXT index 
is used to perform term searches, phrase searches and prefix 
searches (starts with... queries). Querying capabilities and 
syntax are covered later in this document.

[ftsHome]: http://www.sqlite.org/fts3.html#section_3

Use the following methods to create a JSON index:

```objc
-(NSString *)ensureIndexed:(NSArray *)fieldNames 
                  withName:(NSString *)indexName
```

Use either of the following methods to create a TEXT index:

```objc
-(NSString *)ensureIndexed:(NSArray *)fieldNames
                  withName:(NSString *)indexName
                      type:(NSString *)type

// or 

-(NSString *)ensureIndexed:(NSArray *)fieldNames
                  withName:(NSString *)indexName
                      type:(NSString *)type
                  settings:(NSDictionary *)indexSettings
```

These indexes are persistent across application restarts as they 
are saved to disk. They are kept up to date as documents change; 
there's no need to call the `-ensureIndexed:...` method each time 
your applications starts, though there is no harm in doing so.

The first argument, `fieldNames`, is an array of fields to put into 
the index. The second argument, `indexName`, is a name for the 
index. This is used to delete indexes at a later stage and appears 
when you list the indexes in the database.  The third argument, 
`type`, defines what type of index to create.  Valid index 
types are `json` and `text`.  If not provided, the index type 
defaults to `json`.  The fourth argument, `indexSettings`, is 
comprised of index parameters and their values.  Currently the 
only valid index setting is `tokenize` and it can only apply to a 
TEXT index.  If index settings are not provided for a TEXT index, 
the `tokenize` parameter defaults to the value `simple`.

A field can appear in more than one index. The query engine will 
select an appropriate index to use for a given query. However, the 
more indexes you have, the more disk space they will use and the 
greater the overhead in keeping them up to date.

To index values in sub-documents, use _dotted notation_. This notation puts
the field names in the path to a particular value into a single string,
separated by dots. Therefore, to index the `species`
field of the `pet` sub-document in the examples above, use `pet.species`.

```objc
// Create an index over the name and age fields.
NSString *name = [ds ensureIndexed:@[@"name", @"age", @"pet.species"] 
                          withName:@"basic"]
if (!name) {
    // there was an error creating the index
}
```

#### Indexing for text search

Since text search relies on SQLite FTS, which is a compile time option, we must ensure that SQLite FTS is available.  To verify that text search is enabled and that a text index can be created use `-isTextSearchEnabled` before attempting to create a text index.  If text search is not enabled see [compiling and enabling SQLite FTS][enableFTS] for details. 

[enableFTS]: http://www.sqlite.org/fts3.html#section_2

```objc
if ([ds isTextSearchEnabled]) {
    // Create a text index over the name and comment fields.
    NSString *name = [ds ensureIndexed:@[@"name", @"comment"]
                              withName:@"basic_text_index"
                                  type:@"text"];
    if (name == nil) {
        // there was an error creating the index
    }
}
```

Because text indexing relies on SQLite FTS functionality, any custom tokenizers need to be managed through SQLite.  SQLite comes standard with the "simple" default tokenizer as well as a Porter stemming algorithm tokenizer ("porter").  Please refer to [SQLite FTS tokenizers][fts] for additional information on custom tokenizers.

[fts]: http://www.sqlite.org/fts3.html#tokenizer  

When creating a text index, overriding the default tokenizer setting is done by providing a `tokenize` parameter setting as part of the index settings.  The value should be the same as the tokenizer name given to SQLite when registering that tokenizer.  In the example below we set the tokenizer to `porter`.

```objc
if ([ds isTextSearchEnabled]) {
    Map<String, String> settings = new HashMap<String, String>();
    settings.add("tokenize", "porter");
    // Create a text index over the name and comment fields.
    // Setting the tokenizer to "porter".
    NSString *name = [ds ensureIndexed:@[@"name", @"comment"]
                              withName:@"basic_text_index"
                                  type:@"text"
                              settings:@{@"tokenize": @"porter"}];
    if (name == null) {
        // there was an error creating the index
    }
}
```

The `-ensureIndexed:...` methods returns the name of the index if 
it is successful, otherwise they returns `nil`.

##### Restrictions

- There is a limit of one text index per datastore.
- Text indexes cannot be created on field names containing an `=` 
sign. This is due to restrictions imposed by SQLite's virtual table syntax.

#### Viewing index definitions

Use `-listIndexes` to retrieve a dictionary containing all of the query indexes in a datastore.  The key to the dictionary is the index name.

The format of the dictionary returned by `-listindexes` is:

```objc
@{ @"jsonIdxName": @{ @"fields": @[ @"field1", @"field2" ],
                      @"type": @"json",
                      @"name": @"jsonIdxName" },
   
   @"textIdxName": @{ @"fields": @[ @"field1", @"field2" ],
                      @"type": @"text",
                      @"name": @"textIdxName",
                      @"settings": @"{tokenize: simple}"  },
       ...
 }
```

Note:  `settings` are returned as a JSON string.

#### Changing and removing indexes

If an index needs to be changed, first delete the existing index 
by calling `-deleteIndexNamed:` and provide the index name of the index to be deleted, then call the appropriate 
`-ensureIndexed:...` method with the new definition.

#### Indexing document metadata (_id and _rev)

The document ID and revision ID are automatically indexed under `_id` and `_rev` 
respectively. If you need to query on document ID or document revision ID,
use these field names.

#### Indexing array fields

Indexing of array fields is supported. See "Array fields" below for the indexing and
querying semantics.

### Querying syntax

Query documents using `NSDictionary` objects. These use the [Cloudant Query `selector`][sel]
syntax. Several features of Cloudant Query are not yet supported in this implementation.
See below for more details.

[sel]: https://docs.cloudant.com/api/cloudant-query.html#selector-syntax

#### Equality and comparisons

To query for all documents where `pet.species` is `cat`:

```objc
@{ @"pet.species": @"cat" };
```

If you don't specify a condition for the clause, equality (`$eq`) is used. To use
other conditions, supply them explicitly in the clause.

To query for documents where `age` is greater than twelve use the `$gt` condition:

```objc
@{ @"age": @{ @"$gt": @12 } };
```

See below for supported operators (Selections -> Conditions).

#### Modulo operation in queries

Using the `$mod` operator in queries allows you to select documents based on the value of a field divided by an integer yielding a specific remainder.

To query for documents where `age` divided by 5 has a remainder of  4, do the following:

```objc
@{ @"age": @{ @"$mod": [ @5, @4 ] } }
```

A few things to keep in mind when using `$mod` are:

- The array argument to the `$mod` operator must contain two number elements. The first element is the divisor and the second element is the remainder.
- Division by zero is not allowed so the divisor cannot be zero.
- The dividend (field value), divisor, and the remainder can be positive or negative.
- The dividend, divisor, and the remainder can be represented as whole numbers or by using decimal notation.  However internally, prior to performing the modulo arithmetic operation, all three are truncated to their logical whole number representations.  So, for example, the query `@{ @"age": @{ @"$mod": [ @5.6, @4.2 ] } }` will provide the same result as the query `@{ @"age": @{ @"$mod": [ @5, @4 ] } }`.

#### Text search

After creating a text index, a text clause may be used as part of 
a query to perform full text search term matching, phrase 
matching, and prefix matching.  A text clause can stand on its own 
as a query or can be part of a compound query (see below).  Text 
search supports either SQLite [Standard Query Syntax][ftsStandard] 
or [Enhanced Query Syntax][ftsEnhanced].  This is dependent on 
which syntax is enabled as part of SQLite FTS.  Typically SQLite 
FTS on iOS comes configured with the SQLite Enhanced Query Syntax 
(confirmed during testing on iOS 7.1, 8.1, 8.2 and 8.3).  See [SQLite 
full text query][ftsQuery] for more details on syntax that is 
possible with text search.

[ftsQuery]: http://www.sqlite.org/fts3.html#section_3
[ftsStandard]: http://www.sqlite.org/fts3.html#section_3_1
[ftsEnhanced]: http://www.sqlite.org/fts3.html#section_3_2

##### Restrictions

- Only one text clause per query is permitted.
- All clauses in a query must be satisfied by an index if that query contains a text search clause.
- Both tokenizers, `simple` and `porter`, that come with text search by default are case-insensitive.

To find documents that include all of the terms in `doctor books` use:

```objc         
NSDictionary *query = @{@"$text": @{@"$search": @"doctor books" }};
```

This query will match the following document because both `doctor` and `books` are found in its comment field.

```objc
@{ @"name": @"mike", 
   @"age": @34, 
   @"pet": @{@"species": @"dog"},
   @"comment": @"Mike is a doctor and likes reading books." };
```

To find documents that include the phrase `is a doctor` use:

```objc  
NSDictionary *query = @{@"$text": @{@"$search": @"\"is a doctor\"" }};
```

This query will match the following document because the phrase `is a doctor` is found in its comment field.

```objc
@{ @"name": @"mike", 
   @"age": @34, 
   @"pet": @{@"species": @"dog"},
   @"comment": @"Mike is a doctor and likes reading books." };
```

To find documents that include the prefix `doc` use:

```objc              
NSDictionary *query = @{@"$text": @{@"$search": @"doc*" }};
```

This query will match the following document because the prefix `doc` followed by the `*` wildcard matches `doctor` found in its comment field.

```objc
@{ @"name": @"mike", 
   @"age": @34, 
   @"pet": @{@"species": @"dog"},
   @"comment": @"Mike is a doctor and likes reading books." };
```

These examples are a small sample of what can be done using text search.  Take a look at the [SQLite full text query][ftsQuery] documentation for more details.

#### Compound queries

Compound queries allow selection of documents based on more than one criteria.
If you specify several clauses, they are implicitly joined by AND.

To find all people named `fred` with a `cat` use:

```objc
@{ @"name": @"fred", @"pet.species": @"cat" };
```

##### Using OR to join clauses

Use `$or` to find documents where just one of the clauses match.

To find all people with a `dog` who are under thirty:

```objc
@{ @"$or": @[ @{ @"pet.species": @{ @"$eq": @"dog" } }, 
              @{ @"age": @{ @"$lt": @30 } }
            ]};
```

#### Using AND and OR in queries

Using a combination of AND and OR allows the specification of complex queries.

This selects documents where _either_ the person has a pet `dog` _or_ they are
both over thirty _and_ named `mike`:

```objc
@{ @"$or": @[ @{ @"pet.species": @{ @"$eq": @"dog" } }, 
              @{ @"$and": @[ @{ @"age": @{ @"$gt": @30 } },
                             @{ @"name": @{ @"$eq": @"mike" } }
                          ] }
            ]};
```

### Executing queries

To find documents matching a query, use the `CDTQIndexManager` objects `-find:`
function. Use the returned object's `-enumerateObjectsUsingBlock:` method to iterate
over the results:

```objc
CDTQResultSet *result = [ds find:query];
[result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop) {
    // The returned revision object contains all fields for
    // the object. You cannot project certain fields in the
    // current implementation.
    //
    // rev: the result revision.
    // idx: the index of this result.
    // stop: set to YES to stop the iteration.
}];
```

There is an extended version of the `-find:` method which supports:

- Sorting results.
- Projecting fields from documents rather than returning whole documents.
- Skipping results.
- Limiting the number of results returned.

For any of these, use 

#### Sorting

Provide a sort document to `-find:skip:limit:fields:sort:` to sort the results of a query. 

The sort document is an array of fields to sort by. Each field is represented by a 
dictionary specifying the name of the field to sort by and the direction to sort.

The sort document must use fields from a single index.

As yet, you can't leave out the sort direction. The sort direction can be `asc` (ascending)
or `desc` (descending).

```objc
NSArray *sortDocument = @[ @{ @"name": @"asc" }, 
                           @{ @"age": @"desc" } ];
CDTQResultSet *result = [ds find:query
                            skip:0
                           limit:0
                          fields:nil
                            sort:sortDocument];
```

Pass `nil` as the `sort` argument to disable sorting.

#### Projecting fields

Projecting fields is useful when you have a large document and only need to use a
subset of the fields for a given view.

To project certain fields from the documents included in the results, pass an
array of field names to the `fields` argument. These field names must:

- Be top level fields in the document.
- Cannot use dotted notation to access sub-documents.

For example, in the following document the `name`, `age` and `pet` fields could
be projected, but the `species` field inside `pet` cannot:

```json
{
    "name": "mike",
    "age": 12,
    "pet": { "species": "cat" }
}
```

To project the `name` and `age` fields of the above document:

```objc
NSArray *fields = @[ @"name", @"age" ];
CDTQResultSet *result = [ds find:query
                            skip:0
                           limit:0
                          fields:fields
                            sort:nil];
```

Pass `nil` as the `fields` argument to disable projection.

#### Skip and limit

Skip and limit allow retrieving subsets of the results. Amongst other things, this is
useful in pagination.

* `skip` skips over a number of results from the result set.
* `limit` defines the maximum number of results to return for the query.

To display the twenty-first to thirtieth results:

```objc
CDTQResultSet *result = [ds find:query
                            skip:20
                           limit:10
                          fields:fields
                            sort:nil];
```

To disable:

- `skip`, pass `0` as the `skip` argument.
- `limit`, pass `0` as the `limit` argument.

### Array fields

Indexing and querying over array fields is supported by this query engine, with some
caveats.

Take this document as an example:

```
{
  _id: mike32
  pet: [ cat, dog, parrot ],
  name: mike,
  age: 32
}
```

You can create an index over the `pet` field:

```objc
NSString *name = [ds ensureIndexed:@[@"name", @"age", @"pet"] 
                          withName:@"basic"]
```

Each value of the array is treated as a separate entry in the index. This means that
a query such as:

```
{ pet: { $eq: cat } }
```

Will return the document `mike32`. Negation such as:

```
{ pet: { $not: { $eq: cat } } }
```

Will not return `mike32` because negation returns the set of documents that are not in the set of documents returned by the non-negated query. In other words the negated query above will return all of the documents that are not in the set of documents returned by `{ pet: { $eq: cat } }`.

#### Restrictions

Only one field in a given index may be an array. This is because each entry in each array
requires an entry in the index, causing a Cartesian explosion in index size. Taking the
above example, this document wouldn't be indexed because the `name` and `pet` fields are
both indexed in a single index:


```
{
  _id: mike32
  pet: [ cat, dog, parrot ],
  name: [ mike, rhodes ],
  age: 32
}
```

If this happens, an error will be emitted into the log but the indexing process will be
successful.

However, if there was one index with `pet` in and another with `name` in, like this:

```objc
NSString *name = [ds ensureIndexed:@[@"name", @"age"] 
                          withName:@"one_index"];
NSString *name = [ds ensureIndexed:@[@"age", @"pet"] 
                          withName:@"another_index"]
```

The document _would_ be indexed in both of these indexes: each index only contains one of
the array fields.

Also see "Unsupported features", below.


### Errors

Error reporting is terrible right now. The only indication something went wrong is a
`nil` return value from `-find:` or `-ensureIndexed:withName:`. We're working on
adding logging.

## Supported features

Right now the list of supported features is:

- Create compound indexes using dotted notation that index JSON fields.
- Delete index by name.
- Execute nested queries.
- Limiting returned results.
- Skipping results.
- Queries can include unindexed fields.
- Queries can include a text search clause, although if they do no unindexed fields may be used.
      
Selectors -> combination

- `$and`
- `$or`

Selectors -> Conditions -> Equalities

- `$lt`
- `$lte`
- `$eq`
- `$gte`
- `$gt`
- `$ne`

Selectors -> combination

- `$not`

Selectors -> Condition -> Objects

- `$exists`

Selectors -> Condition -> Misc

- `$text` in combination with `$search`
- `$mod`

Selectors -> Condition -> Array

- `$in`
- `$nin`
- `$size`

Implicit operators

- Implicit `$and`.
- Implicit `$eq`.

Arrays

- Indexing individual values in an array.
- Querying for individual values in an array.

## Unsupported features

Some features are not supported yet. We're actively working to support features -- check the commit log :)

### Query

Overall restrictions:

- Cannot use covering indexes with projection (`fields`) to avoid loading 
  documents from the datastore.

#### Query syntax

- Using non-dotted notation to query sub-documents.
    - That is, `{"pet": { "species": {"$eq": "cat"} } }` is unsupported,
      you must use `{"pet.species": {"$eq": "cat"}}`.
- Cannot use multiple conditions in a single clause, `{ field: { $gt: 7, $lt: 14 } }`.

Selectors -> combination

- `$nor`
- `$all`
- `$elemMatch`

Selectors -> Condition -> Objects

- `$type`

Selectors -> Condition -> Misc

- `$regex`


Arrays

- Dotted notation to index or query sub-documents in arrays.
- Querying for exact array match, `{ field: [ 1, 3, 7 ] }`.
- Querying to match a specific array element using dotted notation, `{ field.0: 1 }`.
- Querying using `$all`.
- Querying using `$elemMatch`.


## Performance

### Indexing

These were run on an iPhone 5 on commit c9bd52102fab8a8906b5fd8fe89f1f0f87568ef6, 2014-10-21.

The documents were simple, of the form:

```json
{ 
    "name": "mike", 
    "age": 34, 
    "docNumber": 0, 
    "pet": "cat" 
}
```

The one-index was over the `name` field, the three-index over `name`, `age` and `pet`.

| Number of documents  | Number of fields  | Indexing time (seconds) |
| ------------:|---------------:| -----:|
| 1,000      | 1 | 0.8s |
| 1,000      | 3 | 0.8s |
| 10,000      | 1 | 6.9s |
| 10,000      | 3 | 7.6s |
| 50,000      | 1 | 56.2s |
| 50,000      | 3 | 60.7s |
| 100,000      | 1 | 169.2s |
| 100,000      | 3 | 179.9s |


## Grammar

To help, Below is a grammar/schema for the Query language.

Here:

* Bold is used for the JSON formatting (or to indicate use of NSDictionary, NSArray etc. in objc).
* Italic is variables in the grammar-like thing.
* Quotes enclose literal string values.

<pre>
<em>query</em> := 
    <strong>{ }</strong>
    <strong>{</strong> <em>many-expressions</em> <strong>}</strong>

<em>many-expressions</em> := <em>expression</em> (&quot;,&quot; <em>expression</em>)*

<em>expression</em> := 
    <em>compound-expression</em>
    <em>comparison-expression</em>
    <em>text-search-expression</em>

<em>compound-expression</em> := 
    <strong>{</strong> (&quot;$and&quot; | &quot;$nor&quot; | &quot;$or&quot;) <strong>:</strong> <strong>[</strong> <em>many-expressions</em> <strong>] }</strong>  // nor not implemented
    
<em>comparison-expression</em> :=
    <strong>{</strong> <em>field</em> <strong>:</strong> <strong>{</strong> <em>operator-expression</em> <strong>} }</strong>

<em>negation-expression</em> := 
    <strong>{</strong> &quot;$not&quot; <strong>:</strong> <strong>{</strong> <em>operator-expression</em> <strong>} }</strong>

<em>operator-expression</em> := 
    <em>negation-expression</em>
    <strong>{</strong> <em>operator</em> <strong>:</strong> <em>simple-value</em> <strong>}</strong>
    <strong>{</strong> &quot;$regex&quot; <strong>:</strong> <em>NSRegularExpression</em> <strong>}</strong>  // not implemented
    <strong>{</strong> &quot;$mod&quot; <strong>:</strong> <strong>[</strong> <em>non-zero-number, number</em> <strong>] }</strong>
    <strong>{</strong> &quot;$elemMatch&quot; <strong>: {</strong> <em>many-expressions</em> <strong>} }</strong>  // not implemented
    <strong>{</strong> &quot;$size&quot; <strong>:</strong> <em>positive-integer</em> <strong>}</strong>
    <strong>{</strong> &quot;$all&quot; <strong>:</strong> <em>array-value</em> <strong>}</strong>  // not implemented
    <strong>{</strong> &quot;$in&quot; <strong>:</strong> <em>array-value</em> <strong>}</strong>
    <strong>{</strong> &quot;$nin&quot; <strong>:</strong> <em>array-value</em> <strong>}</strong>
    <strong>{</strong> &quot;$exists&quot; <strong>:</strong> <em>boolean</em> <strong>}</strong>
    <strong>{</strong> &quot;$type&quot; <strong>:</strong> <em>type</em> <strong>}</strong>  // not implemented

<em>text-search-expression</em> :=     
    <strong>{</strong> &quot;$text&quot; <strong>:</strong><strong> {</strong> &quot;$search&quot; <strong>:</strong> <em>string-value</em> <strong>}</strong> <strong>}</strong>

<em>operator</em> := &quot;$gt&quot; | &quot;$gte&quot; | &quot;$lt&quot; | &quot;$lte&quot; | &quot;$eq&quot; | &quot;$ne&quot;

// Obviously NSArray, but easier to express like this
<em>array-value</em> := <strong>[</strong> simple-value (&quot;,&quot; simple-value)+ <strong>]</strong>

// Objective-C mappings of basic types

<em>field</em> := <em>NSString</em>  // a field name

<em>simple-value</em> := <em>NSString</em> | <em>NSNumber</em>

<em>string-value</em> := <em>NSString</em>

<em>number</em> := <em>NSNumber</em>

<em>non-zero-number</em> := <em>NSNumber</em>

<em>positive-integer</em> := <em>NSNumber</em>

<em>boolean</em> := <em>NSNumber (boxed BOOL)</em>

<em>type</em> := <em>Class</em>
</pre>

