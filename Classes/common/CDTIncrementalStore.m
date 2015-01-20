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
#import "CDTFieldIndexer.h"

@class CDTISObjectModel;

#pragma mark - properties
@interface CDTIncrementalStore () <CDTReplicatorDelegate>

@property (nonatomic, strong) NSString *databaseName;
@property (nonatomic, strong) CDTDatastoreManager *manager;
@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) NSURL *localURL;
@property (nonatomic, strong) NSURL *remoteURL;
@property (nonatomic, strong) CDTIndexManager *indexManager;
@property (nonatomic, strong) CDTReplicator *puller;
@property (nonatomic, strong) CDTReplicator *pusher;
@property (copy) CDTISProgressBlock progressBlock;
@property (nonatomic, strong) CDTISObjectModel *objectModel;

/**
 *  Helps us with our bogus [uniqueID](@ref uniqueID)
 */
@property (nonatomic, strong) NSString *run;

/**
 *  This holds the "dot" directed graph, see [dotMe](@ref dotMe)
 */
@property (nonatomic, strong) NSData *dotData;

@end

#pragma mark - string constants
// externed
NSString *const kCDTISErrorDomain = @"CDTIncrementalStoreDomain";
NSString *const kCDTISException = @"CDTIncrementalStoreException";

static NSString *const kCDTISType = @"CDTIncrementalStore";
static NSString *const kCDTISDirectory = @"cloudant-sync-datastore-incremental";
static NSString *const kCDTISPrefix = @"CDTIS";
static NSString *const kCDTISMeta = @"CDTISMeta_";
static NSString *const kCDTISMetaDataDocID = @"CDTISMetaData";

#pragma mark - private keys
static NSString *const kCDTISObjectVersionKey = @"CDTISObjectVersion";
static NSString *const kCDTISEntityNameKey = @"CDTISEntityName";
static NSString *const kCDTISIdentifierKey = @"CDTISIdentifier";

#pragma mark - types
static NSString *const kCDTISTypeKey = @"CDTISType";
static NSString *const kCDTISTypeProperties = @"attributes";
static NSString *const kCDTISTypeMetadata = @"metaData";

#pragma mark - property string type for backing store
static NSString *const kCDTISUndefinedAttributeType = @"undefined";

static NSString *const kCDTISInteger16AttributeType = @"int16";
static NSString *const kCDTISInteger32AttributeType = @"int32";
static NSString *const kCDTISInteger64AttributeType = @"int64";
static NSString *const kCDTISFloatAttributeType = @"float";
static NSString *const kCDTISDoubleAttributeType = @"double";

// encodings for floating point special values
static NSString *const kCDTISFPInfinityKey = @"infinity";
static NSString *const kCDTISFPNegInfinityKey = @"-infinity";
static NSString *const kCDTISFPNaNKey = @"nan";

static NSString *const kCDTISPropertiesKey = @"properties";
static NSString *const kCDTISTypeNameKey = @"name";
static NSString *const kCDTISTypeStringKey = @"type";
static NSString *const kCDTISTypeCodeKey = @"code";
static NSString *const kCDTISTransformerClassKey = @"xform";
static NSString *const kCDTISMIMETypeKey = @"mime-type";
static NSString *const kCDTISRelationNameKey = @"name";
static NSString *const kCDTISRelationReferenceKey = @"reference";
static NSString *const kCDTISFloatImageKey = @"ieee754_single";
static NSString *const kCDTISDoubleImageKey = @"ieee754_double";
static NSString *const kCDTISDecimalImageKey = @"nsdecimal";
static NSString *const kCDTISMetaDataKey = @"metaData";
static NSString *const kCDTISRunKey = @"run";
static NSString *const kCDTISObjectModelKey = @"objectModel";
static NSString *const kCDTISVersionHashKey = @"versionHash";
static NSString *const kCDTISRelationDesitinationKey = @"desintation";

static NSString *const kCDTISDecimalAttributeType = @"decimal";
static NSString *const kCDTISStringAttributeType = @"utf8";
static NSString *const kCDTISBooleanAttributeType = @"bool";
static NSString *const kCDTISDateAttributeType = @"date1970";
static NSString *const kCDTISBinaryDataAttributeType = @"base64";
static NSString *const kCDTISTransformableAttributeType = @"xform";
static NSString *const kCDTISObjectIDAttributeType = @"id";
static NSString *const kCDTISRelationToOneType = @"relation-to-one";
static NSString *const kCDTISRelationToManyType = @"relation-to-many";

// These are in addition to NSAttributeType, which is unsigned
static NSInteger const CDTISRelationToOneType = -1;
static NSInteger const CDTISRelationToManyType = -2;

#pragma mark - error codes
typedef NS_ENUM(NSInteger, CDTIncrementalStoreErrors) {
    CDTISErrorBadURL = 1,
    CDTISErrorBadPath,
    CDTISErrorNilObject,
    CDTISErrorUndefinedAttributeType,
    CDTISErrorObjectIDAttributeType,
    CDTISErrorNaN,
    CDTISErrorRevisionIDMismatch,
    CDTISErrorExectueRequestTypeUnkown,
    CDTISErrorExectueRequestFetchTypeUnkown,
    CDTISErrorMetaDataMismatch,
    CDTISErrorNoRemoteDB,
    CDTISErrorSyncBusy,
    CDTISErrorNotSupported
};

#pragma mark - Code selection
// allows selection of different code paths
// Use this instead of ifdefs so the code are actually gets compiled
/**
 *  This allows UIDs for individual objects to be readable.
 *  Useful for debugging
 */
static BOOL CDTISReadableUUIDs = NO;

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
 *  This is how I like to assert, it stops me in the debugger.
 *
 *  *Why not use exceptions?*
 *  1. I can continue from this simply by typing:
 *  ```
 *  strap register write pc `$pc+2`
 *  ```
 *  > Different architectures will use different addend values
 *  2. I don't need to "Add Exception Breakpoint"
 *  3. I don't need to hunt down which exception a test is using in an
 *  expected way
 *
 *  *Why is it a macro?*
 *  I want to stop *at* the `oops` line in the code and not have to "pop up"
 *  the stack if `oops` was not inlines due to optimization issues.
 *
 *  @param fmt A format string
 *  @param ... A comma-separated list of arguments to substitute into format.
 */
