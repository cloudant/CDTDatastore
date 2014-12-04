//
//  CDTIncrementalStore.m
//
//
//  Created by Jimi Xenidis on 11/18/14.
//
//

#import <Foundation/Foundation.h>
#import <libkern/OSAtomic.h>

#import "CDTIncrementalStore.h"
#import "CDTFieldIndexer.h"

#pragma mark - properties
@interface CDTIncrementalStore ()

@property (nonatomic, strong) NSString *databaseName;
@property (nonatomic, strong) CDTDatastoreManager *manager;
@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) CDTReplicatorFactory *replicatorFactory;
@property (nonatomic, strong) NSURL *localURL;
@property (nonatomic, strong) CDTIndexManager *indexManager;

/**
 *  Helps us with our bogus [uniqueID](@ref uniqueID)
 */
@property (nonatomic, strong) NSString *run;

/**
 *  Don't think we need this but we keep it for now
 */
@property (nonatomic, strong) NSMutableDictionary *revIDFromDocID;

@end

#pragma mark - string constants
static NSString *const kCDTISType = @"CDTIncrementalStore";
static NSString *const kCDTISErrorDomain = @"CDTIncrementalStoreDomain";
static NSString *const kCDTISDirectory = @"cloudant-sync-datastore-incremental";
static NSString *const kCDTISPrefix = @"CDTIS";
static NSString *const kCDTISEscape = @"CDTISEscape";
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

#define kCDTISNumberPrefix @"number_"
static NSString *const kCDTISInteger16AttributeType = kCDTISNumberPrefix @"int16";
static NSString *const kCDTISInteger32AttributeType = kCDTISNumberPrefix @"int32";
static NSString *const kCDTISInteger64AttributeType = kCDTISNumberPrefix @"int64";
static NSString *const kCDTISFloatAttributeType = kCDTISNumberPrefix @"float";
static NSString *const kCDTISDoubleAttributeType = kCDTISNumberPrefix @"double";

static NSString *const kCDTISDecimalAttributeType = @"decimal";
static NSString *const kCDTISStringAttributeType = @"utf8";
static NSString *const kCDTISBooleanAttributeType = @"bool";
static NSString *const kCDTISDateAttributeType = @"date1970";
static NSString *const kCDTISBinaryDataAttributeType = @"base64";
static NSString *const kCDTISTransformableAttributeType = @"xform";
static NSString *const kCDTISObjectIDAttributeType = @"id";
static NSString *const kCDTISRelationToOneType = @"relation-to-one";
static NSString *const kCDTISRelationToManyType = @"relation-to-many";

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
    CDTISErrorNotSupported
};

#pragma mark - Code selection
// allows selection of different code paths
// Use this instead of ifdefs so the code are actually gets compiled
/**
 *  This allows UIDs for individual objects to be readable.
 *  Useful for debugging
 */
static BOOL CDTISReadableUUIDs = YES;

/**
 *  If true, will simply delete the database object with no considerations
 */
static BOOL CDTISDeleteAggresively = NO;

#pragma mark - oops macro for debug
/**
 *  This is how I like to assert, it stops me in the debugger
 *
 *  @param fmt A format string
 *  @param ... A comma-separated list of arguments to substitute into format.
 */
#define oops(fmt, ...)                                                            \
    do {                                                                          \
        NSLog(@"%s:%u OOPS: %@", __FILE__, __LINE__, NSStringFromSelector(_cmd)); \
        NSLog(fmt, ##__VA_ARGS__);                                                \
        __builtin_trap();                                                         \
    } while (NO);

@implementation CDTIncrementalStore

#pragma mark - getters/setters
- (NSMutableDictionary *)revIDFromDocID
{
    if (!_revIDFromDocID) {
        _revIDFromDocID = [NSMutableDictionary dictionary];
    }
    return _revIDFromDocID;
}

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
}

+ (NSString *)type
{
    return kCDTISType;
}

#pragma mark - Utils
/**
 *  Generate a unique identifier
 *
 *  @return A unique ID
 */
