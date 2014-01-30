//
//  TD_RevisionTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TD_Revision.h"
//#import "TDCollateRevIDs.h"

@interface TD_RevisionTests : SenTestCase


@end

@implementation TD_RevisionTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)parseRevIDFailTest:(NSString *)aRev
{
    int gen;
    NSString* suffix;
    STAssertFalse([TD_Revision parseRevID: aRev intoGeneration: &gen andSuffix: &suffix],
                  @"parsing rev: %@ did not fail in %s", aRev, __PRETTY_FUNCTION__);
}

- (void)parseRevIDTrueTest:(NSString *)aRev expectGen:(int)gen expectSuffix:(NSString *)suffix
{
    int localgen;
    NSString* localsuffix;

    STAssertTrue([TD_Revision parseRevID: aRev intoGeneration: &localgen andSuffix: &localsuffix],
                 @"%@ did not fail in %s", aRev, __PRETTY_FUNCTION__);
    
    STAssertEquals(gen, localgen, @"generation number is not 1 in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(suffix, localsuffix,
                         @"Revision suffix is not \"%@\" in %s", suffix, __PRETTY_FUNCTION__);
    
}

- (void)testParseRevID
{
    //RequireTestCase(TD_Database);

    [self parseRevIDTrueTest:@"1-utiopturoewpt" expectGen:1 expectSuffix:@"utiopturoewpt"];
    [self parseRevIDTrueTest:@"321-fdjfdsj-e" expectGen:321 expectSuffix:@"fdjfdsj-e"];
    
    [self parseRevIDFailTest:@"0-fdjfdsj-e"];
    [self parseRevIDFailTest:@"-4-fdjfdsj-e"];
    [self parseRevIDFailTest:@"5_fdjfdsj-e"];
    [self parseRevIDFailTest:@" 5-fdjfdsj-e"];
    [self parseRevIDFailTest:@"7 -foo"];
    [self parseRevIDFailTest:@"7-"];
    [self parseRevIDFailTest:@"7"];
    [self parseRevIDFailTest:@"eiuwtiu"];
    [self parseRevIDFailTest:@""];
    
}

- (void)runCollateRevEqualsTest:(const char*)rev1 rev2:(const char*)rev2 val:(int)val
{
    STAssertEquals(TDCollateRevIDs(NULL, (int)strlen(rev1), rev1, (int)strlen(rev2), rev2),
                   val,
                   @"TDCollateRevIDs rev1:%s, rev2:%2 does not return %d in %s", rev1, rev2, val, __PRETTY_FUNCTION__);
}

- (void)testCollateRevIDs
{
    // Single-digit:
    [self runCollateRevEqualsTest:"1-foo" rev2:"1-foo" val:0];
    [self runCollateRevEqualsTest:"2-bar" rev2:"1-foo" val:1];
    [self runCollateRevEqualsTest:"1-foo" rev2:"2-bar" val:-1];
    
    // Multi-digit:
    [self runCollateRevEqualsTest:"123-bar" rev2:"456-foo" val:-1];
    [self runCollateRevEqualsTest:"456-foo" rev2:"123-bar" val:1];
    [self runCollateRevEqualsTest:"456-foo" rev2:"456-foo" val:0];
    [self runCollateRevEqualsTest:"456-foo" rev2:"456-foofoo" val:-1];

    // Different numbers of digits:
    [self runCollateRevEqualsTest:"89-foo" rev2:"123-bar" val:-1];
    [self runCollateRevEqualsTest:"123-bar" rev2:"89-foo" val:1];
    
    // Edge cases:
    [self runCollateRevEqualsTest:"123-" rev2:"89-" val:1];
    [self runCollateRevEqualsTest:"123-a" rev2:"123-a" val:0];
    
    // Invalid rev IDs:
    [self runCollateRevEqualsTest:"-a" rev2:"-b" val:-1];
    [self runCollateRevEqualsTest:"-" rev2:"-" val:0];
    [self runCollateRevEqualsTest:"" rev2:"" val:0];
    [self runCollateRevEqualsTest:"" rev2:"-b" val:-1];
    [self runCollateRevEqualsTest:"bogus" rev2:"yo" val:-1];
    [self runCollateRevEqualsTest:"bogus-x" rev2:"yo-y" val:-1];
    
}

@end