#define oops(fmt, ...)                                                     \
    do {                                                                   \
        NSLog(@"%s:%u OOPS: %s", __FILE__, __LINE__, __PRETTY_FUNCTION__); \
        NSLog(fmt, ##__VA_ARGS__);                                         \
        fflush(stderr);                                                    \
        __builtin_trap();                                                  \
    } while (NO);

static NSString *stringFromData(NSData *data)
{
    NSMutableString *s = [NSMutableString string];
    const unsigned char *d = (const unsigned char *)[data bytes];
    size_t sz = [data length];

    for (size_t i = 0; i < sz; i++) {
        [s appendString:[NSString stringWithFormat:@"%02x", d[i]]];
    }
    return [NSString stringWithString:s];
}

static NSData *dataFromString(NSString *str)
{
    char buf[3] = {0};

    size_t sz = [str length];

    if (sz % 2) {
        oops(@"must be even number of characters (%zd): %@", sz, str);
    }

    unsigned char *bytes = malloc(sz / 2);
    unsigned char *bp = bytes;
    for (size_t i = 0; i < sz; i += 2) {
        buf[0] = [str characterAtIndex:i];
        buf[1] = [str characterAtIndex:i + 1];
        char *chk = NULL;
        *bp = strtol(buf, &chk, 16);
        if (chk != buf + 2) {
            oops(@"bad character around %zd: %@", i, str);
        }
        ++bp;
    }

    return [NSData dataWithBytesNoCopy:bytes length:sz / 2 freeWhenDone:YES];
}

@interface CDTISProperty : NSObject
// Information about the object
@property (nonatomic) BOOL isRelationship;
@property (strong, nonatomic) NSString *name;
@property (nonatomic) NSInteger code;
@property (strong, nonatomic) NSString *xform;
@property (strong, nonatomic) NSString *destination;
@property (strong, nonatomic) NSData *versionHash;

- (CDTISProperty *)initWithAttribute:(NSAttributeDescription *)attribute;
- (CDTISProperty *)initWithRelationship:(NSRelationshipDescription *)relationship;
- (NSDictionary *)dictionary;
@end

@implementation CDTISProperty

/**
 * Defines tha attribute meta data that is stored in the object.
 *
 *  @param att
 *
 *  @return initialized object
 */
- (CDTISProperty *)initWithAttribute:(NSAttributeDescription *)attribute
{
    self.isRelationship = NO;
    NSAttributeType type = attribute.attributeType;
    self.code = type;
    self.versionHash = attribute.versionHash;

    switch (type) {
        case NSUndefinedAttributeType:
            self.name = @"NSUndefinedAttributeType";
            break;

        case NSStringAttributeType:
            self.name = kCDTISStringAttributeType;
            break;

        case NSBooleanAttributeType:
            self.name = kCDTISBooleanAttributeType;
            break;

        case NSDateAttributeType:
            self.name = kCDTISDateAttributeType;
            break;

        case NSBinaryDataAttributeType:
            self.name = kCDTISBinaryDataAttributeType;
            break;

        case NSTransformableAttributeType:
            self.name = kCDTISTransformableAttributeType;
            self.xform = [attribute valueTransformerName];
            break;

        case NSObjectIDAttributeType:
            self.name = kCDTISObjectIDAttributeType;
            break;

        case NSDecimalAttributeType:
            self.name = kCDTISDecimalAttributeType;
            break;

        case NSDoubleAttributeType:
            self.name = kCDTISDoubleAttributeType;
            break;

        case NSFloatAttributeType:
            self.name = kCDTISFloatAttributeType;
            break;

        case NSInteger16AttributeType:
            self.name = kCDTISInteger16AttributeType;
            break;

        case NSInteger32AttributeType:
            self.name = kCDTISInteger32AttributeType;
            break;

        case NSInteger64AttributeType:
            self.name = kCDTISInteger64AttributeType;
            break;

        default:
            return nil;
    }
    return self;
}

- (CDTISProperty *)initWithRelationship:(NSRelationshipDescription *)relationship
{
    self.isRelationship = YES;
    self.versionHash = relationship.versionHash;

    NSEntityDescription *ent = [relationship destinationEntity];
    self.destination = [ent name];

    if (relationship.isToMany) {
        self.name = kCDTISRelationToManyType;
        self.code = CDTISRelationToManyType;
    } else {
        self.name = kCDTISRelationToOneType;
        self.code = CDTISRelationToOneType;
    }
    return self;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[kCDTISTypeNameKey] = self.name;
    dic[kCDTISTypeCodeKey] = @(self.code);
    dic[kCDTISVersionHashKey] = stringFromData(self.versionHash);

    if (self.xform) {
        dic[kCDTISTransformerClassKey] = self.xform;
    }
    if (self.isRelationship && self.destination) {
        dic[kCDTISRelationDesitinationKey] = self.destination;
    }
    return [NSDictionary dictionaryWithDictionary:dic];
}

- (CDTISProperty *)initWithDictionary:(NSDictionary *)dic
{
    self.name = dic[kCDTISRelationNameKey];
    NSNumber *code = dic[kCDTISTypeCodeKey];
    self.code = [code integerValue];

    self.versionHash = dataFromString(dic[kCDTISVersionHashKey]);

    self.xform = dic[kCDTISTransformerClassKey];
    self.destination = dic[kCDTISRelationDesitinationKey];

    if (self.destination) {
        self.isRelationship = YES;
    }
    return self;
}

- (NSString *)description
{
    NSDictionary *dic = [self dictionary];
    return [dic description];
}

@end

@interface CDTISEntity : NSObject
@property (strong, nonatomic) NSDictionary *properties;
@property (strong, nonatomic) NSData *versionHash;

- (CDTISEntity *)initWithEntities:(NSEntityDescription *)ent;
- (CDTISEntity *)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionary;
@end

@implementation CDTISEntity : NSObject

- (CDTISEntity *)initWithEntities:(NSEntityDescription *)ent
{
    CDTISProperty *enc = nil;
    NSMutableDictionary *props = [NSMutableDictionary dictionary];
    for (id prop in [ent properties]) {
        if ([prop isTransient]) {
            continue;
        }
        if ([prop userInfo].count) {
            oops(@"there is user info.. what to do?");
        }
        if ([prop isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *att = prop;
            enc = [[CDTISProperty alloc] initWithAttribute:att];
        } else if ([prop isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *rel = prop;
            enc = [[CDTISProperty alloc] initWithRelationship:rel];
        } else if ([prop isKindOfClass:[NSFetchedPropertyDescription class]]) {
            oops(@"unexpected NSFetchedPropertyDescription");
        } else {
            oops(@"unknown property: %@", prop);
        }
        props[[prop name]] = enc;
    }
    self.properties = props;
    self.versionHash = ent.versionHash;

    return self;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (NSString *name in self.properties) {
        CDTISProperty *prop = self.properties[name];
        dic[name] = [prop dictionary];
    }
    return @{
        kCDTISPropertiesKey : [NSDictionary dictionaryWithDictionary:dic],
        kCDTISVersionHashKey : stringFromData(self.versionHash)
    };
}

- (CDTISEntity *)initWithDictionary:(NSDictionary *)dictionary
{
    NSString *vh = dictionary[kCDTISVersionHashKey];
    self.versionHash = dataFromString(vh);

    NSMutableDictionary *dic = [NSMutableDictionary dictionary];

    NSDictionary *props = dictionary[kCDTISPropertiesKey];
    for (NSString *name in props) {
        NSDictionary *desc = props[name];
        dic[name] = [[CDTISProperty alloc] initWithDictionary:desc];
    }
    self.properties = [NSDictionary dictionaryWithDictionary:dic];

    return self;
}

- (NSString *)description
{
    NSDictionary *dic = [self dictionary];
    return [dic description];
}

@end

@interface CDTISObjectModel : NSObject
@property (strong, nonatomic) NSDictionary *entities;

- (CDTISObjectModel *)initWithManagedObjectModel:(NSManagedObjectModel *)mom;
- (NSDictionary *)dictionary;
- (NSInteger)propertyTypeWithName:(NSString *)name withEntityName:(NSString *)ent;
@end

@implementation CDTISObjectModel

- (CDTISObjectModel *)initWithManagedObjectModel:(NSManagedObjectModel *)mom
{
    NSMutableDictionary *ents = [NSMutableDictionary dictionary];
    for (NSEntityDescription *ent in mom.entities) {
        if ([ent superentity]) {
            continue;
        }
        ents[ent.name] = [[CDTISEntity alloc] initWithEntities:ent];
    }
    self.entities = [NSDictionary dictionaryWithDictionary:ents];
    return self;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (NSString *name in self.entities) {
        CDTISEntity *ent = self.entities[name];
        dic[name] = [ent dictionary];
    }
    return [NSDictionary dictionaryWithDictionary:dic];
}

- (CDTISObjectModel *)initWithDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];

    for (NSString *name in dictionary) {
        NSDictionary *desc = dictionary[name];
        dic[name] = [[CDTISEntity alloc] initWithDictionary:desc];
    }
    self.entities = [NSDictionary dictionaryWithDictionary:dic];

    return self;
}

- (NSInteger)propertyTypeWithName:(NSString *)name withEntityName:(NSString *)ent
{
    CDTISEntity *ents = self.entities[ent];
    CDTISProperty *prop = ents.properties[name];
    return prop.code;
}

- (NSString *)description { return [self.entities description]; }
@end

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
     */
    if (CDTISEnableLogging != DDLogLevelOff) {
        [DDLog addLogger:[DDTTYLogger sharedInstance]];

        CDTChangeLogLevel(CDTREPLICATION_LOG_CONTEXT, CDTISEnableLogging);
        CDTChangeLogLevel(CDTDATASTORE_LOG_CONTEXT, CDTISEnableLogging);
        CDTChangeLogLevel(CDTDOCUMENT_REVISION_LOG_CONTEXT, CDTISEnableLogging);
        CDTChangeLogLevel(CDTTD_REMOTE_REQUEST_CONTEXT, CDTISEnableLogging);
    }
}