- (NSString *)uniqueID
{
    /**
     *  @See CDTISReadableUUIDs
     */
    if (!CDTISReadableUUIDs) {
        return [NSString stringWithFormat:@"%@-%@",
                kCDTISPrefix, TDCreateUUID()];
    }

    static volatile int64_t uniqueCounter;
    uint64_t val = OSAtomicIncrement64(&uniqueCounter);

    return [NSString stringWithFormat:@"%@-%@-%llu",
            kCDTISPrefix, self.run, val];
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

#pragma mark - File System
/**
 *  Create a path to the directory for the local database
 *
 *  @param dirName Name of the directory
 *  @param error   error
 *
 *  @return The path
 */
- (NSString *)pathToDBDirectory:(NSString *)dirName error:(NSError **)error
{
    NSError *err = nil;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsDir =
        [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    self.localURL = [documentsDir URLByAppendingPathComponent:dirName];
    NSString *path = [self.localURL path];

    BOOL isDir;
    BOOL exists = [fileManager fileExistsAtPath:path isDirectory:&isDir];

    if (exists) {
        if (!isDir) {
            NSString *s = [NSString
                localizedStringWithFormat:
                    @"Can't create datastore directory: file in the way at %@", self.localURL];
            NSLog(@"%@", s);
            if (error) {
                *error = [NSError errorWithDomain:kCDTISErrorDomain
                                             code:CDTISErrorBadPath
                                         userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
            }
            return nil;
        }
    } else {
        if (![fileManager createDirectoryAtURL:self.localURL
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&err]) {
            NSLog(@"Error creating manager directory: %@", err);
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
 *  Create an array (for JSON) that encodes an attribute.
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
- (NSArray *)encodeAttribute:(NSAttributeDescription *)attribute
                  withObject:(id)obj
                       error:(NSError **)error
{
    NSAttributeType type = attribute.attributeType;

    if (!obj) oops(@"no nil allowed");

    switch (type) {
        case NSUndefinedAttributeType: {
            if (error) {
                NSString *str =
                    [NSString
                     localizedStringWithFormat:@"%@ attribute type: %@",
                     kCDTISUndefinedAttributeType, @(type)];
                *error = [NSError errorWithDomain:kCDTISErrorDomain
                                             code:CDTISErrorUndefinedAttributeType
                                         userInfo:@{NSLocalizedDescriptionKey : str}];
            }
            return nil;
        }
        case NSStringAttributeType: {
            NSString *str = obj;
            return @[ kCDTISStringAttributeType, str ];
        }
        case NSBooleanAttributeType: {
            NSNumber *b = obj;
            return @[ kCDTISBooleanAttributeType, b ];
        }
        case NSDateAttributeType: {
            NSDate *date = obj;
            NSNumber *since = [NSNumber numberWithDouble:[date timeIntervalSince1970]];
            return @[ kCDTISDateAttributeType, since ];
        }
        case NSBinaryDataAttributeType: {
            NSData *data = obj;
            return @[ kCDTISBinaryDataAttributeType, [data base64EncodedDataWithOptions:0] ];
            break;
        }
        case NSTransformableAttributeType: {
            NSString *xname = [attribute valueTransformerName];
            id xform = [[NSClassFromString(xname) alloc] init];
            // use reverseTransformedValue to come back
            NSData *save = [xform transformedValue:obj];
            NSString *bytes = [save base64EncodedStringWithOptions:0];
            return @[
                kCDTISTransformableAttributeType,
                xname,
                bytes
            ];
        }
        case NSObjectIDAttributeType: {
            // I'm guessing here
            if (![obj isKindOfClass:[NSManagedObjectID class]]) {
                oops(@"I guessed wrong");
            }
            // I don't think converting to a ref is needed, besides we
            // would need the entity id to decode.
            NSManagedObjectID *oid = obj;
            NSURL *uri = [oid URIRepresentation];
            return @[ kCDTISObjectIDAttributeType, [uri absoluteString] ];
        }
        case NSDecimalAttributeType: {
            NSDecimalNumber *dec = obj;
            NSString *desc = [dec description];
            return @[ kCDTISDecimalAttributeType, desc ];
        }
        case NSDoubleAttributeType:{
            NSNumber *num = obj;
            NSString *str = [num stringValue];
            return @[ kCDTISDoubleAttributeType, str];
        }

        case NSFloatAttributeType:{
            NSNumber *num = obj;
            NSString *str = [num stringValue];
            return @[ kCDTISFloatAttributeType, str];
        }

        case NSInteger16AttributeType:{
            NSNumber *num = obj;
            NSString *str = [num stringValue];
            return @[ kCDTISInteger16AttributeType, str];
        }

        case NSInteger32AttributeType:{
            NSNumber *num = obj;
            NSString *str = [num stringValue];
            return @[ kCDTISInteger32AttributeType, str];
        }

        case NSInteger64AttributeType: {
            NSNumber *num = obj;
            NSString *str = [num stringValue];
            return @[ kCDTISInteger64AttributeType, str];
        }
        default: {
            if (error) {
                NSString *str = [NSString
                                 localizedStringWithFormat:@"type %@: is not of NSNumber: %@ = %@", @(type),
                                 attribute.name, NSStringFromClass([obj class])];
                *error = [NSError errorWithDomain:kCDTISErrorDomain
                                             code:CDTISErrorNaN
                                         userInfo:@{NSLocalizedDescriptionKey : str}];
            }
            return nil;
        }
    }
    oops(@"should never get here");
    return nil;
}

/**
 *  Encode a relation as a tuple of strings:
 *  * entity name
 *  * ref/docID
 *
 *  > *Note*: the entity name is necessary for decoding
 *
 *  @param mo Managed Object
 *
 *  @return the tuple
 */
- (NSArray *)encodeRelationFromManagedObject:(NSManagedObject *)mo
{
    if (!mo) {
        return @[ @"", @"" ];
    }

    NSEntityDescription *entity = [mo entity];
    NSString *entityName = [entity name];
    NSManagedObjectID *moid = [mo objectID];
    if (moid.isTemporaryID) oops(@"tmp");
    NSString *ref = [self referenceObjectForObjectID:moid];
    return @[ entityName, ref ];
}

/**
 *  Encode a complete relation, both "to-one" and "to-many"
 *
 *  @param rel   relation
 *  @param obj   object
 *  @param error error
 *
 *  @return the tuple
 */
- (NSArray *)encodeRelation:(NSRelationshipDescription *)rel
                 withObject:(id)obj
                      error:(NSError **)error
{
    if (!rel.isToMany) {
        NSArray *ret = @[kCDTISRelationToOneType];
        NSManagedObject *mo = obj;
        NSArray *enc = [self encodeRelationFromManagedObject:mo];
        ret = [ret arrayByAddingObjectsFromArray:enc];
        return ret;
    }
    NSMutableArray *ids = [NSMutableArray array];
    for (NSManagedObject *mo in obj) {
        if (!mo) oops(@"nil mo");

        NSArray *enc = [self encodeRelationFromManagedObject:mo];
        [ids addObject:enc];
    }
    return @[ kCDTISRelationToManyType, ids];
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
     * everything inline, otherwise we just add another unecessary reference.
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
        id enc = nil;
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
            oops(@"bad prop?");
        }
        if (!enc) {
            oops(@"%@", err);
        }
        props[name] = enc;
    }
    // just checking
    NSArray *entitySubs = [[mo entity] subentities];
    if ([entitySubs count] > 0) {
        NSLog(@"XXX %@", entitySubs);
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
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName
                                              inManagedObjectContext:context];
    NSManagedObjectID *moid = [self newObjectIDForEntity:entity
                                         referenceObject:ref];
    return moid;
}

/**
 *  Get the object from a property encoded with
 *  [propertiesFromManagedObject](@ref propertiesFromManagedObject)
 *
 *  @param prop    <#prop description#>
 *  @param context <#context description#>
 *
 *  @return <#return value description#>
 */
- (id)decodePropertyFrom:(NSArray *)prop
             withContext:(NSManagedObjectContext *)context
{
    NSString *type = [prop firstObject];
    id value = [prop objectAtIndex:1];
    id obj = nil;
    if ([type isEqualToString:kCDTISStringAttributeType]) {
        obj = value;

    } else if ([type isEqualToString:kCDTISBooleanAttributeType]) {
        NSNumber *bn = value;
        obj = bn;

    } else if ([type isEqualToString:kCDTISDateAttributeType]) {
        NSNumber *since = value;
        obj = [NSDate dateWithTimeIntervalSince1970:[since doubleValue]];

    } else if ([type isEqualToString:kCDTISBinaryDataAttributeType]) {
        NSString *str = value;
        obj = [[NSData alloc] initWithBase64EncodedString:str options:0];

    } else if ([type isEqualToString:kCDTISTransformableAttributeType]) {
        NSString *str = value;
        id xform = [[NSClassFromString(str) alloc] init];
        NSString *base64 = [prop objectAtIndex:2];
        NSData *restore = nil;
        if ([base64 length]) {
            restore = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
        }
        // is the xform guaranteed to handle nil?
        obj = [xform reverseTransformedValue:restore];

    } else if ([type isEqualToString:kCDTISObjectIDAttributeType]) {
        NSString *str = value;
        oops(@"guessing");
        NSURL *uri = [NSURL URLWithString:str];
        NSManagedObjectID *moid =
            [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
        obj = moid;

    } else if ([type isEqualToString:kCDTISDecimalAttributeType]) {
        NSString *str = value;
        obj = [NSDecimalNumber decimalNumberWithString:str];

    } else if ([type hasPrefix:kCDTISNumberPrefix]) {
        NSString *str = value;
        NSNumber *num;
        if ([type isEqualToString:kCDTISDoubleAttributeType]) {
            double dbl = [str doubleValue];
            num = [NSNumber numberWithDouble:dbl];
        } else if ([type isEqualToString:kCDTISFloatAttributeType]) {
            float flt = [str floatValue];
            num = [NSNumber numberWithFloat:flt];
        } else if ([type isEqualToString:kCDTISInteger16AttributeType]) {
            int i16 = [str intValue];
            num = [NSNumber numberWithInt:i16];
        } else if ([type isEqualToString:kCDTISInteger32AttributeType]) {
            int i32 = [str intValue];
            num = [NSNumber numberWithInt:i32];
        } else if ([type isEqualToString:kCDTISInteger64AttributeType]) {
            int64_t i64 = [str longLongValue];
            num = [NSNumber numberWithLongLong:i64];
        }
        obj = num;

    } else if ([type isEqualToString:kCDTISRelationToOneType]) {
        NSString *entityName = value;
        if (entityName.length == 0) {
            obj = [NSNull null];
        } else {
            NSString *ref = [prop objectAtIndex:2];
            NSManagedObjectID *moid = [self decodeRelationFromEntityName:entityName
                                                                 withRef:ref
                                                             withContext:context];
            // we cannot return nil
            if (!moid) {
                obj = [NSNull null];
            } else {
                obj = moid;
            }
        }
    } else if ([type isEqualToString:kCDTISRelationToManyType]) {
        // we actually should do this here, but we hope to eventually
        // use a Cloudant View?
        oops(@"this is defered to newValueForRelationship");

    } else {
        oops(@"unknown ecoding: %@", type);
    }

    return obj;
}

#pragma mark - database methods
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
    if (!rev && err && error) {
        *error = err;
        NSLog(@"newRev: %@", newRev.body);
        oops(@"error: %@", err);
        return NO;
    }

    return YES;
}

/**
 *  Update exisiting object in the database
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
    NSString *revID = self.revIDFromDocID[docID];
    if (!revID) oops(@"revID is nil");

    NSEntityDescription *entity = [mo entity];
    NSDictionary *propDic = [entity propertiesByName];

    NSMutableDictionary *props = [NSMutableDictionary dictionary];
    NSDictionary *changed = [mo changedValues];

    for (NSString *name in changed) {
        NSArray *enc = nil;
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
        props[name] = enc;
    }

    // :( It makes me very sad that I have to fetch it
    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev && err) {
        if (error) *error = err;
        oops(@"no properties: %@", err);
    }

    if (![oldRev.revId isEqualToString:revID]) {
        if (error) {
            NSString *s = [NSString
                localizedStringWithFormat:@"RevisionID mismatch %@: %@", oldRev.revId, revID];
            *error = [NSError errorWithDomain:kCDTISErrorDomain
                                         code:CDTISErrorRevisionIDMismatch
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        return NO;
    }

    // TODO: version HACK
    NSString *oldVersion = oldRev.body[kCDTISObjectVersionKey];
    uint64_t version = [oldVersion longLongValue];
    ++version;
    NSNumber *v = [NSNumber numberWithUnsignedLongLong:version];
    props[kCDTISObjectVersionKey] = [v stringValue];

    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    // delete all changed properies, in case they are being removed.
    [upRev.body removeObjectsForKeys:[changed allKeys]];
    [upRev.body addEntriesFromDictionary:props];

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev && err) {
        if (error) *error = err;
        oops(@"no properties: %@", err);
    }
    // does not appear that I have to do this since we fetch it all again?
    self.revIDFromDocID[docID] = upedRev.revId;

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

    NSString *revID = self.revIDFromDocID[docID];
    if (!revID) oops(@"revID is nil");

    // :( It makes me very sad that I have to fetch it
    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev && err) {
        if (error) *error = err;
        oops(@"no properties: %@", err);
        return NO;
    }

    if (![oldRev.revId isEqualToString:revID]) {
        if (error) {
            NSString *s = [NSString
                localizedStringWithFormat:@"RevisionID mismatch %@: %@", oldRev.revId, revID];
            *error = [NSError errorWithDomain:kCDTISErrorDomain
                                         code:CDTISErrorRevisionIDMismatch
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
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
 *  @return dictionary
 */
- (NSDictionary *)valuesFromDocID:(NSString *)docID
                      withContext:(NSManagedObjectContext *)context
                       versionPtr:(uint64_t *)version
                            error:(NSError **)error
{
    NSError *err = nil;

    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docID
                                                           error:&err];
    if (!rev && err) {
        if (error) *error = err;
        oops(@"no properties: %@", err);
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
        NSArray *prop = rev.body[name];

        // we defer to newValueForRelationship:forObjectWithID:withContext:error
        if ([[prop firstObject] isEqualToString:kCDTISRelationToManyType]) {
            continue;
        }

        id obj = [self decodePropertyFrom:prop
                              withContext:context];
        if (!obj) {
            // Dictionaries do not take nil, but Values can't have NSNull.
            // Apparentely we just skip it and the properties faults take care of it
            continue;
        }
        values[name] = obj;
    }

    self.revIDFromDocID[docID] = rev.revId;

    return [NSDictionary dictionaryWithDictionary:values];
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
    self.databaseName = [remoteURL lastPathComponent];
    NSString *path = [self pathToDBDirectory:kCDTISDirectory error:&err];
    if (!path) {
        if (error) *error = err;
        return NO;
    }

    self.manager = [[CDTDatastoreManager alloc] initWithDirectory:path error:&err];
    if (!self.manager) {
        NSLog(@"Error creating manager: %@", err);
        if (error) *error = err;
        return NO;
    }

    self.datastore = [self.manager datastoreNamed:self.databaseName error:&err];
    if (!self.datastore) {
        NSLog(@"Error creating datastore: %@", err);
        if (error) *error = err;
        return NO;
    }

    self.indexManager = [[CDTIndexManager alloc] initWithDatastore:self.datastore error:&err];
    if (!self.indexManager) {
        if (error) *error = err;
        oops(@"cannot create indexManager: %@", err);
        return NO;
    }

    // nothing really here yet
    self.replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.manager];

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
        oops(@"cannot create default index: %@", err);
        return NO;
    }

    return YES;
}

/**
 *  Encode version hashes, which come to us as a dictionary of inline data
 *  objects, so we just base64 them.
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
        NSString *s = [h base64EncodedStringWithOptions:0];
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
    if (!oldRev && err) {
        if (error) *error = err;
        oops(@"no metaData?: %@", err);
    }
    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    // need to fixup the version hashed
    NSMutableDictionary *metaData = [[self metadata] mutableCopy];
    NSDictionary *hashes = metaData[NSStoreModelVersionHashesKey];

    // hashes are inline data and need to be converted
    if (hashes) {
        metaData[NSStoreModelVersionHashesKey] =
        [self encodeVersionHashes:hashes];
    }
    upRev.body[@"metaData"] = [NSDictionary dictionaryWithDictionary:metaData];

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev
                                                                        error:&err];
    if (!upedRev && err) {
        if (error) *error = err;
        oops(@"could not update metadata: %@", err);
    }

    return YES;
}

/**
 *  Decode version hashes, which come to us as a dictionary of base64 strings
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
        NSData *h = [[NSData alloc] initWithBase64EncodedString:s options:0];
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

        NSString *uuid = [self uniqueID];
        NSDictionary *metaData = @{
                                   NSStoreUUIDKey : uuid,
                                   NSStoreTypeKey : [self type]
                                   };

        // TODO: NSStoreModelVersionHashes?

        // store it so we can get it back the next time
        CDTMutableDocumentRevision *newRev = [CDTMutableDocumentRevision revision];
        newRev.docId = kCDTISMetaDataDocID;
        newRev.body = @{kCDTISTypeKey : kCDTISTypeMetadata,
                        @"metaData" : metaData,
                        @"run" : self.run
                        };

        rev = [self.datastore createDocumentFromRevision:newRev error:&err];
        if (!rev && err) {
            if (error) *error = err;
            oops(@"unable to store metaData: %@", err);
            return nil;
        }
        return metaData;
    }

    NSDictionary *oldMetaData = rev.body[@"metaData"];
    NSString *run = rev.body[@"run"];
    uint64_t runVal = [run longLongValue];
    ++runVal;
    self.run = [NSString stringWithFormat:@"%llu", runVal];

    CDTMutableDocumentRevision *upRev = [rev mutableCopy];
    upRev.body[@"run"] = self.run;
    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev && err) {
        if (error) *error = err;
        oops(@"upedRev: %@", err);
        return nil;
    }

    NSMutableDictionary *newMetaData = [oldMetaData mutableCopy];
    NSMutableDictionary *hashes = [newMetaData[NSStoreModelVersionHashesKey]
                                   mutableCopy];

    // hashes are encoded and need to be inline data
    if (hashes) {
        newMetaData[NSStoreModelVersionHashesKey] =
        [self decodeVersionHashes:hashes];
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
        NSString *e = [NSString
                      localizedStringWithFormat:
                      @"Unexpected store type %@", s];
        if (error) {
            *error = [NSError errorWithDomain:kCDTISErrorDomain
                                         code:CDTISErrorBadPath
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        oops(@"%@", e);
        return NO;
    }
    // TODO: check hashes
    return YES;
}

/**
 *  Out own setter for metadata
 *  Quote the docs:
 *  > Subclasses must override this property to provide storage and
 *  > persistence for the store metadata.
 *
 *  @param metadata <#metadata description#>
 */
- (void)setMetadata:(NSDictionary *)metadata
{
    NSError *err = nil;
    if (![self updateMetaDataWithDocID:kCDTISMetaDataDocID
                                 error:&err]) {
        oops(@"update metadata error?");
    }
    [super setMetadata:metadata];
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
        oops(@"failed metaData check");
    }
    // go directly to super
    [super setMetadata:metaData];


#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_0
    // must exclude anything but iOS
    /* FIXME
     * caches are either garbage or out of sync some how, so we just delete them?
     */
    [NSFetchedResultsController deleteCacheWithName:nil];
#endif

    return YES;
}

- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest
              withContext:(NSManagedObjectContext *)context
                    error:(NSError **)error
{
    NSError *err = nil;
    NSFetchRequestResultType fetchType = [fetchRequest resultType];
    NSEntityDescription *entity = [fetchRequest entity];
    NSString *entityName = [entity name];

    NSDictionary *query = @{kCDTISEntityNameKey : entityName};
    CDTQueryResult *hits = [self.indexManager queryWithDictionary:query error:&err];
    if (!hits) {
        oops(@"no hits");
    }

    switch (fetchType) {
        case NSManagedObjectResultType: {
            NSMutableArray *results = [NSMutableArray array];
            for (CDTDocumentRevision *rev in hits) {
                NSManagedObjectID *moid = [self newObjectIDForEntity:entity
                                                     referenceObject:rev.docId];
                NSManagedObject *mo = [context objectWithID:moid];
                [results addObject:mo];
            }
            return [NSArray arrayWithArray:results];
            break;
        }

        case NSManagedObjectIDResultType: {
            oops(@"NSManagedObjectIDResultType: guessing");
            NSMutableArray *results = [NSMutableArray array];
            for (CDTDocumentRevision *rev in hits) {
                NSManagedObjectID *moid = [self newObjectIDForEntity:entity
                                                     referenceObject:rev.docId];
                [results addObject:moid];
            }
            return [NSArray arrayWithArray:results];
            break;
        }

        case NSDictionaryResultType:
            oops(@"NSDictionaryResultType: no idea");
            break;

        case NSCountResultType: {
            NSArray *docIDs = [hits documentIds];
            NSUInteger count = [docIDs count];
            return @[ [NSNumber numberWithUnsignedLong:count] ];
            break;
        }

        default: {
            NSString *s = [NSString
                           localizedStringWithFormat:
                           @"Unknown request fetch type: %@", fetchRequest];
            if (error) {
                *error = [NSError errorWithDomain:kCDTISErrorDomain
                                             code:CDTISErrorExectueRequestFetchTypeUnkown
                                         userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
            }
            oops(@"%@", s);
            return nil;
            break;
        }
    }
    oops(@"should never get here");
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
            oops(@"inserted: %@", err);
        }
    }
    NSSet *updatedObjects = [saveRequest updatedObjects];
    for (NSManagedObject *mo in updatedObjects) {
        if (![self updateManagedObject:mo error:&err]) {
            oops(@"update: %@", err);
        }
    }
    NSSet *deletedObjects = [saveRequest deletedObjects];
    for (NSManagedObject *mo in deletedObjects) {
        if (![self deleteManagedObject:mo error:&err]) {
            oops(@"delete");
            (void)mo;
        }
    }
    NSSet *optLockObjects = [saveRequest lockedObjects];
    for (NSManagedObject *mo in optLockObjects) {
        if (![self optLockManagedObject:mo error:&err]) {
            oops(@"optObject")
        }
    }

    /* quote the docs:
     * > If the save request contains nil values for the
     * > inserted/updated/deleted/locked collections; 
     * > you should treat it as a request to save the store metadata.
     */
    if (!insertedObjects &&
        !updatedObjects &&
        !deletedObjects &&
        !optLockObjects) {
        if (![self updateMetaDataWithDocID:kCDTISMetaDataDocID
                                     error:&err]) {
            oops(@"update metadata error?");
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
        return [self executeFetchRequest:fetchRequest
                             withContext:context
                                   error:error];
    } else if (requestType == NSSaveRequestType) {
        NSSaveChangesRequest *saveRequest = (NSSaveChangesRequest *)request;
        return [self executeSaveRequest:saveRequest
                            withContext:context
                                  error:error];
    } else {
        NSString *s = [NSString
                       localizedStringWithFormat:
                       @"Unknown request type: %@", @(requestType)];
        if (error) {
            *error = [NSError errorWithDomain:kCDTISErrorDomain
                                         code:CDTISErrorExectueRequestTypeUnkown
                                     userInfo:@{NSLocalizedFailureReasonErrorKey : s}];
        }
        oops(@"%@", s);
        return nil;
    }
    oops(@"never get here");
    return @[];
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context
                                               error:(NSError **)error
{
    NSError *err = nil;
    NSString *docID = [self stringReferenceObjectForObjectID:objectID];
    uint64_t version = 1;

    NSDictionary *values = [self valuesFromDocID:docID
                                     withContext:context
                                      versionPtr:&version
                                           error:&err];

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
    /* FIXME
     * Very Inefficient
     */
    NSError *err = nil;
    NSString *docID = [self stringReferenceObjectForObjectID:objectID];
    CDTDocumentRevision *rev = [self.datastore getDocumentWithId:docID
                                                           error:&err];
    if (!rev && err) {
        if (error) *error = err;
        oops(@"no attributes: %@", err);
    }
    NSString *name = [relationship name];
    NSArray *rel = rev.body[name];
    NSString *type = [rel objectAtIndex:0];

    if ([type isEqualToString:kCDTISRelationToOneType]) {
        NSString *entityName = [rel objectAtIndex:1];
        NSString *ref = [rel objectAtIndex:2];
        NSManagedObjectID *moid = [self decodeRelationFromEntityName:entityName
                                                             withRef:ref
                                                         withContext:context];
        if (!moid) {
            return [NSNull null];
        }
        return moid;
    }
    if ([type isEqualToString:kCDTISRelationToManyType]) {
        NSMutableArray *moids = [NSMutableArray array];
        NSArray *oids = [rel objectAtIndex:1];
        for (NSArray *oid in oids) {
            NSString *entityName = [oid objectAtIndex:0];
            NSString *ref = [oid objectAtIndex:1];
            NSManagedObjectID *moid = [self decodeRelationFromEntityName:entityName
                                                                 withRef:ref
                                                             withContext:context];
            // if we get nil, don't add it, this should get us an empty array
            if (!moid && oids.count > 1) oops(@"got nil in an oid list");
            if (moid) {
                [moids addObject:moid];
            }
        }
        return [NSArray arrayWithArray:moids];
    }
    oops(@"unexpected type: %@", type);
    return nil;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error
{
    NSMutableArray *objectIDs = [NSMutableArray arrayWithCapacity:[array count]];
    for (NSManagedObject *mo in array) {
        NSManagedObjectID *moid =
            [self newObjectIDForEntity:[mo entity] referenceObject:[self uniqueID]];
        [objectIDs addObject:moid];
    }
    return objectIDs;
}

