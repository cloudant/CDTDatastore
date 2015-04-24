//
//  CDTQIndexTests.m
//  CDTQIndexTests
//
//  Created by Al Finkelstein on 04/21/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <CloudantSync.h>
#import <CDTQIndex.h>
#import "Matchers/CDTQContainsAllElementsMatcher.h"

SpecBegin(CDTQIndex)

describe(@"When creating an instance of index", ^{

    __block NSArray *fieldNames;
    __block NSString *indexName;
    
    beforeAll(^{
        fieldNames = @[ @"name", @"age" ];
        indexName = @"basic";
    });
    
    it(@"constructs an index instance with the default index type", ^{
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames];
        
        expect(index.indexName).to.equal(@"basic");
        expect(index.fieldNames).to.containsAllElements(@[ @"name", @"age" ]);
        expect(index.indexType).to.equal(@"json");
        expect(index.indexSettings).to.beNil();
    });
    
    it(@"constructs an index instance with the TEXT index type and default index settings", ^{
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames ofType:@"text"];

        expect(index.indexName).to.equal(@"basic");
        expect(index.fieldNames).to.containsAllElements(@[ @"name", @"age" ]);
        expect(index.indexType).to.equal(@"text");
        expect(index.indexSettings.count).to.equal(1);
        expect(index.indexSettings[ @"tokenize" ]).to.equal(@"simple");
    });
    
    it(@"returns nil when no fields are provided", ^{
        expect([CDTQIndex index:indexName withFields:nil]).to.beNil();
        
        expect([CDTQIndex index:indexName withFields:@[]]).to.beNil();
    });
    
    it(@"returns nil when no index name is provided", ^{
        expect([CDTQIndex index:nil withFields:fieldNames]).to.beNil();
        
        expect([CDTQIndex index:@"" withFields:fieldNames]).to.beNil();
    });
    
    it(@"returns nil when index type is specifically nil or blank", ^{
        expect([CDTQIndex index:indexName withFields:fieldNames ofType:nil]).to.beNil();
        
        expect([CDTQIndex index:indexName withFields:fieldNames ofType:@""]).to.beNil();
    });
    
    it(@"returns nil when index type is invalid", ^{
        expect([CDTQIndex index:indexName withFields:fieldNames ofType:@"blah"]).to.beNil();
    });
    
    it(@"returns nil when index settings are invalid", ^{
        expect([CDTQIndex index:indexName
                     withFields:fieldNames
                         ofType:@"text"
                   withSettings:@{ @"foo": @"bar" }]).to.beNil();
    });
    
    it(@"constructs index instance but ignores index settings when appropriate", ^{
        // json indexes do not support index settings.  Index settings will be ignored.
        CDTQIndex *index = [CDTQIndex index:indexName
                                 withFields:fieldNames
                                     ofType:@"json"
                               withSettings:@{ @"tokenize": @"porter" }];

        expect(index.indexName).to.equal(@"basic");
        expect(index.fieldNames).to.containsAllElements(@[ @"name", @"age" ]);
        expect(index.indexType).to.equal(@"json");
        expect(index.indexSettings).to.beNil();
    });
    
    it(@"constructs index instance and sets index settings when appropriate", ^{
        // text indexes support the tokenize setting.
        CDTQIndex *index = [CDTQIndex index:indexName
                                 withFields:fieldNames
                                     ofType:@"text"
                               withSettings:@{ @"tokenize": @"porter" }];

        expect(index.indexName).to.equal(@"basic");
        expect(index.fieldNames).to.containsAllElements(@[ @"name", @"age" ]);
        expect(index.indexType).to.equal(@"text");
        expect(index.indexSettings[ @"tokenize" ]).to.equal(@"porter");
    });
    
});

describe(@"When comparing index content", ^{
    
    __block NSArray *fieldNames;
    __block NSString *indexName;
    
    beforeAll(^{
        fieldNames = @[ @"name", @"age" ];
        indexName = @"basic";
    });
    
    it(@"correctly compares index type inequality", ^{
        // Construct an index instance of default index type "json"
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames];
        
        expect([index compareIndexTypeTo:@"text" withIndexSettings:nil]).to.equal(NO);
    });
    
    it(@"correctly compares index type equality", ^{
        // Construct an index instance of default index type "json"
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames];
        
        expect([index compareIndexTypeTo:@"json" withIndexSettings:nil]).to.equal(YES);
    });
    
    it(@"correctly compares index setting inequality", ^{
        // Construct a "text" index instance with default index settings of { "tokenize": "simple" }
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames ofType:@"text"];
        
        expect([index compareIndexTypeTo:@"text"
                       withIndexSettings:@"{\"tokenize\":\"porter\"}"]).to.equal(NO);
    });
    
    it(@"correctly compares index setting equality", ^{
        // Construct a "text" index instance with default index settings of { "tokenize": "simple" }
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames ofType:@"text"];
        
        expect([index compareIndexTypeTo:@"text"
                       withIndexSettings:@"{\"tokenize\":\"simple\"}"]).to.equal(YES);
    });
    
});

describe(@"When retrieving index settings as a String", ^{
    
    __block NSArray *fieldNames;
    __block NSString *indexName;
    
    beforeAll(^{
        fieldNames = @[ @"name", @"age" ];
        indexName = @"basic";
    });
    
    it(@"returns a String representation of the index settings", ^{
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames ofType:@"text"];
        
        expect([index settingsAsJSON]).to.equal(@"{\"tokenize\":\"simple\"}");
    });
    
    it(@"returns nil when appropriate", ^{
        CDTQIndex *index = [CDTQIndex index:indexName withFields:fieldNames];
        
        expect([index settingsAsJSON]).to.beNil();
    });
    
});

SpecEnd
