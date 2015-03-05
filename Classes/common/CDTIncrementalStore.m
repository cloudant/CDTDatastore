//
//  CDTIncrementalStore.m
//
//
//  Created by Jimi Xenidis on 11/18/14.
//
//

#import <Foundation/Foundation.h>
#import <libkern/OSAtomic.h>

#import <CDTLogging.h>

#import "CDTIncrementalStore.h"
#import "CDTISObjectModel.h"
#import "CDTFieldIndexer.h"
#import "CDTISGraphviz.h"

#pragma mark - properties
@interface CDTIncrementalStore () <CDTReplicatorDelegate>

@property (nonatomic, strong) CDTDatastoreManager *manager;
@property (nonatomic, strong) NSURL *localURL;
@property (nonatomic, strong) NSURL *remoteURL;
@property (nonatomic, strong) CDTIndexManager *indexManager;
@property (nonatomic, strong) CDTReplicator *puller;
@property (nonatomic, strong) CDTReplicator *pusher;
@property (copy) CDTISProgressBlock progressBlock;
@property (nonatomic, strong) CDTISObjectModel *objectModel;

/**
 *  This holds the "dot" directed graph, see [dotMe](@ref dotMe)
 */
@property (nonatomic, strong) CDTISGraphviz *graph;

@end

#pragma mark - string constants
// externed
NSString *const CDTISErrorDomain = @"CDTIncrementalStoreDomain";
NSString *const CDTISException = @"CDTIncrementalStoreException";

static NSString *const CDTISType = @"CDTIncrementalStore";
static NSString *const CDTISDirectory = @"cloudant-sync-datastore-incremental";

static NSString *const CDTISObjectVersionKey = @"CDTISObjectVersion";
static NSString *const CDTISIdentifierKey = @"CDTISIdentifier";

#pragma mark - property string type for backing store

static NSString *const CDTISMetaDataKey = @"metaData";
static NSString *const CDTISObjectModelKey = @"objectModel";

#pragma mark - Code selection
// allows selection of different code paths
// Use this instead of #ifdef's so the code are actually gets compiled

/**
 *  If true, will simply delete the database object with no considerations
 */
static BOOL CDTISDeleteAggresively = NO;

/**
 *  The backing store will drop the document body if there is a JSON
 *  serialization error. When this happens there is no failure condition or
 *  error reported.  So we read it back and make sure the body isn't empty.
 */
static BOOL CDTISReadItBack = YES;

/**
 *  Will update the Dot graph on save request
 */
static BOOL CDTISDotMeUpdate = NO;

/**
 *  Select if compound predicates are ever supported
 *  > *Warning*: Untested
 */
static BOOL CDTISSupportCompoundPredicates = NO;

/**
 *  Default log level.
 *  Setting it to DDLogLevelOff does not turn it off, but will simply
 *  not adjust it.
 */
static DDLogLevel CDTISEnableLogging = DDLogLevelOff;

/**
 *  Detect if the hashes changed and update the stored object model.
 *  Turn this on if you would like to migrate objects into the same store.
 *
 *  > ***Warning***: Use with care
 */
static BOOL CDTISUpdateStoredObjectModel = NO;

/**
 *  Check entity version mismatches which could cause problems
 */
static BOOL CDTISCheckEntityVersions = NO;

/**
 *  Fix given database name to fit backing store constraints
 */
static BOOL CDTISFixUpDatabaseName = NO;

/**
 *  Check for the exisitence of subentities that we may be ignorning
 */
static BOOL CDTISCheckForSubEntities = NO;

@implementation CDTIncrementalStore

#pragma mark - Init
/**
 *  Registers this NSPersistentStore.
 *  You must invoke this method before a custom subclass of NSPersistentStore
 *  can be loaded into a persistent store coordinator.
 */
+ (void)initialize
{
    if (![[self class] isEqual:[CDTIncrementalStore class]]) {
        return;
    }

    [NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];

    /**
     *  We post to:
     *  - CDTDATASTORE_LOG_CONTEXT
     *  - CDTREPLICATION_LOG_CONTEXT
     *
     *  We are interested in:
     *  - CDTTD_REMOTE_REQUEST_CONTEXT
     *  - CDTDOCUMENT_REVISION_LOG_CONTEXT
     */
    if (CDTISEnableLogging != DDLogLevelOff) {
        [DDLog addLogger:[DDTTYLogger sharedInstance]];

        CDTChangeLogLevel(CDTREPLICATION_LOG_CONTEXT, CDTISEnableLogging);
        CDTChangeLogLevel(CDTDATASTORE_LOG_CONTEXT, CDTISEnableLogging);
        CDTChangeLogLevel(CDTDOCUMENT_REVISION_LOG_CONTEXT, CDTISEnableLogging);
        CDTChangeLogLevel(CDTTD_REMOTE_REQUEST_CONTEXT, CDTISEnableLogging);
    }
}

+ (NSString *)type { return CDTISType; }

+ (NSURL *)localDir
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsDir =
        [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *dbDir = [documentsDir URLByAppendingPathComponent:CDTISDirectory];

    return dbDir;
}

+ (NSArray *)storesFromCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
    NSArray *stores = [coordinator persistentStores];
    NSMutableArray *ours = [NSMutableArray array];

    for (id ps in stores) {
        if ([ps isKindOfClass:[CDTIncrementalStore class]]) {
            [ours addObject:ps];
        }
    }
    return [NSArray arrayWithArray:ours];
}

#pragma mark - Utils
/**
 *  Generate a unique identifier
 *
 *  @return A unique ID
 */
static NSString *uniqueID(NSString *label)
{
    return [NSString stringWithFormat:@"%@-%@-%@", CDTISPrefix, label, TDCreateUUID()];
}

/**
 * It appears that CoreData will convert an NSString reference object to an
 * NSNumber if it can, so we make sure we always use a string.
 *
 *  @param objectID a CoreData object ID
 *
 *  @return A string that is the docID for the object
 */
- (NSString *)stringReferenceObjectForObjectID:(NSManagedObjectID *)objectID
{
    id ref = [self referenceObjectForObjectID:objectID];
    if ([ref isKindOfClass:[NSNumber class]]) {
        return [ref stringValue];
    }
    return ref;
}

static BOOL badEntityVersion(NSEntityDescription *entity, NSDictionary *metadata)
{
    if (!CDTISCheckEntityVersions) return NO;

    NSString *oidName = entity.name;
    NSData *oidHash = entity.versionHash;
    NSDictionary *dic = metadata[NSStoreModelVersionHashesKey];
    NSData *metaHash = dic[oidName];

    if ([oidHash isEqualToData:metaHash]) return NO;
    return YES;
}

static BOOL badObjectVersion(NSManagedObjectID *moid, NSDictionary *metadata)
{
    if (!CDTISCheckEntityVersions) return NO;
    return badEntityVersion(moid.entity, metadata);
}

- (NSInteger)propertyTypeFromDoc:(NSDictionary *)body withName:(NSString *)name
{
    if (!self.objectModel) oops(@"no object model exists yet");

    NSString *entityName = body[CDTISEntityNameKey];
    NSInteger ptype = [self.objectModel propertyTypeWithName:name withEntityName:entityName];
    return ptype;
}

- (NSString *)destinationFromDoc:(NSDictionary *)body withName:(NSString *)name
{
    if (!self.objectModel) oops(@"no object model exists yet");

    NSString *entityName = body[CDTISEntityNameKey];
    NSString *dest = [self.objectModel destinationWithName:name withEntityName:entityName];
    return dest;
}

- (NSString *)xformFromDoc:(NSDictionary *)body withName:(NSString *)name
{
    if (!self.objectModel) oops(@"no object model exists yet");

    NSString *entityName = body[CDTISEntityNameKey];
    NSString *xform = [self.objectModel xformWithName:name withEntityName:entityName];
    return xform;
}

- (CDTIndexType)indexTypeForKey:(NSString *)key inProperties:(NSDictionary *)props
{
    // our own keys are not in the core data properties
    // but we still want to index on them
    if ([key hasPrefix:CDTISPrefix]) {
        return CDTIndexTypeString;
    }

    NSAttributeDescription *attr = props[key];

    NSAttributeType type = attr.attributeType;
    NSString *name;
    switch (type) {
        default:
        case NSUndefinedAttributeType:
            name = @"NSUndefinedAttributeType";
            break;
        case NSBinaryDataAttributeType:
            name = @"NSBinaryDataAttributeType";
            break;
        case NSTransformableAttributeType:
            name = @"NSTransformableAttributeType";
            break;
        case NSObjectIDAttributeType:
            name = @"NSObjectIDAttributeType";
            break;

        case NSStringAttributeType:
            return CDTIndexTypeString;
            break;

        case NSBooleanAttributeType:
        case NSDateAttributeType:
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
        case NSInteger64AttributeType:
        case NSDecimalAttributeType:
        case NSDoubleAttributeType:
        case NSFloatAttributeType:
            return CDTIndexTypeInteger;
    }
    [NSException raise:CDTISException format:@"can't index on %@", name];
    return 0;
}

