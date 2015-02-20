//
//  CDTEncryptionKeyDummy.m
//
//
//  Created by Enrique de la Torre Fernandez on 20/02/2015.
//
//

#import "CDTEncryptionKeyDummy.h"

@implementation CDTEncryptionKeyDummy

#pragma mark - NSObject methods
- (BOOL)isEqual:(id)object
{
    return (object && [object isMemberOfClass:[CDTEncryptionKeyDummy class]]);
}

#pragma mark - CDTEncryptionKey methods
- (NSString *)encryptionKeyOrNil { return nil; }

#pragma mark - NSCopying methods
- (id)copyWithZone:(NSZone *)zone { return [[[self class] alloc] init]; }

#pragma mark - Public class methods
+ (instancetype)dummy { return [[[self class] alloc] init]; }

@end
