//
//  CDTEncryptionKeyDummy.h
//
//
//  Created by Enrique de la Torre Fernandez on 20/02/2015.
//
//

#import <Foundation/Foundation.h>

#import "CDTEncryptionKey.h"

@interface CDTEncryptionKeyDummy : NSObject <CDTEncryptionKey>

+ (instancetype)dummy;

@end