- (NSString *)cleanURL:(NSURL *)url
{
    return
        [NSString stringWithFormat:@"%@://%@:****@%@/%@", url.scheme, url.user, url.host, url.path];
}

#pragma mark - File System
/**
 *  Create a path to the directory for the local database
 *
 *  @param dirName Name of the directory
 *  @param error   error
 *
 *  @return The path
 */
- (NSString *)pathToDBDirectory:(NSError **)error
{
    NSError *err = nil;

    self.localURL = [[self class] localDir];
    NSString *path = [self.localURL path];

    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL exists = [fileManager fileExistsAtPath:path isDirectory:&isDir];

    if (exists) {
        if (!isDir) {
            NSString *s = [NSString localizedStringWithFormat:@"Can't create datastore directory: "
                                                              @"file in the way at %@",
                                                              self.localURL];
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@", CDTISType, s);
            if (error) {
                NSDictionary *ui = @{NSLocalizedFailureReasonErrorKey : s};
                *error =
                    [NSError errorWithDomain:CDTISErrorDomain code:CDTISErrorBadPath userInfo:ui];
            }
            return nil;
        }
    } else {
        if (![fileManager createDirectoryAtURL:self.localURL
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&err]) {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: Error creating manager directory: %@",
                        CDTISType, err);
            if (error) {
                *error = err;
            }
            return nil;
        }
    }
    return path;
}

#pragma mark - property encode

- (NSString *)encodeBlob:(NSData *)blob
                withName:(NSString *)name
                 inStore:(NSMutableDictionary *)store
            withMIMEType:(NSString *)mt
{
    CDTUnsavedDataAttachment *at =
        [[CDTUnsavedDataAttachment alloc] initWithData:blob name:name type:mt];
    store[name] = at;
    return name;
}

/**
 *  Create a dictionary (for JSON) that encodes an attribute.
 *  The array represents a tuple of strings:
 *  * type
 *  * _optional_ information
 *  * encoded object
 *
 *  @param attribute The attribute
 *  @param value     The object
 *  @param error     Error
 *
 *  @return Encoded array
 */
- (NSDictionary *)encodeAttribute:(NSAttributeDescription *)attribute
                        withValue:(id)value
                        blobStore:(NSMutableDictionary *)blobStore
                            error:(NSError **)error
{
    NSAttributeType type = attribute.attributeType;
    NSString *name = attribute.name;

    // Keep this
    if (!value) oops(@"no nil allowed");

    switch (type) {
        case NSUndefinedAttributeType: {
            if (error) {
                NSString *str =
                    [NSString localizedStringWithFormat:@"%@ attribute type: %@",
                                                        CDTISUndefinedAttributeType, @(type)];
                NSDictionary *ui = @{NSLocalizedDescriptionKey : str};
                *error = [NSError errorWithDomain:CDTISErrorDomain
                                             code:CDTISErrorUndefinedAttributeType
                                         userInfo:ui];
            }
            return nil;
        }
        case NSStringAttributeType: {
            NSString *str = value;
            return @{
                name : str,
            };
        }
        case NSBooleanAttributeType:
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
        case NSInteger64AttributeType: {
            NSNumber *num = value;
            return @{
                name : num,
            };
        }
        case NSDateAttributeType: {
            NSDate *date = value;
            NSNumber *since = [NSNumber numberWithDouble:[date timeIntervalSince1970]];
            return @{
                name : since,
            };
        }
        case NSBinaryDataAttributeType: {
            NSData *data = value;
            NSString *mimeType = @"application/octet-stream";
            NSString *bytes =
                [self encodeBlob:data withName:name inStore:blobStore withMIMEType:mimeType];
            return @{
                name : bytes,
                CDTISMakeMeta(name) : @{CDTISMIMETypeKey : @"application/octet-stream"}
            };
        }
        case NSTransformableAttributeType: {
            NSString *xname = [attribute valueTransformerName];
            NSString *mimeType = @"application/octet-stream";
            NSData *save;
            if (xname) {
                Class myClass = NSClassFromString(xname);
                // Yes, we could try/catch here.. but why?
                if ([myClass respondsToSelector:@selector(MIMEType)]) {
                    mimeType = [myClass performSelector:@selector(MIMEType)];
                }
                id xform = [[myClass alloc] init];
                // use reverseTransformedValue to come back
                save = [xform transformedValue:value];
            } else {
                save = [NSKeyedArchiver archivedDataWithRootObject:value];
            }
            NSString *bytes =
                [self encodeBlob:save withName:name inStore:blobStore withMIMEType:mimeType];

            return @{ name : bytes, CDTISMakeMeta(name) : @{CDTISMIMETypeKey : mimeType} };
        }
        case NSObjectIDAttributeType: {
            // I don't think converting to a ref is needed, besides we
            // would need the entity id to decode.
            NSManagedObjectID *oid = value;
            NSURL *uri = [oid URIRepresentation];
            return @{
                name : [uri absoluteString],
            };
        }
        case NSDecimalAttributeType: {
            NSDecimalNumber *dec = value;
            NSString *desc = [dec description];
            NSDecimal val = [dec decimalValue];
            NSData *data = [NSData dataWithBytes:&val length:sizeof(val)];
            NSString *b64 = [data base64EncodedStringWithOptions:0];
            NSMutableDictionary *meta = [NSMutableDictionary dictionary];
            meta[CDTISDecimalImageKey] = b64;

            if ([dec isEqual:[NSDecimalNumber notANumber]]) {
                meta[CDTISFPNonFiniteKey] = CDTISFPNaN;
                desc = nil;
            }
            if (desc) {
                return @{
                    name : desc,
                    CDTISMakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]
                };
            } else {
                return @{
                    name : [NSNull null],
                    CDTISMakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]
                };
            }
        }
        case NSDoubleAttributeType: {
            NSNumber *num = value;
            double dbl = [num doubleValue];
            NSNumber *i64 = @(*(int64_t *)&dbl);
            NSMutableDictionary *meta = [NSMutableDictionary dictionary];
            meta[CDTISDoubleImageKey] = i64;

            if ([num isEqual:@(INFINITY)]) {
                num = @(DBL_MAX);
                meta[CDTISFPNonFiniteKey] = CDTISFPInfinity;
            }
            if ([num isEqual:@(-INFINITY)]) {
                num = @(-DBL_MAX);
                meta[CDTISFPNonFiniteKey] = CDTISFPNegInfinity;
            }
            // we use null if it is NaN that way it will not get evaluated as a predicate
            if ([num isEqual:@(NAN)]) {
                num = nil;
                meta[CDTISFPNonFiniteKey] = CDTISFPNaN;
            }
            if (num) {
                // NSDecimalNumber "description" is the closest thing we will get
                // to an arbitrary precision number in JSON, so lets use it.
                NSDecimalNumber *dec = (NSDecimalNumber *)[NSDecimalNumber numberWithDouble:dbl];
                NSString *str = [dec description];
                return @{
                    name : str,
                    CDTISMakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]
                };
            }
            return @{
                name : [NSNull null],
                CDTISMakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]
            };
        }
        case NSFloatAttributeType: {
            NSNumber *num = value;
            float flt = [num floatValue];
            NSNumber *i32 = @(*(int32_t *)&flt);
            NSMutableDictionary *meta = [NSMutableDictionary dictionary];
            meta[CDTISFloatImageKey] = i32;

            if ([num isEqual:@(INFINITY)]) {
                num = @(FLT_MAX);
                meta[CDTISFPNonFiniteKey] = CDTISFPInfinity;
            }
            if ([num isEqual:@(-INFINITY)]) {
                num = @(-FLT_MAX);
                meta[CDTISFPNonFiniteKey] = CDTISFPNegInfinity;
            }

            // we use null if it is NaN that way it will not get evaluated as a
            // predicate
            if ([num isEqual:@(NAN)]) {
                meta[CDTISFPNonFiniteKey] = CDTISFPNaN;
                num = nil;
            }
            if (num) {
                return @{
                    name : num,
                    CDTISMakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]
                };
            }
            return @{
                name : [NSNull null],
                CDTISMakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]
            };
        }
        default:
            break;
    }

    if (error) {
        NSString *str = [NSString
            localizedStringWithFormat:@"type %@: is not of " @"NSNumber: %@ = %@", @(type),
                                      attribute.name, NSStringFromClass([value class])];
        *error = [NSError errorWithDomain:CDTISErrorDomain
                                     code:CDTISErrorNaN
                                 userInfo:@{NSLocalizedDescriptionKey : str}];
    }

    return nil;
}

/**
 *  Encode a relation as a dictionary of strings:
 *  * entity name
 *  * ref/docID
 *
 *  > *Note*: the entity name is necessary for decoding
 *
 *  @param mo Managed Object
 *
 *  @return dictionary
 */
