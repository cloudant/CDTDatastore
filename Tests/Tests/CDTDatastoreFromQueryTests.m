//
//  CDTDatastoreFromQueryTests.m
//  Tests
//
//  Created by tomblench on 21/10/2014.
//
//

#import "CDTDatastoreFromQuery.h"
#import "CDTDatastoreFromQueryTests.h"


@implementation CDTDatastoreFromQueryTests

- (void)testQuery
{
    NSDictionary *query1 = @{@"$or": @[@{@"name": @"mike"},
                                          @{@"pet": @"cat"},
                                          @{@"$or": @[@{@"name": @"mike"},
                                                      @{@"pet": @"cat"}
                                                      ]},
                                          @{@"$and": @[@{@"name": @"tom"},
                                                       @{@"pet": @"dog"}
                                                       ]}
                                          ]
                                };
    
    NSDictionary *query2 = @{@"$or": @[@{@"name": @"mike"},
                                       @{@"pet": @"cat"},
                                       @{@"$or": @[@{@"name": @"mike"},
                                                   @{@"pet": @"cat"}
                                                   ]},
                                       @{@"$and": @[@{@"name": @"tom"},
                                                    @{@"pet": @"dog"}
                                                    ]}
                                       ]
                             };
    
    // we don't actually depend on any state of this object so we don't need to fully initialise it
    CDTDatastoreFromQuery *q = [[CDTDatastoreFromQuery alloc] init];
    CDTDatastoreQuery *cdtQuery = [[CDTDatastoreQuery alloc] init];
    cdtQuery.queryDictionary = query1;
    NSString *str1 = [q queryToDatastoreName:cdtQuery];
    cdtQuery.queryDictionary = query2;
    NSString *str2 = [q queryToDatastoreName:cdtQuery];
    STAssertEqualObjects(str1, str2, @"strings should be equal");
}

@end