+ (NSString *)type { return kCDTISType; }

+ (NSURL *)localDir
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsDir =
        [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *dbDir = [documentsDir URLByAppendingPathComponent:kCDTISDirectory];

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
- (NSString *)uniqueID:(NSString *)label
{
    /**
     *  @See CDTISReadableUUIDs
     */
    if (!CDTISReadableUUIDs) {
        return [NSString stringWithFormat:@"%@-%@-%@", kCDTISPrefix, label, TDCreateUUID()];
    }

    static volatile int64_t uniqueCounter;
    uint64_t val = OSAtomicIncrement64(&uniqueCounter);

    return [NSString stringWithFormat:@"%@-%@-%@-%llu", kCDTISPrefix, label, self.run, val];
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

static NSString *MakeMeta(NSString *s) { return [kCDTISMeta stringByAppendingString:s]; }

- (NSInteger)propertyTypeFromDoc:(NSDictionary *)body withName:(NSString *)name
{
    if (!self.objectModel) oops(@"no object model exists yet");

    NSString *entityName = body[kCDTISEntityNameKey];
    NSInteger ptype = [self.objectModel propertyTypeWithName:name withEntityName:entityName];
    return ptype;
}

- (CDTIndexType)indexTypeForKey:(NSString *)key inProperties:(NSDictionary *)props
{
    // our own keys are not in the core data properties
    // but we still want to index on them
    if ([key hasPrefix:kCDTISPrefix]) {
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
    [NSException raise:kCDTISException format:@"can't index on %@", name];
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
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@", kCDTISType, s);
            if (error) {
                NSDictionary *ui = @{NSLocalizedFailureReasonErrorKey : s};
                *error =
                    [NSError errorWithDomain:kCDTISErrorDomain code:CDTISErrorBadPath userInfo:ui];
            }
            return nil;
        }
    } else {
        if (![fileManager createDirectoryAtURL:self.localURL
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&err]) {
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: Error creating manager directory: %@",
                        kCDTISType, err);
            if (error) {
                *error = err;
            }
            return nil;
        }
    }
    return path;
}

#pragma mark - property encode
/**
 *  Create a dictionary (for JSON) that encodes an attribute.
 *  The array represents a tuple of strings:
 *  * type
 *  * _optional_ information
 *  * encoded object
 *
 *  @param attribute The attribute
 *  @param obj       The object
 *  @param error     Error
 *
 *  @return Encoded array
 */