- (NSString *)encodeRelationFromManagedObject:(NSManagedObject *)mo
{
    if (!mo) {
        return @"";
    }

    NSManagedObjectID *moid = [mo objectID];

    if (moid.isTemporaryID) oops(@"tmp");

    NSString *ref = [self referenceObjectForObjectID:moid];
    return ref;
}

/**
 *  Encode a complete relation, both "to-one" and "to-many"
 *
 *  @param rel   relation
 *  @param value   object
 *  @param error error
 *
 *  @return the dictionary
 */
- (NSDictionary *)encodeRelation:(NSRelationshipDescription *)rel
                       withValue:(id)value
                           error:(NSError **)error
{
    NSString *name = rel.name;

    if (!rel.isToMany) {
        NSManagedObject *mo = value;
        NSString *enc = [self encodeRelationFromManagedObject:mo];
        return @{
            name : enc,
        };
    }
    NSMutableArray *ids = [NSMutableArray array];
    for (NSManagedObject *mo in value) {
        if (!mo) oops(@"nil mo");

        NSString *enc = [self encodeRelationFromManagedObject:mo];
        [ids addObject:enc];
    }
    return @{
        name : ids,
    };
}

/**
 *  Get all the properties of a managed object and put them in a dictionary
 *
 *  @param mo managed object
 *
 *  @return dictionary
 */
- (NSDictionary *)propertiesFromManagedObject:(NSManagedObject *)mo
                                withBlobStore:(NSMutableDictionary *)blobStore
{
    NSError *err = nil;
    NSEntityDescription *entity = [mo entity];
    NSDictionary *propDic = [entity propertiesByName];
    NSMutableDictionary *props = [NSMutableDictionary dictionary];

    for (NSString *name in propDic) {
        id prop = propDic[name];
        if ([prop isTransient]) {
            continue;
        }
        id value = [mo valueForKey:name];
        NSDictionary *enc = nil;
        if ([prop isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *att = prop;
            if (!value) {
                // don't even process nil objects
                continue;
            }
            enc = [self encodeAttribute:att withValue:value blobStore:blobStore error:&err];
        } else if ([prop isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *rel = prop;
            enc = [self encodeRelation:rel withValue:value error:&err];
        } else if ([prop isKindOfClass:[NSFetchedPropertyDescription class]]) {
            /**
             *  The incremental store should never see this, if it did it would
             * make NoSQL "views" interesting
             */
            [NSException raise:CDTISException format:@"Fetched property?: %@", prop];
        } else {
            [NSException raise:CDTISException format:@"unknown property: %@", prop];
        }

        if (!enc) {
            [NSException raise:CDTISException
                        format:@"There should always be an encoding: %@: %@", prop, err];
        }

        [props addEntriesFromDictionary:enc];
    }

    if (CDTISCheckForSubEntities) {
        NSArray *entitySubs = [[mo entity] subentities];
        if ([entitySubs count] > 0) {
            CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"%@: subentities: %@", CDTISType, entitySubs);
        }
    }
    return [NSDictionary dictionaryWithDictionary:props];
}

#pragma mark - property decode
/**
 *  Create an Object ID from the information decoded in
 *  [encodeRelationFromManagedObject](@ref encodeRelationFromManagedObject)
 *
 *  @param entityName entityName
 *  @param ref        ref
 *  @param context    context
 *
 *  @return object ID
 */
- (NSManagedObjectID *)decodeRelationFromEntityName:(NSString *)entityName
                                            withRef:(NSString *)ref
                                        withContext:(NSManagedObjectContext *)context
{
    if (entityName.length == 0) {
        return nil;
    }
    NSEntityDescription *entity =
        [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    NSManagedObjectID *moid = [self newObjectIDForEntity:entity referenceObject:ref];
    return moid;
}

- (NSData *)decodeBlob:(NSString *)name fromStore:(NSDictionary *)store
{
    CDTSavedAttachment *att = store[name];
    return [att dataFromAttachmentContent];
}

/**
 *  Get the object from the encoded property
 *
 *  @param name    name of object
 *  @param body    Dictionary representing the document
 *  @param context Context for the object
 *
 *  @return object or nil if no object exists
 */
- (id)decodeProperty:(NSString *)name
             fromDoc:(NSDictionary *)body
       withBlobStore:(NSDictionary *)blobStore
         withContext:(NSManagedObjectContext *)context
{
    NSInteger type = [self propertyTypeFromDoc:body withName:name];

    // we defer to newValueForRelationship:forObjectWithID:withContext:error
    if (type == CDTISRelationToManyType) {
        return nil;
    }

    id prop = body[name];
    NSDictionary *meta = body[CDTISMakeMeta(name)];

    id value;

    switch (type) {
        case NSStringAttributeType:
        case NSBooleanAttributeType:
            value = prop;
            break;
        case NSDateAttributeType: {
            NSNumber *since = prop;
            value = [NSDate dateWithTimeIntervalSince1970:[since doubleValue]];
        } break;
        case NSBinaryDataAttributeType: {
            NSString *uname = prop;
            value = [self decodeBlob:uname fromStore:blobStore];
        } break;
        case NSTransformableAttributeType: {
            NSString *xname = [self xformFromDoc:body withName:name];
            NSString *uname = prop;
            NSData *restore = [self decodeBlob:uname fromStore:blobStore];
            if (xname) {
                id xform = [[NSClassFromString(xname) alloc] init];
                // is the xform guaranteed to handle nil?
                value = [xform reverseTransformedValue:restore];
            } else {
                value = [NSKeyedUnarchiver unarchiveObjectWithData:restore];
            }
        } break;
        case NSObjectIDAttributeType: {
            NSString *str = prop;
            NSURL *uri = [NSURL URLWithString:str];
            NSManagedObjectID *moid =
                [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
            value = moid;
        } break;
        case NSDecimalAttributeType: {
            NSString *b64 = meta[CDTISDecimalImageKey];
            NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
            NSDecimal val;
            [data getBytes:&val length:sizeof(val)];
            value = [NSDecimalNumber decimalNumberWithDecimal:val];
        } break;
        case NSDoubleAttributeType: {
            // just get the image
            NSNumber *i64Num = meta[CDTISDoubleImageKey];
            int64_t i64 = [i64Num longLongValue];
            NSNumber *num = @(*(double *)&i64);
            value = num;
        } break;
        case NSFloatAttributeType: {
            // just get the image
            NSNumber *i32Num = meta[CDTISFloatImageKey];
            int32_t i32 = (int32_t)[i32Num integerValue];
            NSNumber *num = @(*(float *)&i32);
            value = num;
        } break;
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
        case NSInteger64AttributeType: {
            NSNumber *num = prop;
            value = num;
        } break;
        case CDTISRelationToOneType: {
            NSString *ref = prop;
            NSString *entityName = [self destinationFromDoc:body withName:name];
            if (entityName.length == 0) {
                value = [NSNull null];
            } else {
                NSManagedObjectID *moid =
                    [self decodeRelationFromEntityName:entityName withRef:ref withContext:context];
                if (!moid) {
                    // Our relation desitination object has not been assigned
                    value = [NSNull null];
                } else {
                    value = moid;
                }
            }
        } break;
        case CDTISRelationToManyType:
            // See the check at the top of this function
            oops(@"this is deferred to newValueForRelationship");
            break;
        default:
            oops(@"unknown encoding: %@", @(type));
            break;
    }

    return value;
}

#pragma mark - database methods
/**
 *  Make sure an index we will need exists
 *  To perform predicates and sorts we need to index on the key.
 *
 *  We just try to create the index and allow it to fail.
 *  FIXME?:
 *  We could track all the indexes in an NSSet, just not sure it is
 *  worth it.
 *
 *  @param indexName  case-sensitive name of the index.
 *                    Can only contain letters, digits and underscores.
 *                    It must not start with a digit.
 *  @param fieldName  top-level field use for index values
 *  @param type       type for the field to index on
 *  @param error      will point to an NSError object in case of error.
 *
 *  @return  YES if successful; NO in case of error.
 */
- (BOOL)ensureIndexExists:(NSString *)indexName
                fieldName:(NSString *)fieldName
                     type:(CDTIndexType)type
                    error:(NSError **)error
{
    NSError *err = nil;

    // Todo: BUG? if we get the type wrong should there be an error?
    if (![self.indexManager ensureIndexedWithIndexName:indexName
                                             fieldName:fieldName
                                                  type:type
                                                 error:&err]) {
        if (err.code != CDTIndexErrorIndexAlreadyRegistered) {
            if (error) *error = err;
            return NO;
        }
    }
    return YES;
}

/**
 *  Insert a managed object to the database
 *
 *  @param mo    Managed Object
 *  @param error Error
 *
 *  @return YES on success, NO on Failure
 */
- (BOOL)insertManagedObject:(NSManagedObject *)mo error:(NSError **)error
{
    NSError *err = nil;
    NSManagedObjectID *moid = [mo objectID];
    NSString *docID = [self stringReferenceObjectForObjectID:moid];
    NSEntityDescription *entity = [mo entity];

    // I don't think this should never happen
    if (moid.isTemporaryID) oops(@"tmp");

    if (badObjectVersion(moid, self.metadata)) oops(@"hash mismatch?: %@", moid);

    CDTMutableDocumentRevision *newRev = [CDTMutableDocumentRevision revision];
    NSMutableDictionary *blobStore = [NSMutableDictionary dictionary];

    // do the actual attributes first
    newRev.docId = docID;
    newRev.body = [self propertiesFromManagedObject:mo withBlobStore:blobStore];
    newRev.body[CDTISObjectVersionKey] = @"1";
    newRev.body[CDTISEntityNameKey] = [entity name];
    newRev.body[CDTISIdentifierKey] = [[[mo objectID] URIRepresentation] absoluteString];
    if ([blobStore count]) {
        newRev.attachments = blobStore;
    }

    CDTDocumentRevision *rev = [self.datastore createDocumentFromRevision:newRev error:&err];
    if (!rev) {
        if (error) *error = err;
        return NO;
    }

    if (CDTISReadItBack) {
        /**
         *  See CDTISReadItBack
         */
        rev = [self.datastore getDocumentWithId:newRev.docId error:&err];
        if (!rev) {
            // Always oops!
            oops(@"ReadItBack: error: %@", err);
        }
        // Always oops
        if ([rev.body count] == 0) oops(@"empty save");
    }

    return YES;
}

/**
 *  Update existing object in the database
 *
 *  @param mo    Managed Object
 *  @param error Error
 *
 *  @return YES/NO
 */
- (BOOL)updateManagedObject:(NSManagedObject *)mo error:(NSError **)error
{
    NSError *err = nil;
    NSManagedObjectID *moid = [mo objectID];

    if (badObjectVersion(moid, self.metadata)) oops(@"hash mismatch?: %@", moid);

    NSString *docID = [self stringReferenceObjectForObjectID:moid];

    NSEntityDescription *entity = [mo entity];
    NSDictionary *propDic = [entity propertiesByName];

    NSMutableDictionary *props = [NSMutableDictionary dictionary];
    NSMutableDictionary *blobStore = [NSMutableDictionary dictionary];
    NSDictionary *changed = [mo changedValues];

    for (NSString *name in changed) {
        NSDictionary *enc = nil;
        id prop = propDic[name];
        if ([prop isTransient]) {
            continue;
        }
        if ([prop isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *att = prop;
            enc = [self encodeAttribute:att withValue:changed[name] blobStore:blobStore error:&err];
        } else if ([prop isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *rel = prop;
            enc = [self encodeRelation:rel withValue:changed[name] error:&err];
        } else {
            oops(@"bad prop?");
        }
        [props addEntriesFromDictionary:enc];
    }

    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev) {
        if (error) *error = err;
        return NO;
    }

    // TODO: version HACK
    NSString *oldVersion = oldRev.body[CDTISObjectVersionKey];
    uint64_t version = [oldVersion longLongValue];
    ++version;
    NSNumber *v = [NSNumber numberWithUnsignedLongLong:version];
    props[CDTISObjectVersionKey] = [v stringValue];

    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    // update attachments first
    if ([blobStore count]) {
        [upRev.attachments addEntriesFromDictionary:blobStore];
    }

    /**
     *  > ***Note***:
     *  >
     *  > Since the properties of the entity are being updated/modified, there is
     *  > no need to remove the actual members from the body.
     *  >
     *  > However, care must be taken, since this code adds additional "Meta Properties"
     *  > to the dictionary that may require cleaning up.
     *  >
     *  > Currently, this is not a problem since we collect all "Meta Properties"
     *  > in a single dictionary that is always present if necessary.
     *  > Therefore, there is nothing to clean up.
     */
    [upRev.body addEntriesFromDictionary:props];

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        return NO;
    }

    if ([blobStore count]) {
        if (![self.datastore compactWithError:&err]) {
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@: datastore compact failed: %@", CDTISType,
                       err);
        }
    }

    if (CDTISReadItBack) {
        /**
         *  See CDTISReadItBack
         */
        upedRev = [self.datastore getDocumentWithId:upRev.docId error:&err];
        if (!upedRev) {
            // Always oops!
            oops(@"ReadItBack: error: %@", err);
        }
        // Always oops
        if ([upedRev.body count] == 0) oops(@"empty save");
    }

    return YES;
}

/**
 *  Delete a managed object from the database
 *
 *  > ***Warning***: it is assumed that CoreData will handle any cascading
 *  > deletes that are required.

 *  @param mo    Managed Object
 *  @param error Error
 *
 *  @return YES/NO, No with error
 */
- (BOOL)deleteManagedObject:(NSManagedObject *)mo error:(NSError **)error
{
    NSError *err = nil;
    NSManagedObjectID *moid = [mo objectID];
    NSString *docID = [self stringReferenceObjectForObjectID:moid];

    /**
     *  @See CDTISDeleteAggresively
     */
    if (CDTISDeleteAggresively) {
        if (![self.datastore deleteDocumentWithId:docID error:&err]) {
            if (error) *error = err;
            return NO;
        }
        return YES;
    }

    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev) {
        if (error) *error = err;
        return NO;
    }

    if (![self.datastore deleteDocumentFromRevision:oldRev error:&err]) {
        if (error) *error = err;
        return NO;
    }
    return YES;
}

/**
 *  optLock??
 *
 *  @param mo    Managed Object
 *  @param error Error
 *
 *  @return YES/NO
 */
- (BOOL)optLockManagedObject:(NSManagedObject *)mo error:(NSError **)error
{
    oops(@"We don't do this yet");
    return NO;
}

/**
 *  Create a dictionary of values for the attributes of a Managed Object from
 *  a docId/ref.
 *
 *  @param docID   docID
 *  @param context context
 *  @param version version
 *  @param error   error
 *
 *  @return dictionary or nil with error
 */
- (NSDictionary *)valuesFromDocID:(NSString *)docID
                      withContext:(NSManagedObjectContext *)context
                       versionPtr:(uint64_t *)version
                            error:(NSError **)error
{
    NSError *err = nil;

    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docID error:&err];
    if (!rev) {
        if (error) *error = err;
        return nil;
    }
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *name in rev.body) {
        if ([name isEqualToString:CDTISObjectVersionKey]) {
            *version = [rev.body[name] longLongValue];
            continue;
        }
        if ([name hasPrefix:CDTISPrefix]) {
            continue;
        }

        id value = [self decodeProperty:name
                                fromDoc:rev.body
                          withBlobStore:rev.attachments
                            withContext:context];
        if (!value) {
            // Dictionaries do not take nil, but Values can't have NSNull.
            // Apparently we just skip it and the properties faults take care
            // of it
            continue;
        }
        values[name] = value;
    }

    return [NSDictionary dictionaryWithDictionary:values];
}

