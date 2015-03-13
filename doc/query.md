# Finding documents with Cloudant Sync

This query engine is inspired by MongoDB's query implementation, so users of MongoDB should feel
at home using it in their mobile applications.

The aim is that the query you use on our cloud-based database works for your mobile application.

This query engine is meant to replace our previous [indexing/query][1] solution which will be removed from this project repository shortly.  The functionality provided by this query engine already exceeds that of the previous solution.
  

[1]: https://github.com/cloudant/CDTDatastore/blob/master/doc/index-query.md

## Usage


This query engine uses indexes explicitly defined over the fields in the document. Multiple
indexes can be created for use in different queries, the same field may end up indexed in
more than one index.

Querying is carried out by supplying a query in the form of a dictionary which describes the
query.

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
   @"pet": @{@"species": @"cat"} };

@{ @"name": @"mike", 
   @"age": @34, 
   @"pet": @{@"species": @"dog"} };

@{ @"name": @"fred", 
   @"age": @23, 
   @"pet": @{@"species": @"cat"} };
```

### Headers

You need to include `CDTDatastore+Query.h`:

```objc
#import "CDTDatastore+Query.h"
```

### The CDTDatastore+Query Category 

The `CDTDatastore+Query` category adds the ability to manage query indexes and execute queries directly on the `CDTDatastore` object.

### Creating indexes

In order to query documents, indexes need to be created over
the fields to be queried against.

Use `-ensureIndexed:withName:` to create indexes. These indexes are persistent
across application restarts as they are saved to disk. They are kept up to date
documents change; there's no need to call `-ensureIndexed:withName:` each
time your applications starts, though there is no harm in doing so.

The first argument to `-ensureIndexed:withName:` is a list of fields to
put into this index. The second argument is a name for the index. This is used
to delete indexes at a later stage and appears when you list the indexes
in the database.

A field can appear in more than one index. The query engine will select an
appropriate index to use for a given query. However, the more indexes you have,
the more disk space they will use and the greater overhead in keeping them
up to date.

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

`-ensureIndexed:withName:` returns the name of the index if it is successful,
otherwise it returns `nil`.

If an index needs to be changed, first delete the existing index, then call 
`-ensureIndexed:withName:` with the new definition.

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

Selectors -> Condition -> Array

- `$in`
- `$nin`

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

Selectors -> Condition -> Array

- `$size`

Selectors -> Condition -> Misc

- `$mod`
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

To help, I've tried to write a grammar/schema for the Query language.

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
    <strong>{</strong> &quot;$mod&quot; <strong>:</strong> <strong>[</strong> <em>divisor, remainder</em> <strong>] }</strong>  // not implemented
    <strong>{</strong> &quot;$elemMatch&quot; <strong>: {</strong> <em>many-expressions</em> <strong>} }</strong>  // not implemented
    <strong>{</strong> &quot;$size&quot; <strong>:</strong> <em>positive-integer</em> <strong>}</strong>  // not implemented
    <strong>{</strong> &quot;$all&quot; <strong>:</strong> <em>array-value</em> <strong>}</strong>  // not implemented
    <strong>{</strong> &quot;$in&quot; <strong>:</strong> <em>array-value</em> <strong>}</strong>
    <strong>{</strong> &quot;$nin&quot; <strong>:</strong> <em>array-value</em> <strong>}</strong>
    <strong>{</strong> &quot;$exists&quot; <strong>:</strong> <em>boolean</em> <strong>}</strong>
    <strong>{</strong> &quot;$type&quot; <strong>:</strong> <em>type</em> <strong>}</strong>  // not implemented

<em>operator</em> := &quot;$gt&quot; | &quot;$gte&quot; | &quot;$lt&quot; | &quot;$lte&quot; | &quot;$eq&quot; | &quot;$ne&quot;

// Obviously NSArray, but easier to express like this
<em>array-value</em> := <strong>[</strong> simple-value (&quot;,&quot; simple-value)+ <strong>]</strong>

// Objective-C mappings of basic types

<em>field</em> := <em>NSString</em>  // a field name

<em>simple-value</em> := <em>NSString</em> | <em>NSNumber</em>

<em>positive-integer</em> := <em>NSNumber</em>

<em>boolean</em> := <em>NSNumber (boxed BOOL)</em>

<em>type</em> := <em>Class</em>
</pre>

