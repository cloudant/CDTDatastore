//
//  CDTMutableDocumentRevision.h
//  
//
//  Created by Rhys Short on 22/07/2014.
//
//

#import "CDTDocumentRevision.h"

@interface CDTMutableDocumentRevision :CDTDocumentRevision

@property (nonatomic,strong,readwrite) NSMutableDictionary *body;
@property (nonatomic,strong,readwrite) NSMutableArray *attachments; //make mutable so atachments can be added whenever
@property (nonatomic,strong,readwrite) NSString *sourceRevId;
@property (nonatomic,strong, readwrite) NSString *docId;

+(CDTMutableDocumentRevision *)revision;

-(id)init;
-(id)initWithDocumentId:(NSString *)documentId andBody:(NSMutableDictionary *)body;


@end