#pragma mark - Push/Pull with Remote methods

- (BOOL)commWithRemote:(CDTReplicator *)rep
                 error:(NSError **)error
          withProgress:(CDTISProgressBlock)progress
{
    NSError *err = nil;

    CDTReplicatorState state = rep.state;
    // we can only start from pending
    if (state != CDTReplicatorStatePending) {
        NSString *stateName = nil;
        switch (state) {
            case CDTReplicatorStatePending:
                break;
            case CDTReplicatorStateComplete:
                stateName = @"CDTReplicatorStateComplete";
                break;
            case CDTReplicatorStateError:
                stateName = @"CDTReplicatorStateError";
                break;
            case CDTReplicatorStateStopped:
                stateName = @"CDTReplicatorStateStopped";
                break;
            default:
                stateName = [NSString stringWithFormat:@"Unknown replicator state: %@", @(state)];
                break;
        }
        if (error) {
            NSString *s =
                [NSString localizedStringWithFormat:@"Replicator in state: %@", stateName];

            *error = [NSError errorWithDomain:CDTISErrorDomain
                                         code:CDTISErrorSyncBusy
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        return NO;
    }

    if (self.progressBlock) {
        if (error) {
            NSString *s =
                [NSString localizedStringWithFormat:@"Replicator comm already in progress"];

            *error = [NSError errorWithDomain:CDTISErrorDomain
                                         code:CDTISErrorSyncBusy
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        return NO;
    }
    self.progressBlock = progress;

    if ([rep startWithError:&err]) {
        // The delegates should reset self.progressBlock
        return YES;
    }
    if (err) {
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@: Replicator: start: %@: %@", CDTISType,
                   [self cleanURL:self.remoteURL], err);
    }
    self.progressBlock = nil;
    return NO;
}

- (BOOL)pushToRemote:(NSError **)error
        withProgress:
            (void (^)(BOOL last, NSInteger processed, NSInteger total, NSError *err))progress;
{
    if (!self.pusher) {
        if (error) {
            NSString *s = [NSString localizedStringWithFormat:@"There is no remote defined"];

            *error = [NSError errorWithDomain:CDTISErrorDomain
                                         code:CDTISErrorNoRemoteDB
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        return NO;
    }
    return [self commWithRemote:self.pusher error:error withProgress:progress];
}

- (BOOL)pullFromRemote:(NSError **)error
          withProgress:
              (void (^)(BOOL last, NSInteger processed, NSInteger total, NSError *err))progress;
{
    if (!self.puller) {
        if (error) {
            NSString *s = [NSString localizedStringWithFormat:@"There is no remote defined"];

            *error = [NSError errorWithDomain:CDTISErrorDomain
                                         code:CDTISErrorNoRemoteDB
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        return NO;
    }

    return [self commWithRemote:self.puller error:error withProgress:progress];
}

- (BOOL)replicateInDirection:(CDTISReplicateDirection)direction
                   withError:(NSError **)error
                withProgress:(CDTISProgressBlock)progress;
{
    if (direction == push) {
        return [self pushToRemote:error withProgress:progress];
    }
    return [self pullFromRemote:error withProgress:progress];
}

/**
 *  configure the replicators
 *
 *  @param remoteURL remoteURL
 *  @param manager   manager
 *  @param datastore datastore
 *
 *  @return YES/NO. If `NO` then the caller should continue with local database
 *          only.
 */
- (BOOL)setupReplicators:(NSURL *)remoteURL
                 manager:(CDTDatastoreManager *)manager
               datastore:(CDTDatastore *)datastore
{
    NSError *err = nil;

    // If remoteURL has a host component, then we have a replication target
    if (![remoteURL host]) {
        CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: no host component, so no replication",
                   CDTISType);
        return NO;
    }

    NSString *clean = [self cleanURL:remoteURL];

    CDTReplicatorFactory *repFactory =
        [[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];
    if (!repFactory) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create replication factory",
                    CDTISType, clean);
        return NO;
    }

    CDTPushReplication *pushRep =
        [CDTPushReplication replicationWithSource:datastore target:remoteURL];
    if (!pushRep) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create push replication object",
                    CDTISType, clean);
        return NO;
    }

    CDTReplicator *pusher = [repFactory oneWay:pushRep error:&err];
    if (!pusher) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create replicator for push: %@",
                    CDTISType, clean, err);
        return NO;
    }

    CDTPullReplication *pullRep =
        [CDTPullReplication replicationWithSource:remoteURL target:datastore];
    if (!pullRep) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create pull replication object",
                    CDTISType, clean);
        return NO;
    }

    CDTReplicator *puller = [repFactory oneWay:pullRep error:&err];
    if (!puller) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create replicator for pull: %@",
                    CDTISType, clean, err);
        return NO;
    }

    self.remoteURL = remoteURL;

    self.puller = puller;
    puller.delegate = self;

    self.pusher = pusher;
    pusher.delegate = self;

    return YES;
}

