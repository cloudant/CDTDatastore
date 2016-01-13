//
//  CDTDatastore+QueryTests.m
//  CloudantQueryObjc
//
//  Created by Rhys Short on 19/11/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import <CDTDatastore/CloudantSync.h>
#import <CDTDatastore/CDTDatastore+Query.h>
#import <CDTDatastore/CDTQResultSet.h>
#import <objc/runtime.h>
#import <Specta/Specta.h>
#import <Expecta/Expecta.h>

SpecBegin(CDTDatastoreQuery) describe(@"When using datastore query", ^{

    __block NSString *factoryPath;
    __block CDTDatastoreManager *factory;
    __block CDTDatastore *ds;

    beforeEach(^{
        // Create a new CDTDatastoreFactory at a temp path

        NSString *tempDirectoryTemplate = [NSTemporaryDirectory()
            stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
        const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
        char *tempDirectoryNameCString = (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
        strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

        char *result = mkdtemp(tempDirectoryNameCString);
        expect(result).to.beTruthy();

        factoryPath = [[NSFileManager defaultManager]
            stringWithFileSystemRepresentation:tempDirectoryNameCString
                                        length:strlen(result)];
        free(tempDirectoryNameCString);

        NSError *error;
        factory = [[CDTDatastoreManager alloc] initWithDirectory:factoryPath error:&error];

        ds = [factory datastoreNamed:@"test" error:nil];
        expect(ds).toNot.beNil();

        // create some docs

        CDTDocumentRevision *rev;

        rev = [CDTDocumentRevision revisionWithDocId:@"mike12"];
        rev.body = @{ @"name" : @"mike", @"age" : @12, @"pet" : @"cat" };
        [ds createDocumentFromRevision:rev error:nil];

        rev = [CDTDocumentRevision revisionWithDocId:@"mike34"];
        rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dog" };
        [ds createDocumentFromRevision:rev error:nil];

        rev = [CDTDocumentRevision revisionWithDocId:@"mike72"];
        rev.body = @{ @"name" : @"mike", @"age" : @67, @"pet" : @"cat" };
        [ds createDocumentFromRevision:rev error:nil];

        [ds ensureIndexed:@[ @"name" ] withName:@"name"];
    });

    afterEach(^{
        // Delete the databases we used
        factory = nil;
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:factoryPath error:&error];
    });

    it(@"creates different index managers for different datastores", ^{
        CDTDatastore *ds2 = [factory datastoreNamed:@"test2" error:nil];
        expect([ds2 ensureIndexed:@[ @"name", @"age" ] withName:@"pet"]).toNot.beNil();

        CDTQIndexManager *im = objc_getAssociatedObject(ds, @selector(CDTQManager));
        CDTQIndexManager *im2 = objc_getAssociatedObject(ds2, @selector(CDTQManager));

        expect([im listIndexes]).toNot.equal([im2 listIndexes]);
    });

    it(@"can find documents", ^{
        NSDictionary *query = @{ @"name" : @"mike" };
        CDTQResultSet *results = [ds find:query];
        expect(results).toNot.beNil();
        expect([results.documentIds count]).to.equal(3);
    });

    it(@"can find documents with all params", ^{
        NSDictionary *query = @{ @"name" : @"mike" };
        CDTQResultSet *results = [ds find:query skip:0 limit:NSUIntegerMax fields:nil sort:nil];
        expect(results).toNot.beNil();
        expect([results.documentIds count]).to.equal(3);
    });
    
    it(@"can find documents and ignore non-existent documents", ^{
        NSDictionary *query = @{ @"_id" : @{ @"$in" : @[@"mike12", @"mike34", @"mike72", @"mike-not-found"] } };
        CDTQResultSet *results = [ds find:query];
        expect(results).toNot.beNil();
        expect([results.documentIds count]).to.equal(3);
    });

    it(@" can delete an index", ^{
        [ds ensureIndexed:@[ @"name", @"address" ] withName:@"basic"];
        expect([ds listIndexes][@"basic"]).toNot.beNil();

        [ds deleteIndexNamed:@"basic"];
        expect([ds listIndexes][@"basic"]).to.beNil();
    });

    it(@"can list indexes", ^{
        NSDictionary *indexes = [ds listIndexes];
        expect(indexes).toNot.beNil();
        expect([indexes count]).to.equal(1);
    });

    it(@"can update indexes", ^{
        NSDictionary *query = @{ @"name" : @"mike" };
        CDTQResultSet *results = [ds find:query];
        expect(results).toNot.beNil();
        CDTDocumentRevision *rev = [CDTDocumentRevision revision];
        rev.body = @{ @"name" : @"mike", @"age" : @34, @"pet" : @"dolhpin" };
        [ds createDocumentFromRevision:rev error:nil];
        expect([ds updateAllIndexes]).to.beTruthy();
    });
    
    it(@"can create a text index", ^{
        NSString *indexName = [ds ensureIndexed:@[ @"name" ] withName:@"text_idx" type:@"text"];
        expect(indexName).to.equal(@"text_idx");
    });
    
    it(@"can create a text index with defined settings", ^{
        NSString *indexName = [ds ensureIndexed:@[ @"name" ]
                                       withName:@"text_idx"
                                           type:@"text"
                                       settings:@{@"tokenize": @"porter"}];
        expect(indexName).to.equal(@"text_idx");
    });
    
    it(@"can check if text search is enabled", ^{
        expect([ds isTextSearchEnabled]).to.equal(@YES);
    });
    
});

SpecEnd
