//
//  CloudantTests.m
//  Tests
//
//  Created by Rhys Short on 08/10/2014.
//
//

#import "CloudantTests.h"
#import "CDTlogging.h"
#import "DDTTYLogger.h"

@implementation CloudantTests

+(void)initialize
{
    
    if (self == [CloudantTests self]) {
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        for(int i=0;i<sizeof(CDTLoggingLevels);i++){
            CDTLoggingLevels[i] = LOG_LEVEL_ALL;
        }
    }
}

@end
