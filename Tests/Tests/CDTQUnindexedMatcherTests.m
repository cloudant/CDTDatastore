//
//  CloudantQueryObjcTests.m
//  CloudantQueryObjcTests
//
//  Created by Michael Rhodes on 31/10/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <CloudantSync.h>
#import <CDTQIndexManager.h>
#import <CDTQIndexUpdater.h>
#import <CDTQIndexCreator.h>
#import <CDTQResultSet.h>
#import <CDTQQueryExecutor.h>
#import <CDTQUnindexedMatcher.h>
#import <CDTQQueryValidator.h>

SpecBegin(CDTQUnindexedMatcher) describe(@"matcherWithSelector", ^{

    it(@"returns initialised object", ^{
        CDTQUnindexedMatcher *matcher =
            [CDTQUnindexedMatcher matcherWithSelector:[CDTQQueryValidator normaliseAndValidateQuery:@{
                                                          @"n" : @"m"
                                                      }]];
        expect(matcher).toNot.beNil();
    });
});

describe(@"matches", ^{

    __block CDTDocumentRevision *rev;

    beforeAll(^{
        NSDictionary *body = @{
            @"name" : @"mike",
            @"age" : @31,
            @"pets" : @[ @"white_cat", @"black_cat" ],
            @"address" : @{@"number" : @"1", @"road" : @"infinite loop"}
        };
        rev = [[CDTDocumentRevision alloc] initWithDocId:@"dsfsdfdfs"
                                              revisionId:@"qweqeqwewqe"
                                                    body:body
                                             attachments:nil];
    });

    context(@"single", ^{

        context(@"eq", ^{

            it(@"matches", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$eq" : @"mike"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$eq" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match bad field", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$eq" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"implied eq", ^{

            it(@"matches", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{ @"name" : @"mike" }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{ @"name" : @"fred" }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match bad field", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @"fred"
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"ne", ^{

            it(@"matches", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$ne" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match", ^{
                NSDictionary *selector = @{ @"name" : @{@"$ne" : @"mike"} };
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"matches bad field", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$ne" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });
        });

        context(@"gt", ^{

            it(@"matches string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$gt" : @"andy"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$gt" : @12}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$gt" : @"robert"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match int", ^{
                NSDictionary *selector = @{ @"age" : @{@"$gt" : @45} };
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match bad field", ^{
                NSDictionary *selector = @{ @"species" : @{@"$gt" : @"fred"} };
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"gte", ^{

            it(@"matches string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$gte" : @"andy"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches equal string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$gte" : @"mike"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$gte" : @12}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches equal int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$gte" : @31}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$gte" : @"robert"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$gte" : @45}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match bad field", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$gte" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"lt", ^{

            it(@"matches string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$lt" : @"robert"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$lt" : @45}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$lt" : @"andy"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$lt" : @12}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match bad field", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$lt" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });
        context(@"lte", ^{

            it(@"matches string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$lte" : @"robert"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches equal string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$lte" : @"mike"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$lte" : @45}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches equal int", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"age" : @{@"$lte" : @31}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match string", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$lte" : @"andy"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match int", ^{
                NSDictionary *selector = @{ @"age" : @{@"$lte" : @12} };
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match bad field", ^{
                NSDictionary *selector = @{ @"species" : @{@"$lte" : @"fred"} };
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"exists", ^{

            it(@"matches existing", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$exists" : @YES}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match existing", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$exists" : @NO}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"matches missing", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$exists" : @NO}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match missing", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$exists" : @YES}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });
    });

    context(@"compound", ^{

        context(@"and", ^{

            it(@"matches all", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"$and" : @[ @{@"name" : @{@"$eq" : @"mike"}}, @{@"age" : @{@"$eq" : @31}} ]
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match some", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"$and" : @[ @{@"name" : @{@"$eq" : @"mike"}}, @{@"age" : @{@"$eq" : @12}} ]
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"doesn't match any", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"$and" : @[ @{@"name" : @{@"$eq" : @"fred"}}, @{@"age" : @{@"$eq" : @12}} ]
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"implicit and", ^{

            it(@"matches", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$eq" : @"mike"},
                    @"age" : @{@"$eq" : @31}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$eq" : @"mike"},
                    @"age" : @{@"$eq" : @12}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });

        context(@"or", ^{

            it(@"matches all okay", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"$or" : @[ @{@"name" : @{@"$eq" : @"mike"}}, @{@"age" : @{@"$eq" : @31}} ]
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches one okay", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"$or" : @[ @{@"name" : @{@"$eq" : @"mike"}}, @{@"age" : @{@"$eq" : @12}} ]
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"doesn't match", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"$or" : @[ @{@"name" : @{@"$eq" : @"fred"}}, @{@"age" : @{@"$eq" : @12}} ]
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
        });
    });

    context(@"not", ^{

        //  We can be fairly simple here as we know that the internal is that $not just negates
        //  and $ne is just translated to $not..$eq

        context(@"eq", ^{

            it(@"doesn't match", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$not" : @{@"$eq" : @"mike"}}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });

            it(@"matches", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$not" : @{@"$eq" : @"fred"}}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });

            it(@"matches bad field", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$not" : @{@"$eq" : @"fred"}}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });
        });
        
        context(@"ne", ^{
            
            it(@"doesn't match using $ne", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$ne" : @"mike"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
            it(@"doesn't match using $not..$ne", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$not" : @{@"$ne" : @"fred"}}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beFalsy();
            });
            it(@"matches using $ne", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$ne" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });
            it(@"matches using $not..$ne", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"name" : @{@"$not" : @{@"$ne" : @"mike"}}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });
            it(@"matches bad field using $ne", ^{
                NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                    @"species" : @{@"$ne" : @"fred"}
                }];
                CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
                expect([matcher matches:rev]).to.beTruthy();
            });
        });
    });

    context(@"array fields", ^{

        it(@"matches", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @"white_cat"
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });

        it(@"doesn't match good item with $not", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{@"$not" : @{@"$eq" : @"white_cat"}}
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });
        
        it(@"doesn't match good item with $ne", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{@"$ne" : @"white_cat"}
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });

        it(@"doesn't match bad item", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @"tabby_cat"
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });

        it(@"matches bad item with $not", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{@"$not" : @{@"$eq" : @"tabby_cat"}}
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });
        
        it(@"matches bad item with $ne", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{@"$ne" : @"tabby_cat"}
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });
        
        it(@"matches on array using $in", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{@"$in" : @[ @"white_cat", @"tabby_cat" ] }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });
        
        it(@"doesn't match on array using $in with bad items", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{@"$in" : @[ @"grey_cat", @"tabby_cat" ] }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });
        
        it(@"matches on non-array field using $in", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"name" : @{@"$in" : @[ @"mike", @"fred" ] }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });
        
        it(@"doesn't match on non-array field using $in with bad items", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"name" : @{@"$in" : @[ @"john", @"fred" ] }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });
        
        it(@"matches on array using $not $in with bad items", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{ @"$not" : @{@"$in" : @[ @"grey_cat", @"tabby_cat" ] } }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });
        
        it(@"doesn't match on array using $not $in", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"pets" : @{ @"$not" : @{@"$in" : @[ @"white_cat", @"tabby_cat" ] } }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });
        
        it(@"matches on non-array field using $not $in with bad items", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"name" : @{ @"$not" : @{@"$in" : @[ @"john", @"fred" ] } }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });
        
        it(@"doesn't match on non-array field using $not $in", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"name" : @{ @"$not" : @{@"$in" : @[ @"mike", @"fred" ] } }
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });
    });

    context(@"dotted fields", ^{

        it(@"matches", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"address.number" : @"1"
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beTruthy();
        });

        it(@"doesn't match", ^{
            NSDictionary *selector = [CDTQQueryValidator normaliseAndValidateQuery:@{
                @"address.number" : @"2"
            }];
            CDTQUnindexedMatcher *matcher = [CDTQUnindexedMatcher matcherWithSelector:selector];
            expect([matcher matches:rev]).to.beFalsy();
        });
    });
});

SpecEnd
