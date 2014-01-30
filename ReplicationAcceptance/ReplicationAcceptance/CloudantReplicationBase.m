//
//  CloudantReplicationBase.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import "CloudantReplicationBase.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"

@implementation CloudantReplicationBase

+(NSString*)generateRandomString:(int)num {
    NSMutableString* string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}

- (NSString*)createTemporaryDirectoryAndReturnPath
{
    NSString *tempDirectoryTemplate =
    [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudant_sync_ios_tests.XXXXXX"];
    const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
    char *tempDirectoryNameCString =  (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
    strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

    char *result = mkdtemp(tempDirectoryNameCString);
    if (!result)
    {
        STFail(@"Couldn't create temporary directory");
    }

    NSString *path = [[NSFileManager defaultManager]
                      stringWithFileSystemRepresentation:tempDirectoryNameCString
                      length:strlen(result)];
    free(tempDirectoryNameCString);

    return path;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.

    self.factoryPath = [self createTemporaryDirectoryAndReturnPath];

    NSError *error;
    self.factory = [[CDTDatastoreManager alloc] initWithDirectory:self.factoryPath error:&error];

    STAssertNil(error, @"CDTDatastoreManager had error");
    STAssertNotNil(self.factory, @"Factory is nil");

    self.remoteRootURL = [NSURL URLWithString:@"http://localhost:5984"];
    self.remoteDbPrefix = @"replication-acceptance";
}

- (void)tearDown
{
    self.factory = nil;

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:self.factoryPath error:&error];
    STAssertNil(error, @"Error deleting temporary directory.");

    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

@end