- (NSDictionary *)encodeAttribute:(NSAttributeDescription *)attribute
                       withObject:(id)obj
                            error:(NSError **)error
{
    NSAttributeType type = attribute.attributeType;
    NSString *name = attribute.name;

    // Keep this
    if (!obj) oops(@"no nil allowed");

    switch (type) {
        case NSUndefinedAttributeType: {
            if (error) {
                NSString *str =
                    [NSString localizedStringWithFormat:@"%@ attribute type: %@",
                                                        kCDTISUndefinedAttributeType, @(type)];
                NSDictionary *ui = @{NSLocalizedDescriptionKey : str};
                *error = [NSError errorWithDomain:kCDTISErrorDomain
                                             code:CDTISErrorUndefinedAttributeType
                                         userInfo:ui];
            }
            return nil;
        }
        case NSStringAttributeType: {
            NSString *str = obj;
            return @{
                name : str,
            };
        }
        case NSBooleanAttributeType:
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
        case NSInteger64AttributeType: {
            NSNumber *num = obj;
            return @{
                name : num,
            };
        }
        case NSDateAttributeType: {
            NSDate *date = obj;
            NSNumber *since = [NSNumber numberWithDouble:[date timeIntervalSince1970]];
            return @{
                name : since,
            };
        }
        case NSBinaryDataAttributeType: {
            NSData *data = obj;
            return @{
                name : [data base64EncodedDataWithOptions:0],
                MakeMeta(name) : @{kCDTISMIMETypeKey : @"application/octet-stream"}
            };
            break;
        }
        case NSTransformableAttributeType: {
            NSString *xname = [attribute valueTransformerName];
            NSString *mimeType = @"application/octet-stream";
            Class myClass = NSClassFromString(xname);
            // Yes, we could try/catch here.. but why?
            if ([myClass respondsToSelector:@selector(MIMEType)]) {
                mimeType = [myClass performSelector:@selector(MIMEType)];
            }
            id xform = [[myClass alloc] init];
            // use reverseTransformedValue to come back
            NSData *save = [xform transformedValue:obj];
            NSString *bytes = [save base64EncodedStringWithOptions:0];

            return @{
                name : bytes,
                MakeMeta(name) : @{kCDTISTransformerClassKey : xname, kCDTISMIMETypeKey : mimeType}
            };
        }
        case NSObjectIDAttributeType: {
            // I don't think converting to a ref is needed, besides we
            // would need the entity id to decode.
            NSManagedObjectID *oid = obj;
            NSURL *uri = [oid URIRepresentation];
            return @{
                name : [uri absoluteString],
            };
        }
        case NSDecimalAttributeType: {
            NSDecimalNumber *dec = obj;
            NSString *desc = [dec description];
            NSDecimal val = [dec decimalValue];
            NSData *data = [NSData dataWithBytes:&val length:sizeof(val)];
            NSString *b64 = [data base64EncodedStringWithOptions:0];
            NSMutableDictionary *meta = [NSMutableDictionary dictionary];
            meta[kCDTISDecimalImageKey] = b64;

            if ([dec isEqual:[NSDecimalNumber notANumber]]) {
                meta[kCDTISFPNaNKey] = @"true";
                desc = @"0";
            }

            return @{name : desc, MakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]};
        }
        case NSDoubleAttributeType: {
            NSNumber *num = obj;
            double dbl = [num doubleValue];
            NSNumber *i64 = @(*(int64_t *)&dbl);
            NSMutableDictionary *meta = [NSMutableDictionary dictionary];
            meta[kCDTISDoubleImageKey] = i64;

            if ([num isEqual:@(INFINITY)]) {
                num = @(DBL_MAX);
                meta[kCDTISFPInfinityKey] = @"true";
            }
            if ([num isEqual:@(-INFINITY)]) {
                num = @(-DBL_MAX);
                meta[kCDTISFPNegInfinityKey] = @"true";
            }
            if ([num isEqual:@(NAN)]) {
                num = @(0);  // not sure what to do here
                dbl = 0.;
                meta[kCDTISFPNaNKey] = @"true";
            }

            // NSDecimalNumber "description" is the closest thing we will get
            // to an arbitrary precision number in JSON, so lets use it.
            NSDecimalNumber *dec = (NSDecimalNumber *)[NSDecimalNumber numberWithDouble:dbl];
            NSString *str = [dec description];
            return @{name : str, MakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]};
        }

        case NSFloatAttributeType: {
            NSNumber *num = obj;
            float flt = [num floatValue];
            NSNumber *i32 = @(*(int32_t *)&flt);
            NSMutableDictionary *meta = [NSMutableDictionary dictionary];
            meta[kCDTISFloatImageKey] = i32;

            if ([num isEqual:@(INFINITY)]) {
                num = @(FLT_MAX);
                meta[kCDTISFPInfinityKey] = @"true";
            }
            if ([num isEqual:@(-INFINITY)]) {
                num = @(-FLT_MAX);
                meta[kCDTISFPNegInfinityKey] = @"true";
            }
            if ([num isEqual:@(NAN)]) {
                num = @(0);  // not sure what to do here
                meta[kCDTISFPNaNKey] = @"true";
            }

            return @{name : num, MakeMeta(name) : [NSDictionary dictionaryWithDictionary:meta]};
        }

        default:
            break;
    }

    if (error) {
        NSString *str = [NSString
            localizedStringWithFormat:@"type %@: is not of " @"NSNumber: %@ = %@", @(type),
                                      attribute.name, NSStringFromClass([obj class])];
        *error = [NSError errorWithDomain:kCDTISErrorDomain
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
- (NSDictionary *)encodeRelationFromManagedObject:(NSManagedObject *)mo
{
    if (!mo) {
        return @{ kCDTISRelationNameKey : @"", kCDTISRelationReferenceKey : @"" };
    }

    NSEntityDescription *entity = [mo entity];
    NSString *entityName = [entity name];
    NSManagedObjectID *moid = [mo objectID];

    if (moid.isTemporaryID) oops(@"tmp");

    NSString *ref = [self referenceObjectForObjectID:moid];
    return @{kCDTISRelationNameKey : entityName, kCDTISRelationReferenceKey : ref};
}

/**
 *  Encode a complete relation, both "to-one" and "to-many"
 *
 *  @param rel   relation
 *  @param obj   object
 *  @param error error
 *
 *  @return the dictionary
 */
- (NSDictionary *)encodeRelation:(NSRelationshipDescription *)rel
                      withObject:(id)obj
                           error:(NSError **)error
{
    NSString *name = rel.name;

    if (!rel.isToMany) {
        NSManagedObject *mo = obj;
        NSDictionary *enc = [self encodeRelationFromManagedObject:mo];
        return @{
            name : enc,
        };
    }
    NSMutableArray *ids = [NSMutableArray array];
    for (NSManagedObject *mo in obj) {
        if (!mo) oops(@"nil mo");

        NSDictionary *enc = [self encodeRelationFromManagedObject:mo];
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
{
    NSError *err = nil;
    NSEntityDescription *entity = [mo entity];
    NSDictionary *propDic = [entity propertiesByName];
    NSArray *names = [propDic allKeys];

    NSMutableDictionary *props = [NSMutableDictionary dictionary];

    /* TODO
     * Should we bother with attachments?
     * I believe that CoreData deals with this and we should just treat
     * everything inline, otherwise we just add another unnecessary reference.
     */

    for (NSString *name in names) {
        id prop = propDic[name];
        if ([prop isTransient]) {
            continue;
        }
        if ([prop userInfo].count) {
            oops(@"there is user info.. what to do?");
        }
        id obj = [mo valueForKey:name];
        NSDictionary *enc = nil;
        if ([prop isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *att = prop;
            if (!obj) {
                // don't even process nil objects
                continue;
            }
            enc = [self encodeAttribute:att withObject:obj error:&err];
        } else if ([prop isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *rel = prop;
            enc = [self encodeRelation:rel withObject:obj error:&err];
        } else {
            [NSException raise:kCDTISException format:@"unknown property: %@", prop];
        }

        if (!enc) {
            [NSException raise:kCDTISException
                        format:@"There should always be an encoding: %@: %@", prop, err];
        }

        [props addEntriesFromDictionary:enc];
    }

    // just checking
    NSArray *entitySubs = [[mo entity] subentities];
    if ([entitySubs count] > 0) {
        CDTLogDebug(CDTDATASTORE_LOG_CONTEXT, @"%@: subentities: %@", kCDTISType, entitySubs);
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
         withContext:(NSManagedObjectContext *)context
{
    NSInteger type = [self propertyTypeFromDoc:body withName:name];

    // we defer to newValueForRelationship:forObjectWithID:withContext:error
    if (type == CDTISRelationToManyType) {
        return nil;
    }

    id prop = body[name];
    NSDictionary *meta = body[MakeMeta(name)];

    id obj;

    switch (type) {
        case NSStringAttributeType:
        case NSBooleanAttributeType:
            obj = prop;
            break;
        case NSDateAttributeType: {
            NSNumber *since = prop;
            obj = [NSDate dateWithTimeIntervalSince1970:[since doubleValue]];
        } break;
        case NSBinaryDataAttributeType: {
            NSString *str = prop;
            obj = [[NSData alloc] initWithBase64EncodedString:str options:0];
        } break;
        case NSTransformableAttributeType: {
            NSString *xname = meta[kCDTISTransformerClassKey];
            id xform = [[NSClassFromString(xname) alloc] init];
            NSString *base64 = prop;
            NSData *restore = nil;
            if ([base64 length]) {
                restore = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
            }
            // is the xform guaranteed to handle nil?
            obj = [xform reverseTransformedValue:restore];
        } break;
        case NSObjectIDAttributeType: {
            NSString *str = prop;
            NSURL *uri = [NSURL URLWithString:str];
            NSManagedObjectID *moid =
                [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
            obj = moid;
        } break;
        case NSDecimalAttributeType: {
            NSString *b64 = meta[kCDTISDecimalImageKey];
            NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
            NSDecimal val;
            [data getBytes:&val length:sizeof(val)];
            obj = [NSDecimalNumber decimalNumberWithDecimal:val];
        } break;
        case NSDoubleAttributeType: {
            // just get the image
            NSNumber *i64Num = meta[kCDTISDoubleImageKey];
            int64_t i64 = [i64Num longLongValue];
            NSNumber *num = @(*(double *)&i64);
            obj = num;
        } break;
        case NSFloatAttributeType: {
            // just get the image
            NSNumber *i32Num = meta[kCDTISFloatImageKey];
            int32_t i32 = (int32_t)[i32Num integerValue];
            NSNumber *num = @(*(float *)&i32);
            obj = num;
        } break;
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
        case NSInteger64AttributeType: {
            NSNumber *num = prop;
            obj = num;
        } break;
        case CDTISRelationToOneType: {
            NSDictionary *enc = prop;
            NSString *entityName = enc[kCDTISRelationNameKey];
            if (entityName.length == 0) {
                obj = [NSNull null];
            } else {
                NSString *ref = enc[kCDTISRelationReferenceKey];
                NSManagedObjectID *moid =
                    [self decodeRelationFromEntityName:entityName withRef:ref withContext:context];
                // we cannot return nil
                if (!moid) {
                    obj = [NSNull null];
                } else {
                    obj = moid;
                }
            }
        } break;
        case CDTISRelationToManyType:
            oops(@"this is deferred to newValueForRelationship");
            break;
        default:
            oops(@"unknown encoding: %@", @(type));
            break;
    }

    return obj;
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

    CDTMutableDocumentRevision *newRev = [CDTMutableDocumentRevision revision];

    // do the actual attributes first
    newRev.docId = docID;
    newRev.body = [self propertiesFromManagedObject:mo];
    newRev.body[kCDTISTypeKey] = kCDTISTypeProperties;
    newRev.body[kCDTISObjectVersionKey] = @"1";
    newRev.body[kCDTISEntityNameKey] = [entity name];
    newRev.body[kCDTISIdentifierKey] = [[[mo objectID] URIRepresentation] absoluteString];

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
    NSString *docID = [self stringReferenceObjectForObjectID:moid];

    NSEntityDescription *entity = [mo entity];
    NSDictionary *propDic = [entity propertiesByName];

    NSMutableDictionary *props = [NSMutableDictionary dictionary];
    NSDictionary *changed = [mo changedValues];

    for (NSString *name in changed) {
        NSDictionary *enc = nil;
        id prop = propDic[name];
        if ([prop isTransient]) {
            continue;
        }
        if ([prop isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *att = prop;

            enc = [self encodeAttribute:att withObject:changed[name] error:&err];
        } else if ([prop isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *rel = prop;
            enc = [self encodeRelation:rel withObject:changed[name] error:&err];
        } else {
            oops(@"bad prop?");
        }
        [props addEntriesFromDictionary:enc];
    }

    // :( It makes me very sad that I have to fetch it
    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev) {
        if (error) *error = err;
        return NO;
    }

    // TODO: version HACK
    NSString *oldVersion = oldRev.body[kCDTISObjectVersionKey];
    uint64_t version = [oldVersion longLongValue];
    ++version;
    NSNumber *v = [NSNumber numberWithUnsignedLongLong:version];
    props[kCDTISObjectVersionKey] = [v stringValue];

    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    // delete all changed properties, in case they are being removed.
    [upRev.body removeObjectsForKeys:[props allKeys]];
    [upRev.body addEntriesFromDictionary:props];

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        return NO;
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
 *  @param mo    Managed Object
 *  @param error Error
 *
 *  @return YES/NO
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
 *  Create a dictionary of values for a the attributes of a Managed Object from
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
    NSArray *keys = [rev.body allKeys];
    for (NSString *name in keys) {
        if ([name isEqualToString:kCDTISObjectVersionKey]) {
            *version = [rev.body[name] longLongValue];
            continue;
        }
        if ([name hasPrefix:kCDTISPrefix]) {
            continue;
        }

        id obj = [self decodeProperty:name fromDoc:rev.body withContext:context];
        if (!obj) {
            // Dictionaries do not take nil, but Values can't have NSNull.
            // Apparently we just skip it and the properties faults take care
            // of it
            continue;
        }
        values[name] = obj;
    }

    return [NSDictionary dictionaryWithDictionary:values];
}

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

            *error = [NSError errorWithDomain:kCDTISErrorDomain
                                         code:CDTISErrorSyncBusy
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        return NO;
    }

    if (self.progressBlock) {
        if (error) {
            NSString *s =
                [NSString localizedStringWithFormat:@"Replicator comm already in progress"];

            *error = [NSError errorWithDomain:kCDTISErrorDomain
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
        CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@: Replicator: start: %@: %@", kCDTISType,
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

            *error = [NSError errorWithDomain:kCDTISErrorDomain
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

            *error = [NSError errorWithDomain:kCDTISErrorDomain
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
                   kCDTISType);
        return NO;
    }

    NSString *clean = [self cleanURL:remoteURL];

    CDTReplicatorFactory *repFactory =
        [[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];
    if (!repFactory) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create replication factory",
                    kCDTISType, clean);
        return NO;
    }

    CDTPushReplication *pushRep =
        [CDTPushReplication replicationWithSource:datastore target:remoteURL];
    if (!pushRep) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create push replication object",
                    kCDTISType, clean);
        return NO;
    }

    CDTReplicator *pusher = [repFactory oneWay:pushRep error:&err];
    if (!pusher) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create replicator for push: %@",
                    kCDTISType, clean, err);
        return NO;
    }

    CDTPullReplication *pullRep =
        [CDTPullReplication replicationWithSource:remoteURL target:datastore];
    if (!pullRep) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create pull replication object",
                    kCDTISType, clean);
        return NO;
    }

    CDTReplicator *puller = [repFactory oneWay:pullRep error:&err];
    if (!puller) {
        CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: Could not create replicator for pull: %@",
                    kCDTISType, clean, err);
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
    NSString *databaseName = [remoteURL lastPathComponent];
    NSString *path = [self pathToDBDirectory:&err];
    if (!path) {
        if (error) *error = err;
        return NO;
    }

    CDTDatastoreManager *manager = [[CDTDatastoreManager alloc] initWithDirectory:path error:&err];
    if (!manager) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: Error creating manager: %@", kCDTISType,
                    databaseName, err);
        if (error) *error = err;
        return NO;
    }

    CDTDatastore *datastore = [manager datastoreNamed:databaseName error:&err];
    if (!datastore) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: Error creating datastore: %@", kCDTISType,
                    databaseName, err);
        if (error) *error = err;
        return NO;
    }

    CDTIndexManager *indexManager =
        [[CDTIndexManager alloc] initWithDatastore:datastore error:&err];
    if (!indexManager) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: Cannot create indexManager: %@", kCDTISType,
                    databaseName, err);
        return NO;
    }

    // Commit before setting up replication
    self.databaseName = databaseName;
    self.datastore = datastore;
    self.manager = manager;
    self.indexManager = indexManager;

    if (![self setupReplicators:remoteURL manager:manager datastore:datastore]) {
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: continuing without replication", kCDTISType);
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
    if (![self.indexManager ensureIndexedWithIndexName:kCDTISEntityNameKey
                                             fieldName:kCDTISEntityNameKey
                                                 error:&err]) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: cannot create default index: %@",
                    kCDTISType, self.databaseName, err);
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
- (NSDictionary *)encodeVersionHashes:(NSDictionary *)hashes
{
    NSMutableDictionary *newHashes = [NSMutableDictionary dictionary];
    for (NSString *hash in hashes) {
        NSData *h = hashes[hash];
        NSString *s = stringFromData(h);
        newHashes[hash] = s;
    }
    return [NSDictionary dictionaryWithDictionary:newHashes];
}

