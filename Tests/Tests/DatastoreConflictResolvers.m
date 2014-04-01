//
//  DatastoreConflictResolvers.m
//  Tests
//
//  Created by Adam Cox on 5/1/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "DatastoreConflictResolvers.h"
#import "TD_Revision.h"
#import "TD_Body.h"
#import "CDTDocumentRevision.h"

#pragma mark CDTTestBiggestRevResolver
@implementation CDTTestBiggestRevResolver

-(NSDictionary *)resolvedDocumentAsDictionary
{
    return @{@"fooResolved":@"barResolved"};
}

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    NSInteger biggestRev = 0;
    NSString* biggestRevId;
    for(CDTDocumentRevision *aRev in conflicts){
        if([TD_Revision generationFromRevID:aRev.revId] > biggestRev)
            biggestRevId = aRev.revId;
    }
    
    TD_Body *tdbody = [[TD_Body alloc] initWithProperties:self.resolvedDocumentAsDictionary];
    TD_Revision *tdrev = [[TD_Revision alloc] initWithDocID:docId
                                                      revID:nil //doesn't matter, new CDTDocmentRevision* is appended to current winner
                                                    deleted:NO];
    tdrev.body = tdbody;
    CDTDocumentRevision *theReturn = [[CDTDocumentRevision alloc] initWithTDRevision:tdrev];
    
    return theReturn;
}
@end

#pragma mark CDTTestDeleteConflictedDocResolver
@implementation CDTTestDeleteConflictedDocResolver

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:YES];
    return [[CDTDocumentRevision alloc] initWithTDRevision:revision];
}
@end

#pragma mark CDTTestParticularDocBiggestResolver
@implementation CDTTestParticularDocBiggestResolver

-(instancetype) initWithDocsToResolve:(NSSet *)docs
{
    self = [super init];
    if (self) {
        _docIdsToResolve = docs;
    }
    return self;
}

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    
    if (![self.docIdsToResolve containsObject:docId]) {
        return nil;
    }
    
    return [super resolve:docId conflicts:conflicts];
}
@end

#pragma mark CDTTestDoesNoResolutionResolver
@implementation CDTTestDoesNoResolutionResolver

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    return nil;
}
@end