- (BOOL)linkReplicators:(NSURL *)remoteURL
{
    return [self setupReplicators:remoteURL manager:self.manager datastore:self.datastore];
}

- (void)unlinkReplicators
{
    self.pusher = nil;
    self.puller = nil;
}

static NSString *fixupName(NSString *name)
{
    if (!CDTISFixUpDatabaseName) return name;

    // http://wiki.apache.org/couchdb/HTTP_database_API#Naming_and_Addressing
    static NSString *kLegalChars = @"abcdefghijklmnopqrstuvwxyz0123456789_$()+-/";
    static NSCharacterSet *kIllegalNameChars;
    if (!kIllegalNameChars) {
        kIllegalNameChars =
            [[NSCharacterSet characterSetWithCharactersInString:kLegalChars] invertedSet];
    }
    NSMutableString *fix = [NSMutableString stringWithString:[name lowercaseString]];
    // must start with a letter
    NSUInteger first = [fix characterAtIndex:0];
    if ('0' <= first && first <= '9') {
        [fix insertString:@"db_" atIndex:0];
    }
    NSRange srch = NSMakeRange(0, [fix length]);
    for (;;) {
        NSRange r = [fix rangeOfCharacterFromSet:kIllegalNameChars options:0 range:srch];
        if (r.location == NSNotFound) break;
        [fix replaceCharactersInRange:r withString:@"_"];
        NSUInteger l = r.location + r.length;
        srch = NSMakeRange(l, [fix length] - l);
    }
    return [NSString stringWithString:fix];
}

/**
 *  Initialize database
 *  > *Note*: only does local right now
 *
 *  @param error Error
 *
 *  @return YES/NO
 */
- (BOOL)initializeDatabase:(NSError **)error
{
    NSError *err = nil;

    NSURL *remoteURL = [self URL];

    /**
     *  At this point, we assume we are just a local store.
     *  We use the last path component to name the database in the local
     *  directory.
     */
    NSString *last = [remoteURL lastPathComponent];
    NSString *databaseName = fixupName(last);
    NSString *path = [self pathToDBDirectory:&err];
    if (!path) {
        if (error) *error = err;
        return NO;
    }

    CDTDatastoreManager *manager = [[CDTDatastoreManager alloc] initWithDirectory:path error:&err];
    if (!manager) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: Error creating manager: %@", CDTISType,
                    databaseName, err);
        if (error) *error = err;
        return NO;
    }

    CDTDatastore *datastore = [manager datastoreNamed:databaseName error:&err];
    if (!datastore) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: Error creating datastore: %@", CDTISType,
                    databaseName, err);
        if (error) *error = err;
        return NO;
    }

    CDTIndexManager *indexManager =
        [[CDTIndexManager alloc] initWithDatastore:datastore error:&err];
    if (!indexManager) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: Cannot create indexManager: %@", CDTISType,
                    databaseName, err);
        return NO;
    }

    // Commit before setting up replication
    self.databaseName = databaseName;
    self.datastore = datastore;
    self.manager = manager;
    self.indexManager = indexManager;

    if (![self setupReplicators:remoteURL manager:manager datastore:datastore]) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: continuing without replication", CDTISType);
    }

    return YES;
}

/**
 *  Setup the indexes.
 *  We only care about one right now and that is to find an entity name
 *
 *  @param error Error
 *
 *  @return YES/NO
 */
- (BOOL)setupIndexes:(NSError **)error
{
    NSError *err = nil;

    // the big index
    if (![self.indexManager ensureIndexedWithIndexName:CDTISEntityNameKey
                                             fieldName:CDTISEntityNameKey
                                                 error:&err]) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: cannot create default index: %@", CDTISType,
                    self.databaseName, err);
        return NO;
    }

    return YES;
}

/**
 *  Encode version hashes, which come to us as a dictionary of inline data
 *  objects, so we encode them as a hex string.
 *
 *  @param hashes hashes
 *
 *  @return encoded dictionary
 */
static NSDictionary *encodeVersionHashes(NSDictionary *hashes)
{
    NSMutableDictionary *newHashes = [NSMutableDictionary dictionary];
    for (NSString *hash in hashes) {
        NSData *h = hashes[hash];
        NSString *s = CDTISStringFromData(h);
        newHashes[hash] = s;
    }
    return [NSDictionary dictionaryWithDictionary:newHashes];
}

- (NSDictionary *)updateObjectModel
{
    NSPersistentStoreCoordinator *psc = self.persistentStoreCoordinator;
    NSManagedObjectModel *mom = psc.managedObjectModel;
    self.objectModel = [[CDTISObjectModel alloc] initWithManagedObjectModel:mom];
    NSDictionary *omd = [self.objectModel dictionary];
    return omd;
}

/**
 *  Update the metaData for CoreData in our own database
 *
 *  @param docID The docID for the metaData object in our database
 *  @param error error
 *
 *  @return YES/NO
 */
- (BOOL)updateMetadata:(NSDictionary *)metadata withDocID:(NSString *)docID error:(NSError **)error
{
    NSError *err = nil;
    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: no metaData?: %@", CDTISType,
                    self.databaseName, err);
        return NO;
    }
    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    NSDictionary *newHashes = metadata[NSStoreModelVersionHashesKey];
    if (newHashes) {
        NSDictionary *upHashes = @{NSStoreModelVersionHashesKey : encodeVersionHashes(newHashes)};
        NSMutableDictionary *upMeta = [upRev.body[CDTISMetaDataKey] mutableCopy];
        [upMeta addEntriesFromDictionary:upHashes];
        upRev.body[CDTISMetaDataKey] = [NSDictionary dictionaryWithDictionary:upMeta];
    }

    if (CDTISUpdateStoredObjectModel) {
        // check if the hashes have changed
        NSDictionary *oldHashes = [self.objectModel versionHashes];

        if (oldHashes && ![oldHashes isEqualToDictionary:newHashes]) {
            // recreate the object model
            NSDictionary *omd = [self updateObjectModel];
            upRev.body[CDTISObjectModelKey] = omd;
        }
    }

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: could not update metadata: %@", CDTISType,
                    self.databaseName, err);
        return NO;
    }

    return YES;
}

