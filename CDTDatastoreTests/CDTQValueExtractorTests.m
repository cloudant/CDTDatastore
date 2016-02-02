//
//  CloudantQueryObjcTests.m
//  CloudantQueryObjcTests
//
//  Created by Michael Rhodes on 09/27/2014.
//  Copyright (c) 2014 Michael Rhodes. All rights reserved.
//

#import <CloudantSync.h>
#import <CDTQValueExtractor.h>

SpecBegin(CDTQValueExtractor)

    describe(@"from revision", ^{

        __block CDTDocumentRevision *rev;

        beforeAll(^{
            rev = [[CDTDocumentRevision alloc] initWithDocId:@"dsfsdfdfs"
                                                  revisionId:@"qweqeqwewqe"
                                                        body:@{
                                                            @"name" : @"mike"
                                                        }
                                                 attachments:nil];
        });

        it(@"gets _id", ^{
            NSObject *value = [CDTQValueExtractor extractValueForFieldName:@"_id" fromRevision:rev];
            expect(value).to.equal(@"dsfsdfdfs");
        });

        it(@"gets _rev", ^{
            NSObject *value =
                [CDTQValueExtractor extractValueForFieldName:@"_rev" fromRevision:rev];
            expect(value).to.equal(@"qweqeqwewqe");
        });

        it(@"gets name", ^{
            NSObject *value =
                [CDTQValueExtractor extractValueForFieldName:@"name" fromRevision:rev];
            expect(value).to.equal(@"mike");
        });

    });

describe(@"when extracting single fields", ^{

    it(@"returns nil for empty field name", ^{
        NSObject *v =
            [CDTQValueExtractor extractValueForFieldName:@"" fromDictionary:@{
                @"name" : @"mike"
            }];
        expect(v).to.beNil();
    });

    it(@"returns value for single field depth", ^{
        NSObject *v = [CDTQValueExtractor extractValueForFieldName:@"name"
                                                    fromDictionary:@{
                                                        @"name" : @"mike"
                                                    }];
        expect(v).to.equal(@"mike");
    });

    it(@"returns value for two field depth", ^{
        NSDictionary *d = @{ @"name" : @{@"first" : @"mike"} };
        NSObject *v = [CDTQValueExtractor extractValueForFieldName:@"name.first" fromDictionary:d];
        expect(v).to.equal(@"mike");
    });

    it(@"returns value for three field depth", ^{
        NSDictionary *d = @{ @"aaa" : @{@"bbb" : @{@"ccc" : @"mike"}} };
        NSObject *v = [CDTQValueExtractor extractValueForFieldName:@"aaa.bbb.ccc" fromDictionary:d];
        expect(v).to.equal(@"mike");
    });

    it(@"copes when a prefix of the field name exists", ^{
        NSObject *v = [CDTQValueExtractor extractValueForFieldName:@"name.first"
                                                    fromDictionary:@{
                                                        @"name" : @"mike"
                                                    }];
        expect(v).to.beNil();

        NSDictionary *d = @{ @"name" : @{@"first" : @"mike"} };
        v = [CDTQValueExtractor extractValueForFieldName:@"name.first.mike" fromDictionary:d];
        expect(v).to.beNil();
    });

    it(@"returns the sub-document if the path doesn't terminate with a value", ^{
        NSDictionary *d = @{ @"aaa" : @{@"bbb" : @{@"ccc" : @"mike"}} };
        NSObject *v = [CDTQValueExtractor extractValueForFieldName:@"aaa.bbb" fromDictionary:d];
        expect(v).to.equal(@{ @"ccc" : @"mike" });
    });

});

SpecEnd
