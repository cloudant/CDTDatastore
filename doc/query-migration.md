# Migrate from legacy indexing to Cloudant Query

Our original indexing-query solution has now been replaced by [Cloudant Query - iOS][1].  The content within details the differences between the two query implementations and how an existing user of the legacy indexing-query solution can migrate to using the new Cloudant Query implementation.

[1]: https://github.com/cloudant/CDTDatastore/blob/master/doc/query.md

## Differences

For users of the legacy indexing-query solution it is first important to understand the differences between the new and old versions of Query in order to understand the proper path to take with regards to migration.

### Index Management

- The first major difference is that the `CDTDatastore+Query` category adds the ability to manage query indexes and execute queries directly on the `CDTDatastore` object.  So you no longer need to create an instance of an Index Manager.
- `-ensureIndexedWithIndexName:fieldName:error:` has been replaced by `-ensureIndexed:withName:`.
- It is also no longer necessary to invoke `-ensureIndexed:withName:` each time a new instance of the `IndexManager` is created.  Although there is no harm in doing so.  Indexes now are persistent across application restarts.  So they need to only be created one time in order to be used by queries.
- The signature of `-ensureIndexed:withName:` is also slightly different, in that now to create an index on a field or fields you would simply pass an `NSArray` of field(s) rather than an individual field name.
- The notion of index functions no longer exists.
- Another minor difference but one worth noting is that the `-ensureIndexed:withName:` argument order has been flipped.  So now field names are the first argument and index name is the second.
- The processes for deleting and re-defining an index are largely unchanged.

So in the past for indexes created like this:

```objc
CDTIndexManager *indexManager = [[CDTIndexManager alloc]
                                 initWithDatastore:datastore error:nil];
[indexManager ensureIndexedWithIndexName:@"default"
                               fieldName:@"name" error:nil];
[indexManager ensureIndexedWithIndexName:@"age"
                               fieldName:@"age" error:nil];
```

You could now create a single index like this:

```objc
NSString *idx = [datastore ensureIndexed:@[@"name", @"age"] withName:@"default"];
```

Creating multiple indexes is obviously still possible.

### Querying

We have taken the lead from both [Cloudant Query][2] and [MongoDB Query][3] with regards to how we handle querying in this mobile implementation of Cloudant Query.  As with indexing, querying is done using the `CDTDatastore` object.

- Instead of using `-queryWithDictionary:error:` you now use the `-find:` function.
- The result set from a query now is represented by a `CDTQResultSet` object.
- Operators such as `$eq`, `$lt`, `$gt`, etc. are now used to define conditions within the query as you would in [Cloudant Query][2] or [MongoDB Query][3].
- When writing your query it is no longer necessary to specify the index(es) that the query must use to process its results.  The new Query engine will find the appropriate index(es) for your query if they exist.  In the case where index(es) do not exist the Query engine will process the results programmatically albeit in a much slower manner.

So in the past for a query defined like this (looking for name = "mike"):

```objc
// query on the "default" index:
CDTQueryResult *result = [indexManager queryWithDictionary:@{@"default": @"mike"}
                                                     error:nil];
```

You would now define it like this:

```objc
// query engine finds appropriate index or handles query as necessary
CDTQResultSet *result = [datastore find:@{@"name" : @"mike"} ];
```


- Iterating over documents returned as part of a query result can now be done through the returned object's `-enumerateObjectsUsingBlock:` function.

So executing a query changes from:

```objc
for(CDTDocumentRevision *revision in result) {
    // do something
};
```

To:

```objc
[result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop) {
    // do something
}];
```

- Query options like `offset`, `limit`, and `sort` are now handled by `-find:skip:limit:fields:sort:`.  `offset` is now known as `skip` and a new query option to perform field projection is now also available.

[2]: https://docs.cloudant.com/api.html#cloudant-query
[3]: http://docs.mongodb.org/manual/tutorial/query-documents/

## Migration Path

Given the differences detailed above, your migration path should be as follows:

1. Consult the [Cloudant Query - iOS][1] documentation to get familiar with the new implementation and all of the supported operators.
2. Refactor your [index creation][4] code to use the new `-ensureIndexed:withName:` function provided through the CDTDatastore object (via category).
4. Update your [query construction][5] code to adhere to the new querying guidelines.
5. Modify your execution code to use `-find:` to execute your query and the new `-enumerateObjectsUsingBlock:` function to iterate through the returned `CDTQResultSet`.
6. If necessary, refactor code that uses old query options like `offset`, `limit` and `sort` to use the new `-find:skip:limit:fields:sort:` function.

[4]: https://github.com/cloudant/CDTDatastore/blob/master/doc/query.md#creating-indexes
[5]: https://github.com/cloudant/CDTDatastore/blob/master/doc/query.md#querying-syntax
