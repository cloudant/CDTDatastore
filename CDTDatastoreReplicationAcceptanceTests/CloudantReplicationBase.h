//
//  CloudantReplicationBase.h
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 29/01/2014.
//
//

#import <XCTest/XCTest.h>

@class CDTDatastoreManager;
@protocol CDTEncryptionKeyProvider;

@interface CloudantReplicationBase : XCTestCase

+(NSString*)generateRandomString:(int)num;

@property (nonatomic,strong) CDTDatastoreManager *factory;
@property (nonatomic,strong) NSString *factoryPath;
@property (nonatomic,strong) NSString *iamApiKey;

@property (nonatomic, strong) id<CDTEncryptionKeyProvider> provider;

@property (nonatomic, strong) NSURL *remoteRootURL;
@property (nonatomic, strong) NSString *remoteDbPrefix;

-(NSString*)getIAMBearerToken;

-(void) createRemoteDatabase:(NSString*)name
                 instanceURL:(NSURL*)rootURL;

-(void) deleteRemoteDatabase:(NSString*)name
                 instanceURL:(NSURL*)rootURL;

- (NSString*)createRemoteDocumentWithId:(NSString*)docId
                                   body:(NSDictionary*)body
                            databaseURL:(NSURL*)dbUrl;

- (NSString*)addAttachmentToRemoteDocumentWithId:(NSString*)docId
                                           revId:(NSString*)revId
                                  attachmentName:(NSString*)attachmentName
                                     contentType:(NSString*)contentType
                                            data:(NSData*)data
                                     databaseURL:(NSURL*)dbUrl;

- (NSString*)copyRemoteDocumentWithId:(NSString*)fromId
                                 toId:(NSString*)toId
                          databaseURL:(NSURL*)dbUrl;

@end