/**
 *  Decode version hashes, which come to us as a dictionary of hex strings
 *  that we convert back into NSData objects.
 *
 *  @param hashes hashes
 *
 *  @return encoded dictionary
 */
static NSDictionary *decodeVersionHashes(NSDictionary *hashes)
{
    NSMutableDictionary *newHashes = [NSMutableDictionary dictionary];
    for (NSString *hash in hashes) {
        NSString *s = hashes[hash];
        NSData *h = CDTISDataFromString(s);
        newHashes[hash] = h;
    }
    return [NSDictionary dictionaryWithDictionary:newHashes];
}

/**
 *  We need to swizzle the hashes if they exist
 *
 *  @param storedMetaData <#storedMetaData description#>
 *
 *  @return <#return value description#>
 */
NSDictionary *decodeCoreDataMeta(NSDictionary *storedMetaData)
{
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    NSDictionary *hashes = storedMetaData[NSStoreModelVersionHashesKey];

    metadata[NSStoreUUIDKey] = storedMetaData[NSStoreUUIDKey];
    metadata[NSStoreTypeKey] = storedMetaData[NSStoreTypeKey];

    // hashes are encoded and need to be inline data
    if (hashes) {
        metadata[NSStoreModelVersionHashesKey] = decodeVersionHashes(hashes);
    }
    return [NSDictionary dictionaryWithDictionary:metadata];
}

/**
 *  Retrieve the CoreData metaData, if we do not have a copy then we create
 *  a new one.
 *
 *  > *Note:* not sure how to reconcile this with multiple devices and the
 *  > remote store.
 *
 *  @param docID The docID for the metaData object in our database
 *  @param error error
 *
 *  @return nil on failure with error
 */
- (NSDictionary *)getMetaDataFromDocID:(NSString *)docID error:(NSError **)error
{
    NSError *err = nil;

    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docID error:&err];
    if (!rev) {
        NSString *uuid = uniqueID(@"NSStore");
        NSDictionary *metaData = @{NSStoreUUIDKey : uuid, NSStoreTypeKey : [self type]};
        NSDictionary *omd = [self updateObjectModel];

        // store it so we can get it back the next time
        CDTMutableDocumentRevision *newRev = [CDTMutableDocumentRevision revision];
        newRev.docId = CDTISMetaDataDocID;
        newRev.body = @{
            CDTISMetaDataKey : metaData,
            CDTISObjectModelKey : omd,
        };

        rev = [self.datastore createDocumentFromRevision:newRev error:&err];
        if (!rev) {
            if (error) *error = err;
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: unable to store metaData: %@",
                        CDTISType, self.databaseName, err);
            return nil;
        }

        return metaData;
    }

    NSDictionary *omd = rev.body[CDTISObjectModelKey];
    self.objectModel = [[CDTISObjectModel alloc] initWithDictionary:omd];

    NSDictionary *storedMetaData = rev.body[CDTISMetaDataKey];
    CDTMutableDocumentRevision *upRev = [rev mutableCopy];
    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: upedRev: %@", CDTISType, self.databaseName,
                    err);
        return nil;
    }

    NSDictionary *metaData = decodeCoreDataMeta(storedMetaData);
    return metaData;
}

/**
 *  Check that the metadata is still sane.
 *
 *  > *Note*: check is trivial right now
 *
 *  @param metaData metaData
 *  @param error    error
 *
 *  @return YES/NO
 */
- (BOOL)checkMetaData:(NSDictionary *)metaData error:(NSError **)error
{
    NSString *s = metaData[NSStoreTypeKey];
    if (![s isEqualToString:CDTISType]) {
        NSString *e = [NSString localizedStringWithFormat:@"Unexpected store type %@", s];
        if (error) {
            NSDictionary *ui = @{NSLocalizedFailureReasonErrorKey : e};
            *error = [NSError errorWithDomain:CDTISErrorDomain code:CDTISErrorBadPath userInfo:ui];
        }
        return NO;
    }
    // TODO: check hashes
    return YES;
}

/**
 *  Our own setter for metadata
 *  Quote the docs:
 *  > Subclasses must override this property to provide storage and
 *  > persistence for the store metadata.
 *
 *  @param metadata
 */
- (void)setMetadata:(NSDictionary *)metadata
{
    NSError *err = nil;

    if (![self updateMetadata:metadata withDocID:CDTISMetaDataDocID error:&err]) {
        [NSException raise:CDTISException format:@"update metadata error: %@", err];
    }
    [super setMetadata:metadata];
}

#pragma mark - Database Delegates
/**
 * Called when the replicator changes state.
 */
- (void)replicatorDidChangeState:(CDTReplicator *)replicator
{
    NSString *state;
    switch (replicator.state) {
        case CDTReplicatorStatePending:
            state = @"CDTReplicatorStatePending";
            break;
        case CDTReplicatorStateStarted:
            state = @"CDTReplicatorStateStarted";
            break;
        case CDTReplicatorStateStopped:
            state = @"CDTReplicatorStateStopped";
            break;
        case CDTReplicatorStateStopping:
            state = @"CDTReplicatorStateStopping";
            break;
        case CDTReplicatorStateComplete:
            state = @"CDTReplicatorStateComplete";
            break;
        case CDTReplicatorStateError:
            state = @"CDTReplicatorStateError";
            break;
        default:
            state = @"unknown replicator state";
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: state: %@", CDTISType,
                       [self cleanURL:self.remoteURL], replicator, state);
            break;
    }

    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: state: %@", CDTISType,
               [self cleanURL:self.remoteURL], replicator, state);
}

/**
 * Called whenever the replicator changes progress
 */
- (void)replicatorDidChangeProgress:(CDTReplicator *)replicator
{
    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: progressed: [%@/%@]", CDTISType,
               [self cleanURL:self.remoteURL], replicator, @(replicator.changesProcessed),
               @(replicator.changesTotal));
    self.progressBlock(NO, replicator.changesProcessed, replicator.changesTotal, nil);
}

/**
 * Called when a state transition to COMPLETE or STOPPED is
 * completed.
 */
- (void)replicatorDidComplete:(CDTReplicator *)replicator
{
    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: completed", CDTISType,
               [self cleanURL:self.remoteURL], replicator);
    self.progressBlock(YES, 0, 0, nil);
    self.progressBlock = nil;
}

/**
 * Called when a state transition to ERROR is completed.
 */
- (void)replicatorDidError:(CDTReplicator *)replicator info:(NSError *)info
{
    CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: suffered error: %@", CDTISType,
                [self cleanURL:self.remoteURL], replicator, info);
    self.progressBlock(YES, 0, 0, info);
    self.progressBlock = nil;
}

#pragma mark - required methods
- (BOOL)loadMetadata:(NSError **)error
{
    if (self.databaseName) {
        return NO;
    }
    if (![self initializeDatabase:error]) {
        return NO;
    }
    if (![self setupIndexes:error]) {
        return NO;
    }
    NSDictionary *metaData = [self getMetaDataFromDocID:CDTISMetaDataDocID error:error];
    if (!metaData) {
        return NO;
    }
    if (![self checkMetaData:metaData error:error]) {
        [NSException raise:CDTISException format:@"failed metaData check"];
    }
    // go directly to super
    [super setMetadata:metaData];

    // this class only exists in iOS
    Class frc = NSClassFromString(@"NSFetchedResultsController");
    if (frc) {
// If there is a cache for this, it is likely stale.
// Sadly, we do not know the name of it, so we blow them all away
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [frc performSelector:@selector(deleteCacheWithName:) withObject:nil];
#pragma clang diagnostic pop
    }

    return YES;
}

/**
 *  Create a dictionary of query options for the fetch query
 *
 *  @param fetchRequest fetchRequest
 *
 *  @return options dic
 */
- (NSDictionary *)processOptions:(NSFetchRequest *)fetchRequest error:(NSError **)error
{
    NSError *err = nil;
    NSMutableDictionary *sdOpts = [NSMutableDictionary dictionary];

    NSArray *sds = [fetchRequest sortDescriptors];
    if (sds.count) {
        if (sds.count > 1) {
            oops(@"not sure what to do here");
        }

        for (NSSortDescriptor *sd in sds) {
            NSString *sel = NSStringFromSelector([sd selector]);
            if (![sel isEqualToString:@"compare:"]) {
                [NSException raise:CDTISException format:@"we do not allow custom compares"];
            }
            NSString *key = [sd key];

            NSEntityDescription *entity = [fetchRequest entity];
            NSDictionary *props = [entity propertiesByName];

            CDTIndexType type = [self indexTypeForKey:key inProperties:props];

            if (![self ensureIndexExists:key fieldName:key type:type error:&err]) {
                if (error) *error = err;
                return nil;
            }
            sdOpts[kCDTQueryOptionSortBy] = key;
            if ([sd ascending]) {
                sdOpts[kCDTQueryOptionAscending] = @YES;
            } else {
                sdOpts[kCDTQueryOptionDescending] = @YES;
            }
        }
    }

    if (fetchRequest.fetchLimit) {
        sdOpts[kCDTQueryOptionLimit] = @(fetchRequest.fetchLimit);
    }
    if (fetchRequest.fetchOffset) {
        sdOpts[kCDTQueryOptionOffset] = @(fetchRequest.fetchOffset);
    }

    if ([sdOpts count]) {
        return [NSDictionary dictionaryWithDictionary:sdOpts];
    }
    return nil;
}