/**
 *  Update the metaData for CoreData in our own database
 *
 *  @param docID The docID for the metaData object in our database
 *  @param error error
 *
 *  @return YES/NO
 */
- (BOOL)updateMetaDataWithDocID:(NSString *)docID error:(NSError **)error
{
    NSError *err = nil;
    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: no metaData?: %@", kCDTISType,
                    self.databaseName, err);
        return NO;
    }
    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    // need to fix up the version hashed
    NSMutableDictionary *metaData = [[self metadata] mutableCopy];
    NSDictionary *hashes = metaData[NSStoreModelVersionHashesKey];

    // hashes are inline data and need to be converted
    if (hashes) {
        metaData[NSStoreModelVersionHashesKey] = [self encodeVersionHashes:hashes];
    }
    upRev.body[kCDTISMetaDataKey] = [NSDictionary dictionaryWithDictionary:metaData];

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: could not update metadata: %@", kCDTISType,
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
- (NSDictionary *)decodeVersionHashes:(NSDictionary *)hashes
{
    NSMutableDictionary *newHashes = [NSMutableDictionary dictionary];
    for (NSString *hash in hashes) {
        NSString *s = hashes[hash];
        NSData *h = dataFromString(s);
        newHashes[hash] = h;
    }
    return [NSDictionary dictionaryWithDictionary:newHashes];
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
        self.run = @"1";

        NSString *uuid = [self uniqueID:@"NSStore"];
        NSDictionary *metaData = @{NSStoreUUIDKey : uuid, NSStoreTypeKey : [self type]};

        NSPersistentStoreCoordinator *psc = self.persistentStoreCoordinator;
        NSManagedObjectModel *mom = psc.managedObjectModel;
        self.objectModel = [[CDTISObjectModel alloc] initWithManagedObjectModel:mom];
        NSDictionary *omd = [self.objectModel dictionary];

        // store it so we can get it back the next time
        CDTMutableDocumentRevision *newRev = [CDTMutableDocumentRevision revision];
        newRev.docId = kCDTISMetaDataDocID;
        newRev.body = @{
            kCDTISTypeKey : kCDTISTypeMetadata,
            kCDTISMetaDataKey : metaData,
            kCDTISObjectModelKey : omd,
            kCDTISRunKey : self.run,
        };

        rev = [self.datastore createDocumentFromRevision:newRev error:&err];
        if (!rev) {
            if (error) *error = err;
            CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: unable to store metaData: %@",
                        kCDTISType, self.databaseName, err);
            return nil;
        }

        return metaData;
    }

    NSDictionary *omd = rev.body[kCDTISObjectModelKey];
    self.objectModel = [[CDTISObjectModel alloc] initWithDictionary:omd];

    NSDictionary *oldMetaData = rev.body[kCDTISMetaDataKey];
    NSString *run = rev.body[kCDTISRunKey];
    uint64_t runVal = [run longLongValue];
    ++runVal;
    self.run = [NSString stringWithFormat:@"%llu", runVal];

    CDTMutableDocumentRevision *upRev = [rev mutableCopy];
    upRev.body[kCDTISRunKey] = self.run;
    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        CDTLogError(CDTDATASTORE_LOG_CONTEXT, @"%@: %@: upedRev: %@", kCDTISType, self.databaseName,
                    err);
        return nil;
    }

    NSMutableDictionary *newMetaData = [oldMetaData mutableCopy];
    NSMutableDictionary *hashes = [newMetaData[NSStoreModelVersionHashesKey] mutableCopy];

    // hashes are encoded and need to be inline data
    if (hashes) {
        newMetaData[NSStoreModelVersionHashesKey] = [self decodeVersionHashes:hashes];
    }

    NSDictionary *metaData = [NSDictionary dictionaryWithDictionary:newMetaData];
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
    if (![s isEqualToString:kCDTISType]) {
        NSString *e = [NSString localizedStringWithFormat:@"Unexpected store type %@", s];
        if (error) {
            NSDictionary *ui = @{NSLocalizedFailureReasonErrorKey : e};
            *error = [NSError errorWithDomain:kCDTISErrorDomain code:CDTISErrorBadPath userInfo:ui];
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
    if (![self updateMetaDataWithDocID:kCDTISMetaDataDocID error:&err]) {
        [NSException raise:kCDTISException format:@"update metadata error: %@", err];
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
            CDTLogWarn(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: state: %@", kCDTISType,
                       [self cleanURL:self.remoteURL], replicator, state);
            break;
    }

    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: state: %@", kCDTISType,
               [self cleanURL:self.remoteURL], replicator, state);
}

