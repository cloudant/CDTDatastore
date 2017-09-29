//
//  ReplicationSettings.m
//  ReplicationAcceptance
//
//  Created by Rhys Short on 17/03/2015.
//
//

#import "ReplicationSettings.h"

@interface ReplicationSettings ()


@property NSDictionary * replicationSettings;

@end

@implementation ReplicationSettings


-(instancetype)init
{
    self = [super init];

    if(self){
        NSString *replicationSettingsPath = [[NSBundle bundleForClass:[ReplicationSettings class]]
            pathForResource:@"ReplicationSettings"
                     ofType:@"plist"];

        _replicationSettings = [NSDictionary dictionaryWithContentsOfFile:replicationSettingsPath];
    }
    return self;
}

-(NSString *) iamApiKey{
    
    return self.replicationSettings[@"TEST_COUCH_IAM_API_KEY"];
}


-(NSString *) host{

    return self.replicationSettings[@"TEST_COUCH_HOST"];
}

- (NSString *) http {
    return self.replicationSettings[@"TEST_COUCH_HTTP"];
}

-(NSString *) port{
    return self.replicationSettings[@"TEST_COUCH_PORT"];
}

-(NSString *) username{
    return self.replicationSettings[@"TEST_COUCH_USERNAME"];
}

-(NSString *)password {
    return self.replicationSettings[@"TEST_COUCH_PASSWORD"];
}

-(NSNumber *) nDocs {
    return self.replicationSettings[@"TEST_COUCH_N_DOCS"];
}

-(NSNumber *) largeRevTreeSize {
    return self.replicationSettings[@"TEST_COUCH_LARGE_REV_TREE_SIZE"];
}

-(NSNumber *) loggingLevel {
    return self.replicationSettings[@"TEST_COUCH_LOGGING_LEVEL"];
}

-(NSString *) serverURI {

    NSString * server;

    if (self.username == nil || [self.username isEqualToString:@""] ){
        server = [NSString stringWithFormat:@"%@://%@:%@", self.http,self.host,self.port ];
    } else {
         server = [NSString stringWithFormat:@"%@://%@:%@@%@:%@",
                   self.http,
                   self.username,
                   self.password,
                   self.host,
                   self.port ];
    }
    
    return server;
}

-(NSString *) authorization {
    NSString *base64CredsOrIamKey;
    if([self.iamApiKey length] != 0) {
        base64CredsOrIamKey = self.iamApiKey;
    } else {
      if (self.username != nil && ![self.username isEqualToString:@""] ){
        NSData *creds = [[NSString stringWithFormat:@"%@:%@", self.username, self.password]dataUsingEncoding:NSUTF8StringEncoding];
        base64CredsOrIamKey = [NSString stringWithFormat:@"Basic %@", [creds base64EncodedStringWithOptions:0]];
      }
    }
    return base64CredsOrIamKey;
}

@end
