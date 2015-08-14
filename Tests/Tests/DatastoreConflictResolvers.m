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
#import "CDTAttachment.h"

#pragma mark CDTTestBiggestRevResolver
@interface CDTTestBiggestRevResolver()
@property (strong, readwrite) NSDictionary* resolvedDocumentAsDictionary;
@end

@implementation CDTTestBiggestRevResolver

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    NSInteger biggestRev = 0;
    CDTDocumentRevision  *winningRev = nil;
    for (CDTDocumentRevision *aRev in conflicts) {
        if([TD_Revision generationFromRevID:aRev.revId] > biggestRev) {
            biggestRev = [TD_Revision generationFromRevID:aRev.revId];
            winningRev = aRev;
        }
    }
    
    self.resolvedDocumentAsDictionary = [winningRev body];
    return winningRev;
}
@end

#pragma mark CDTTestDeleteConflictedDocResolver
@implementation CDTTestDeleteConflictedDocResolver

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    return [[CDTDocumentRevision alloc] initWithDocId:docId
                                           revisionId:@"2-notreallyarevId"
                                                 body:@{}
                                              deleted:YES
                                          attachments:@{}
                                             sequence:0
            ];
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


#pragma mark CDTTestSmallestRevResolver
@interface CDTTestSmallestRevResolver()
@property (strong, readwrite) NSDictionary* resolvedDocumentAsDictionary;
@end

@implementation CDTTestSmallestRevResolver

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    
    NSInteger smallestRev = -1;
    CDTDocumentRevision  *winningRev = nil;
    for (CDTDocumentRevision *aRev in conflicts) {
        if([TD_Revision generationFromRevID:aRev.revId] < smallestRev || smallestRev == -1) {
            smallestRev = [TD_Revision generationFromRevID:aRev.revId];
            winningRev = aRev;
        }
    }
    
    self.resolvedDocumentAsDictionary = [winningRev body];
    return winningRev;
    
}
@end

#pragma mark CDTTestNewRevisionResolver

@implementation CDTTestNewRevisionResolver

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    CDTDocumentRevision *old = conflicts[0];
    
    TD_Body *tdbody = [[TD_Body alloc] initWithProperties:self.resolvedDocumentAsDictionary?:@{}];
    TD_Revision *tdrev = [[TD_Revision alloc] initWithDocID:docId
                                                      revID:old.revId
                                                    deleted:NO];
    tdrev.body = tdbody;
    CDTDocumentRevision *theReturn = [[CDTDocumentRevision alloc]initWithDocId:tdrev.docID
                                                                    revisionId:tdrev.revID
                                                                          body:tdrev.body.properties
                                                                       deleted:tdrev.deleted attachments:@{}
                                                                      sequence:tdrev.sequence];
    
    return theReturn;
    
}
@end

#pragma mark CDTTestSpecificJSONDocumentResolver
@implementation CDTTestSpecificJSONDocumentResolver

-(instancetype) initWithDictionary:(NSDictionary *)documentBody
{
    self = [super init];
    if (self) {
        _documentBody = documentBody;
    }
    return self;
}

-(CDTDocumentRevision *)resolve:(NSString*)docId
                      conflicts:(NSArray*)conflicts
{
    for(CDTDocumentRevision *aRev in conflicts){
        if ([[aRev body] isEqualToDictionary:self.documentBody]) {
            return aRev;
        }
    }
    
    return nil;
}

@end

#pragma mark CDTTestMutableDocumentResolver

@implementation CDTestMutableDocumentResolver

-(id) init
{
    self = [super init];
    if (self) {
        _selectParentRev = NO;
    }
    return self;
}

-(CDTDocumentRevision *)resolve:(NSString *)docId conflicts:(NSArray *)conflicts
{
    NSString *revId = nil;
    if (self.selectParentRev) {
        // pick a random rev from the array and use that as the parent
        int lowerBound = 0;
        int upperBound = (int)conflicts.count - 1;
        int randomParentIndex = lowerBound + arc4random() % (upperBound - lowerBound);
        CDTDocumentRevision *rev = [conflicts objectAtIndex:randomParentIndex];
        revId = rev.revId;
        self.selectedParent = rev;
    }

    CDTDocumentRevision *mutableRev;
    if (revId) {
        mutableRev = [CDTDocumentRevision revisionWithDocId:docId revId:revId];
    } else {
        mutableRev = [CDTDocumentRevision revisionWithDocId:docId];
    }

    NSMutableDictionary *mergedBody = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergedAttachments = [NSMutableDictionary dictionary];

    for(CDTDocumentRevision * revision in conflicts){
        for(NSString *key in revision.body){
            mergedBody[key] = revision.body[key];
        }
        for(NSString * key in revision.attachments){
            mergedAttachments[key] = revision.attachments[key];
        }
    }
    
    if(self.addAttachment){
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *imagePath = [bundle pathForResource:@"bonsai-boston" ofType:@"jpg"];
        NSData *data = [NSData dataWithContentsOfFile:imagePath];
        
        NSString *attachmentName = @"Resolver-bonsai-boston";
        CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                              name:attachmentName
                                                                              type:@"image/jpg"];
        mergedAttachments[attachment.name] = attachment;
    }

    mutableRev.body = mergedBody;
    mutableRev.attachments = mergedAttachments;

    return mutableRev;
    
}

@end