/**
 * Called whenever the replicator changes progress
 */
- (void)replicatorDidChangeProgress:(CDTReplicator *)replicator
{
    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: progressed: [%@/%@]", kCDTISType,
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
    CDTLogInfo(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: completed", kCDTISType,
               [self cleanURL:self.remoteURL], replicator);
    self.progressBlock(YES, 0, 0, nil);
    self.progressBlock = nil;
}

/**
 * Called when a state transition to ERROR is completed.
 */
- (void)replicatorDidError:(CDTReplicator *)replicator info:(NSError *)info
{
    CDTLogError(CDTREPLICATION_LOG_CONTEXT, @"%@: %@: %@: suffered error: %@", kCDTISType,
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
    NSDictionary *metaData = [self getMetaDataFromDocID:kCDTISMetaDataDocID error:error];
    if (!metaData) {
        return NO;
    }
    if (![self checkMetaData:metaData error:error]) {
        [NSException raise:kCDTISException format:@"failed metaData check"];
    }
    // go directly to super
    [super setMetadata:metaData];

    // this class only exists in iOS
    Class frc = NSClassFromString(@"NSFetchedResultsController");
    if (frc) {
        // If there is a cache for this, it is likely stale.
        // Sadly, we do not know the name of it, so we blow them all away
        [frc performSelector:@selector(deleteCacheWithName:) withObject:nil];
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
                [NSException raise:kCDTISException format:@"we do not allow custom compares"];
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
 *  > *Warning*: completely untested right now
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
        key = kCDTISIdentifierKey;
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
                [NSException raise:kCDTISException format:@"Can't do substring matches: %@", value];
                break;
            }
            // FIXME? I hope this deals with collections
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
                [NSException raise:kCDTISException format:@"unexpected \"between\" args"];
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
            [NSException raise:kCDTISException
                        format:@"Predicate with unsupported comparison operator: %@", @(predType)];
            break;

        default:
            [NSException raise:kCDTISException
                        format:@"Predicate with unrecognized comparison operator: %@", @(predType)];
            break;
    }

    NSError *err = nil;

    CDTIndexType type = [self indexTypeForKey:keyStr inProperties:props];

    if (![self ensureIndexExists:keyStr fieldName:keyStr type:type error:&err]) {
        [NSException raise:kCDTISException format:@"failed at creating index for key %@", keyStr];
        // it is unclear what happens if I perform a query with no index
        // I think we should let the backing store deal with it.
    }
    return result;
}

