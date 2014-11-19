//
//  CDTMutableDocumentRevision.h
//
//
//  Created by Rhys Short on 22/07/2014.
//
//

#import "CDTDocumentRevision.h"

@interface CDTMutableDocumentRevision : CDTDocumentRevision

@property (nonatomic, strong, readwrite) NSString *sourceRevId;
@property (nonatomic, strong, readwrite) NSString *docId;

+ (CDTMutableDocumentRevision *)revision;

- (id)initWithDocumentId:(NSString *)documentId body:(NSMutableDictionary *)body;

- (id)initWithSourceRevisionId:(NSString *)sourceRevId;

- (void)setBody:(NSDictionary *)body;

- (NSMutableDictionary *)body;

- (NSMutableDictionary *)attachments;

- (void)setAttachments:(NSDictionary *)attachments;

@end
