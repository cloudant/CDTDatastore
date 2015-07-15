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

/**
 *   Creates an empty CDTMutableDocumentRevision
 **/
+ (CDTMutableDocumentRevision *)revision;

/**
 * Initializes a CDTMutableDocumentRevision revision
 *
 * @param documentId The id of the document
 * @param body The body of the document
 *
 **/
- (instancetype)initWithDocumentId:(NSString *)documentId body:(NSMutableDictionary *)body;

/**
 * Initializes a CDTMutableDocumentRevision
 * 
 * @param sourceRevId the parent revision id
 **/
- (instancetype)initWithSourceRevisionId:(NSString *)sourceRevId;

/**
 Initializes a CDTMutableDocumentRevision
 
 @param documentId the id of the document
 @param body the body of the document
 @param attachments the document's attachments
 @param sourceRevId the parent revision id
 **/
- (instancetype)initWithDocumentId:(NSString*) documentId
                              body:(NSMutableDictionary *)body
                       attachments: (NSMutableDictionary *)attachments
                  sourceRevisionId:(NSString*)sourceRevId;

- (void)setBody:(NSDictionary *)body;

- (NSMutableDictionary *)body;

- (NSMutableDictionary *)attachments;

- (void)setAttachments:(NSDictionary *)attachments;

@end