- (NSDictionary *)processPredicate:(NSPredicate *)p withProperties:(NSDictionary *)props
{
    if ([p isKindOfClass:[NSCompoundPredicate class]]) {
        if (!CDTISSupportCompoundPredicates) {
            [NSException raise:kCDTISException
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
                     raise:kCDTISException
                    format:@"Predicate with unsupported compound operator: %@", @(predType)];
                break;
            default:
                [NSException
                     raise:kCDTISException
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

    NSMutableDictionary *query = [@{ kCDTISEntityNameKey : entityName } mutableCopy];
    NSDictionary *predicate = [self processPredicate:fetchRequest];
    [query addEntriesFromDictionary:predicate];

    return [NSDictionary dictionaryWithDictionary:query];
}

- (NSArray *)fetchDictionaryResult:(NSFetchRequest *)fetchRequest withHits:(CDTQueryResult *)hits
{
    // we only support one grouping
    if ([fetchRequest.propertiesToGroupBy count] > 1) {
        [NSException raise:kCDTISException format:@"can only group by 1 property"];
    }

    id groupProp = [fetchRequest.propertiesToGroupBy firstObject];

    // we only support grouping by an existing property, no expressions or
    // aggregates
    if (![groupProp isKindOfClass:[NSPropertyDescription class]]) {
        [NSException raise:kCDTISException format:@"can only handle properties for groupings"];
    }

    // use a dictionary so we can track repeates
    NSString *groupKey = [groupProp name];
    NSMutableDictionary *group = [NSMutableDictionary dictionary];
    for (CDTDocumentRevision *rev in hits) {
        id obj = rev.body[groupKey];
        NSArray *revList = group[obj];
        if (revList) {
            group[obj] = [revList arrayByAddingObject:rev];
        } else {
            group[obj] = @[ rev ];
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
                    [NSException raise:kCDTISException format:@"expression type is not a function"];
                }
                if (![e.function isEqualToString:@"count:"]) {
                    [NSException raise:kCDTISException
                                format:@"count: is the only function currently supported"];
                }
                dic[ed.name] = @([ga count]);
            } else {
                [NSException raise:kCDTISException format:@"unsupported property descriptor"];
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
    NSEntityDescription *entity = [fetchRequest entity];

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
    // hits == nil is valie, get rid of this once tested
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
        *error = [NSError errorWithDomain:kCDTISErrorDomain
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
        if (![self updateMetaDataWithDocID:kCDTISMetaDataDocID error:&err]) {
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
        *error = [NSError errorWithDomain:kCDTISErrorDomain
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

    switch (type) {
        case CDTISRelationToOneType: {
            NSDictionary *rel = rev.body[name];
            NSString *entityName = rel[kCDTISRelationNameKey];
            NSString *ref = rel[kCDTISRelationReferenceKey];
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
            for (NSDictionary *oid in oids) {
                NSString *entityName = oid[kCDTISRelationNameKey];
                NSString *ref = oid[kCDTISRelationReferenceKey];
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
            [self newObjectIDForEntity:e referenceObject:[self uniqueID:e.name]];
        [objectIDs addObject:moid];
    }
    return objectIDs;
}

#pragma mark - DOT
/**
 *  Quick function to write an `NSString` in UTF8 format.
 *
 *  @param out Object to write to.
 *  @param s   The string to write.
 */
static void DotWrite(NSMutableData *out, NSString *s)
{
    [out appendBytes:[s UTF8String] length:[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
}

/**
 *  This is a quick hack which lets me dump the storage graph visually.
 *  It uses [Graphviz](http://www.graphviz.org/) "dot" format.
 *
 *  Once you have a database configured, in any form, you can simply call:
 *      [self dotMe]
 *
 *  What you get:
 *  * You may call this from your code or from the debugger (LLDB).
 *  * The result is stored as `self.dotData` which is an `NSData` object`
 *  ** You can then use your favorite `writeTo` method.
 *  * dotMe returns
 *  > *Warning*: this replaces contents of an existing file but does not
 *  > truncate it. So if the original file was bigger there will be garbage
 *  > at the end.
 *
 *  @return A string that is the debugger command to dump the result
 *   into a file on the host.
 */
- (NSString *)dotMe __attribute__((used))
{
    if (!self.datastore) {
        return @"FAIL";
    }
    NSArray *all = [self.datastore getAllDocuments];
    NSMutableData *out = [NSMutableData data];

    DotWrite(out, @"strict digraph CDTIS {\n");
    DotWrite(out, @"  overlap=false;\n");
    DotWrite(out, @"  splines=true;\n");

    for (CDTDocumentRevision *rev in all) {
        NSString *type = rev.body[kCDTISTypeKey];
        if ([type isEqualToString:kCDTISTypeProperties]) {
            NSString *entity = nil;
            NSMutableArray *props = [NSMutableArray array];

            for (NSString *name in rev.body) {
                if ([name isEqual:kCDTISEntityNameKey]) {
                    // the node
                    entity = rev.body[name];
                }

                if ([name hasPrefix:kCDTISPrefix]) {
                    continue;
                }
                id value = rev.body[name];
                NSDictionary *meta = rev.body[MakeMeta(name)];
                NSInteger ptype = [self propertyTypeFromDoc:rev.body withName:name];

                size_t idx = [props count] + 1;
                switch (ptype) {
                    case CDTISRelationToOneType: {
                        NSDictionary *rel = value;
                        NSString *str = rel[kCDTISRelationReferenceKey];
                        [props addObject:[NSString stringWithFormat:@"<%zu> to-one", idx]];
                        DotWrite(
                            out,
                            [NSString
                                stringWithFormat:
                                    @"  \"%@\":%zu -> \"%@\":0 [label=\"one\", color=\"blue\"];\n",
                                    rev.docId, idx, str]);
                    } break;
                    case CDTISRelationToManyType: {
                        NSArray *rels = value;
                        [props addObject:[NSString stringWithFormat:@"<%zu> to-many", idx]];
                        DotWrite(out,
                                 [NSString stringWithFormat:@"  \"%@\":%zu -> { ", rev.docId, idx]);
                        for (NSDictionary *rel in rels) {
                            NSString *str = rel[kCDTISRelationReferenceKey];
                            DotWrite(out, [NSString stringWithFormat:@"\"%@\":0 ", str]);
                        }
                        DotWrite(out, @"} [label=\"many\", color=\"red\"];\n");
                    } break;
                    case NSDecimalAttributeType: {
                        NSString *str = value;
                        NSDecimalNumber *dec = [NSDecimalNumber decimalNumberWithString:str];
                        double dbl = [dec doubleValue];
                        [props
                            addObject:[NSString stringWithFormat:@"<%zu> %@:%e", idx, name, dbl]];
                    } break;
                    case NSInteger16AttributeType:
                    case NSInteger32AttributeType:
                    case NSInteger64AttributeType: {
                        NSNumber *num = value;
                        [props
                            addObject:[NSString stringWithFormat:@"<%zu> %@:%@", idx, name, num]];
                    } break;
                    case NSFloatAttributeType: {
                        NSNumber *i32Num = meta[kCDTISFloatImageKey];
                        int32_t i32 = (int32_t)[i32Num integerValue];
                        float flt = *(float *)&i32;
                        [props
                            addObject:[NSString stringWithFormat:@"<%zu> %@:%f", idx, name, flt]];
                    } break;
                    case NSDoubleAttributeType: {
                        NSNumber *i64Num = meta[kCDTISDoubleImageKey];
                        int64_t i64 = [i64Num integerValue];
                        double dbl = *(double *)&i64;
                        [props
                            addObject:[NSString stringWithFormat:@"<%zu> %@:%f", idx, name, dbl]];
                    } break;
                    case NSStringAttributeType: {
                        NSString *str = value;
                        if ([str length] > 16) {
                            str = [NSString stringWithFormat:@"%@...", [str substringToIndex:16]];
                        }
                        str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                        [props
                            addObject:[NSString stringWithFormat:@"<%zu> %@: %@", idx, name, str]];
                    } break;
                    default:
                        [props addObject:[NSString stringWithFormat:@"<%zu> %@:*", idx, name]];
                        break;
                }
            }

            if (!entity) oops(@"no entity name?");
            DotWrite(out, [NSString stringWithFormat:@"  \"%@\" [shape=record, label=\"{ <0> %@ ",
                                                     rev.docId, entity]);

            for (NSString *p in props) {
                DotWrite(out, [NSString stringWithFormat:@"| %@ ", p]);
            }
            DotWrite(out, @"}\" ];\n");

        } else if ([type isEqualToString:kCDTISTypeMetadata]) {
            // DotWrite(out, node);

        } else {
            oops(@"unknown type: %@", type);
        }
    }
    DotWrite(out, @"}\n");

    self.dotData = [NSData dataWithData:out];
    size_t length = [self.dotData length];
    return [NSString stringWithFormat:@"memory read --force --binary --outfile "
                                      @"/tmp/CDTIS.dot --count %zu %p",
                                      length, [self.dotData bytes]];
}

@end