/**
 *  Process comparison predicates
 *
 *  The queries currently supported by the backing store are:
 *  * `{index: @{@"max": value}}`: index <= value
 *  * `{index: value}`: index == value
 *  * `{index: @{@"min": value}}`: index >= value
 *  * `{index: @{@"min": value1, @"max": value2}}`: value1 <= index <= value2
 *  * `{index: @[value_0,...,value_n]}`: index == value_0 || ... || index == value_n
 *
 *  @param fetchRequest
 *
 *  @return predicate dictionary
 */
- (NSDictionary *)comparisonPredicate:(NSComparisonPredicate *)cp
                       withProperties:(NSDictionary *)props
{
    NSExpression *lhs = [cp leftExpression];
    NSExpression *rhs = [cp rightExpression];

    NSString *key = @"";
    if ([lhs expressionType] == NSKeyPathExpressionType) {
        key = [lhs keyPath];
    } else if ([lhs expressionType] == NSEvaluatedObjectExpressionType) {
        key = CDTISIdentifierKey;
    }

    id value = [rhs expressionValueWithObject:nil context:nil];
    NSDictionary *result = nil;
    if (!key || !value) {
        return nil;
    }
    NSString *keyStr = key;

    // process the predicate operator and create the key-value string
    NSPredicateOperatorType predType = [cp predicateOperatorType];
    switch (predType) {
        case NSLessThanOrEqualToPredicateOperatorType:
            result = @{ keyStr : @{@"max" : value} };
            break;
        case NSEqualToPredicateOperatorType:
            result = @{keyStr : value};
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            result = @{ keyStr : @{@"min" : value} };
            break;

        case NSInPredicateOperatorType: {
            if ([value isKindOfClass:[NSString class]]) {
                [NSException raise:CDTISException format:@"Can't do substring matches: %@", value];
                break;
            }
            if ([value respondsToSelector:@selector(objectEnumerator)]) {
                NSMutableArray *set = [NSMutableArray array];
                for (id el in value) {
                    [set addObject:el];
                }
                result = @{keyStr : [NSArray arrayWithArray:set]};
            }
            break;
        }

        case NSBetweenPredicateOperatorType: {
            if (![value isKindOfClass:[NSArray class]]) {
                [NSException raise:CDTISException format:@"unexpected \"between\" args"];
                break;
            }
            NSArray *between = value;

            result = @{
                keyStr : @{@"min" : [between objectAtIndex:0], @"max" : [between objectAtIndex:1]}
            };
            break;
        }

        case NSNotEqualToPredicateOperatorType:
        case NSGreaterThanPredicateOperatorType:
        case NSLessThanPredicateOperatorType:
        case NSMatchesPredicateOperatorType:
        case NSLikePredicateOperatorType:
        case NSBeginsWithPredicateOperatorType:
        case NSEndsWithPredicateOperatorType:
        case NSCustomSelectorPredicateOperatorType:
        case NSContainsPredicateOperatorType:
            [NSException raise:CDTISException
                        format:@"Predicate with unsupported comparison operator: %@", @(predType)];
            break;

        default:
            [NSException raise:CDTISException
                        format:@"Predicate with unrecognized comparison operator: %@", @(predType)];
            break;
    }

    NSError *err = nil;

    CDTIndexType type = [self indexTypeForKey:keyStr inProperties:props];

    if (![self ensureIndexExists:keyStr fieldName:keyStr type:type error:&err]) {
        [NSException raise:CDTISException format:@"failed at creating index for key %@", keyStr];
        // it is unclear what happens if I perform a query with no index
        // I think we should let the backing store deal with it.
    }
    return result;
}

- (NSDictionary *)processPredicate:(NSPredicate *)p withProperties:(NSDictionary *)props
{
    if ([p isKindOfClass:[NSCompoundPredicate class]]) {
        if (!CDTISSupportCompoundPredicates) {
            [NSException raise:CDTISException
                        format:@"Compound predicates not supported at all: %@", p];
        }

        NSCompoundPredicate *cp = (NSCompoundPredicate *)p;
        NSCompoundPredicateType predType = [cp compoundPredicateType];

        switch (predType) {
            case NSAndPredicateType: {
                oops(@"can we do this? I don't think so. need a test.");
                NSMutableDictionary *ands = [NSMutableDictionary dictionary];
                for (NSPredicate *sub in [cp subpredicates]) {
                    [ands
                        addEntriesFromDictionary:[self processPredicate:sub withProperties:props]];
                }
                return [NSDictionary dictionaryWithDictionary:ands];
            }
            case NSOrPredicateType:
            case NSNotPredicateType:
                [NSException
                     raise:CDTISException
                    format:@"Predicate with unsupported compound operator: %@", @(predType)];
                break;
            default:
                [NSException
                     raise:CDTISException
                    format:@"Predicate with unrecognized compound operator: %@", @(predType)];
        }

        return nil;

    } else if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *cp = (NSComparisonPredicate *)p;
        return [self comparisonPredicate:cp withProperties:props];
    }
    return nil;
}

/**
 *  Process the predicates
 *
 *  @param fetchRequest fetchRequest
 *
 *  @return return value
 */
- (NSDictionary *)processPredicate:(NSFetchRequest *)fetchRequest
{
    NSPredicate *p = [fetchRequest predicate];
    if (!p) {
        return nil;
    }

    NSEntityDescription *entity = [fetchRequest entity];
    NSDictionary *props = [entity propertiesByName];

    return [self processPredicate:p withProperties:props];
}

/**
 *  create a query dictionary for the backing store
 *  > *Note*: the predicates are included in this dictionary
 *
 *  @param fetchRequest fetchRequest
 *
 *  @return return value
 */
- (NSDictionary *)queryForFetchRequest:(NSFetchRequest *)fetchRequest error:(NSError **)error
{
    NSEntityDescription *entity = [fetchRequest entity];
    NSString *entityName = [entity name];

    NSMutableDictionary *query = [@{ CDTISEntityNameKey : entityName } mutableCopy];
    NSDictionary *predicate = [self processPredicate:fetchRequest];
    [query addEntriesFromDictionary:predicate];

    return [NSDictionary dictionaryWithDictionary:query];
}

- (NSArray *)fetchDictionaryResult:(NSFetchRequest *)fetchRequest withHits:(CDTQueryResult *)hits
{
    // we only support one grouping
    if ([fetchRequest.propertiesToGroupBy count] > 1) {
        [NSException raise:CDTISException format:@"can only group by 1 property"];
    }

    id groupProp = [fetchRequest.propertiesToGroupBy firstObject];

    // we only support grouping by an existing property, no expressions or
    // aggregates
    if (![groupProp isKindOfClass:[NSPropertyDescription class]]) {
        [NSException raise:CDTISException format:@"can only handle properties for groupings"];
    }

    // use a dictionary so we can track repeats
    NSString *groupKey = [groupProp name];
    NSMutableDictionary *group = [NSMutableDictionary dictionary];
    for (CDTDocumentRevision *rev in hits) {
        id value = rev.body[groupKey];
        NSArray *revList = group[value];
        if (revList) {
            group[value] = [revList arrayByAddingObject:rev];
        } else {
            group[value] = @[ rev ];
        }
    }

    // get the results ready
    NSMutableArray *results = [NSMutableArray array];

    // for every entry in group, build the dictionary of elements
    for (id g in group) {
        NSArray *ga = group[g];
        CDTDocumentRevision *rev = [ga firstObject];
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        for (id prop in fetchRequest.propertiesToFetch) {
            if ([prop isKindOfClass:[NSAttributeDescription class]]) {
                NSAttributeDescription *a = prop;
                dic[a.name] = rev.body[a.name];
            } else if ([prop isKindOfClass:[NSExpressionDescription class]]) {
                NSExpressionDescription *ed = prop;
                NSExpression *e = ed.expression;
                if (e.expressionType != NSFunctionExpressionType) {
                    [NSException raise:CDTISException format:@"expression type is not a function"];
                }
                if (![e.function isEqualToString:@"count:"]) {
                    [NSException raise:CDTISException
                                format:@"count: is the only function currently supported"];
                }
                dic[ed.name] = @([ga count]);
            } else {
                [NSException raise:CDTISException format:@"unsupported property descriptor"];
            }
        }
        [results addObject:[NSDictionary dictionaryWithDictionary:dic]];
    }
    return [NSArray arrayWithArray:results];
}

- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest
              withContext:(NSManagedObjectContext *)context
                    error:(NSError **)error
{
    NSError *err;
    NSFetchRequestResultType fetchType = [fetchRequest resultType];

    /**
     *  The document, [Responding to Fetch
     * Requests](https://developer.apple.com/library/ios/documentation/DataManagement/Conceptual/IncrementalStorePG/ImplementationStrategy/ImplementationStrategy.html#//apple_ref/doc/uid/TP40010706-CH2-SW6),
     *  suggests that we get the entity from the fetch request.
     *  Turns out this can be stale so we check it and log it.
     */
    NSEntityDescription *entity = [fetchRequest entity];
    if (badEntityVersion(entity, self.metadata)) oops(@"bad entity mismatch: %@", entity);

    // Get sort descriptors and add them as options
    err = nil;
    NSDictionary *options = [self processOptions:fetchRequest error:&err];
    if (!options && err) {
        if (error) *error = err;
        // I think we do this on error, it is unclear
        return nil;
    }

    NSDictionary *query = [self queryForFetchRequest:fetchRequest error:&err];
    if (!query) {
        if (error) *error = err;
        return nil;
    }

    err = nil;
    CDTQueryResult *hits = [self.indexManager queryWithDictionary:query options:options error:&err];
    // hits == nil is valid, get rid of this once tested
    if (!hits && err) {
        if (error) *error = err;
        return nil;
    }

    switch (fetchType) {
        case NSManagedObjectResultType: {
            NSMutableArray *results = [NSMutableArray array];
            for (CDTDocumentRevision *rev in hits) {
                NSManagedObjectID *moid =
                    [self newObjectIDForEntity:entity referenceObject:rev.docId];
                NSManagedObject *mo = [context objectWithID:moid];
                [results addObject:mo];
            }
            return [NSArray arrayWithArray:results];
        }

        case NSManagedObjectIDResultType: {
            NSMutableArray *results = [NSMutableArray array];
            for (CDTDocumentRevision *rev in hits) {
                NSManagedObjectID *moid =
                    [self newObjectIDForEntity:entity referenceObject:rev.docId];
                [results addObject:moid];
            }
            return [NSArray arrayWithArray:results];
        }

        case NSDictionaryResultType:
            return [self fetchDictionaryResult:fetchRequest withHits:hits];

        case NSCountResultType: {
            NSArray *docIDs = [hits documentIds];
            NSUInteger count = [docIDs count];
            return @[ [NSNumber numberWithUnsignedLong:count] ];
        }

        default:
            break;
    }
    NSString *s =
        [NSString localizedStringWithFormat:@"Unknown request fetch type: %@", fetchRequest];
    if (error) {
        *error = [NSError errorWithDomain:CDTISErrorDomain
                                     code:CDTISErrorExectueRequestFetchTypeUnkown
                                 userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
    }
    return nil;
}

- (id)executeSaveRequest:(NSSaveChangesRequest *)saveRequest
             withContext:(NSManagedObjectContext *)context
                   error:(NSError **)error
{
    NSError *err = nil;

    NSSet *insertedObjects = [saveRequest insertedObjects];
    for (NSManagedObject *mo in insertedObjects) {
        if (![self insertManagedObject:mo error:&err]) {
            if (error) *error = err;
            return nil;
        }
    }
    // Todo: Not sure how to deal with errors here
    NSSet *updatedObjects = [saveRequest updatedObjects];
    for (NSManagedObject *mo in updatedObjects) {
        if (![self updateManagedObject:mo error:&err]) {
            if (error) *error = err;
            return nil;
        }
    }
    NSSet *deletedObjects = [saveRequest deletedObjects];
    for (NSManagedObject *mo in deletedObjects) {
        if (![self deleteManagedObject:mo error:&err]) {
            if (error) *error = err;
            return nil;
        }
    }
    NSSet *optLockObjects = [saveRequest lockedObjects];
    for (NSManagedObject *mo in optLockObjects) {
        if (![self optLockManagedObject:mo error:&err]) {
            if (error) *error = err;
            return nil;
        }
    }

    if (CDTISDotMeUpdate) {
        NSLog(@"DotMe: %@", [self dotMe]);
    }

    /* quote the docs:
     * > If the save request contains nil values for the
     * > inserted/updated/deleted/locked collections;
     * > you should treat it as a request to save the store metadata.
     */
    if (!insertedObjects && !updatedObjects && !deletedObjects && !optLockObjects) {
        if (![self updateMetadata:[self metadata] withDocID:CDTISMetaDataDocID error:&err]) {
            if (error) *error = err;
            return nil;
        }
    }
    // indicates success
    return @[];
}

- (id)executeRequest:(NSPersistentStoreRequest *)request
         withContext:(NSManagedObjectContext *)context
               error:(NSError **)error
{
    NSPersistentStoreRequestType requestType = [request requestType];

    if (requestType == NSFetchRequestType) {
        NSFetchRequest *fetchRequest = (NSFetchRequest *)request;
        return [self executeFetchRequest:fetchRequest withContext:context error:error];
    }

    if (requestType == NSSaveRequestType) {
        NSSaveChangesRequest *saveRequest = (NSSaveChangesRequest *)request;
        return [self executeSaveRequest:saveRequest withContext:context error:error];
    }

    NSString *s = [NSString localizedStringWithFormat:@"Unknown request type: %@", @(requestType)];
    if (error) {
        *error = [NSError errorWithDomain:CDTISErrorDomain
                                     code:CDTISErrorExectueRequestTypeUnkown
                                 userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
    }
    return nil;
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context
                                               error:(NSError **)error
{
    NSError *err = nil;
    NSString *docID = [self stringReferenceObjectForObjectID:objectID];
    uint64_t version = 1;

    NSDictionary *values =
        [self valuesFromDocID:docID withContext:context versionPtr:&version error:&err];

    if (!values && err) {
        if (error) *error = err;
        return nil;
    }

    if (badObjectVersion(objectID, self.metadata)) oops(@"hash mismatch?: %@", objectID);

    NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc]
        initWithObjectID:objectID
              withValues:[NSDictionary dictionaryWithDictionary:values]
                 version:version];
    return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship
              forObjectWithID:(NSManagedObjectID *)objectID
                  withContext:(NSManagedObjectContext *)context
                        error:(NSError **)error
{
    NSError *err = nil;
    NSString *docID = [self stringReferenceObjectForObjectID:objectID];
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docID error:&err];
    if (!rev) {
        if (error) *error = err;
        return nil;
    }

    NSString *name = [relationship name];
    NSInteger type = [self propertyTypeFromDoc:rev.body withName:name];
    NSString *entityName = [self destinationFromDoc:rev.body withName:name];

    switch (type) {
        case CDTISRelationToOneType: {
            NSString *ref = rev.body[name];
            NSManagedObjectID *moid =
                [self decodeRelationFromEntityName:entityName withRef:ref withContext:context];
            if (!moid) {
                return [NSNull null];
            }
            return moid;
        } break;
        case CDTISRelationToManyType: {
            NSMutableArray *moids = [NSMutableArray array];
            NSArray *oids = rev.body[name];
            for (NSString *ref in oids) {
                NSManagedObjectID *moid =
                    [self decodeRelationFromEntityName:entityName withRef:ref withContext:context];
                // if we get nil, don't add it, this should get us an empty array
                if (!moid && oids.count > 1) oops(@"got nil in an oid list");
                if (moid) {
                    [moids addObject:moid];
                }
            }
            return [NSArray arrayWithArray:moids];
        } break;
    }
    return nil;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error
{
    NSMutableArray *objectIDs = [NSMutableArray arrayWithCapacity:[array count]];
    for (NSManagedObject *mo in array) {
        NSEntityDescription *e = [mo entity];
        NSManagedObjectID *moid =
            [self newObjectIDForEntity:e referenceObject:uniqueID(e.name)];

        if (badObjectVersion(moid, self.metadata)) oops(@"hash mismatch?: %@", moid);

        [objectIDs addObject:moid];
    }
    return objectIDs;
}

/**
 *  Use the CDTISGraphviz to create a graph representation of the datastore
 *
 *  Once you have a database configured, in any form, you can simply call:
 *      [self dotMe]
 *
 *  What you get:
 *  * You may call this from your code or from the debugger (LLDB).
 *  * The result is stored as `self.graph`
 *  ** You can then use your favorite `writeTo` method.
 *
 *  @return A string that is the debugger command to dump the result
 *   into a file on the host.
 *
 *  > *Warning*: this replaces contents of an existing file but does not
 *  > truncate it. So if the original file was bigger there will be garbage
 *  > at the end.
 */
- (NSString *)dotMe
{
    self.graph = [[CDTISGraphviz alloc] initWithIncrementalStore:self];
    [self.graph dotMe];
    return [self.graph extractLLDB:@"/tmp/CDTIS.dot"];
}

@end
