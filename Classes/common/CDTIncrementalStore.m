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

/**
 *  This holds the "dot" directed graph, see [dotMe](@ref dotMe)
 */
@property (nonatomic, strong) NSData *dotData;

@end

#pragma mark - string constants
static NSString *const kCDTISType = @"CDTIncrementalStore";
static NSString *const kCDTISErrorDomain = @"CDTIncrementalStoreDomain";
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

#define kCDTISNumberPrefix @"number_"
static NSString *const kCDTISInteger16AttributeType = kCDTISNumberPrefix @"int16";
static NSString *const kCDTISInteger32AttributeType = kCDTISNumberPrefix @"int32";
static NSString *const kCDTISInteger64AttributeType = kCDTISNumberPrefix @"int64";
static NSString *const kCDTISFloatAttributeType = kCDTISNumberPrefix @"float";
static NSString *const kCDTISDoubleAttributeType = kCDTISNumberPrefix @"double";

// encodings for floating point special values
#define kCDTISFPPrefix @"floating_point_"
static NSString *const kCDTISFPInfinity = kCDTISFPPrefix @"infinity";
static NSString *const kCDTISFPNegInfinity = kCDTISFPPrefix @"-infinity";
static NSString *const kCDTISFPNaN = kCDTISFPPrefix@"nan";

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
 *  This is how I like to assert, it stops me in the debugger.
 *
 *  *Why not use exceptions?*
 *  1. I can continue from this simply by typing:
 *  ```
 *  strap register write pc `$pc+2`
 *  ```
 *  > Different architectures will use different addend values
 *  2. I don't need to "Add Exception Breakpoint"
 *  3. I don't need to hunt down which excpetion a test is using in an
 *  expected way
 *
 *  *Why is it a macro?*
 *  I want to stop *at* the `oops` line in the code and not have to "pop up"
 *  the stack if `oops` was not inlines due to optimization issues.
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
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    CDTChangeLogLevel(CDTREPLICATION_LOG_CONTEXT, DDLogLevelOff);
    CDTChangeLogLevel(CDTTD_REMOTE_REQUEST_CONTEXT, DDLogLevelOff);

    if (![[self class] isEqual:[CDTIncrementalStore class]]) {
        return;
    }
    [NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];
}

+ (NSString *)type
{
    return kCDTISType;
}

+ (NSURL *)localDir
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsDir =
    [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *dbDir = [documentsDir URLByAppendingPathComponent:kCDTISDirectory];

    return dbDir;
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

static NSString* makeMeta(NSString *s)
{
    return [kCDTISMeta stringByAppendingString:s];
}

/**
 *  Split the encoding into two properties
 *  We put in two properties, since we can only index top level items:
 *  1. props[name] which is the actual data
 *  1. props[meta] which is the other data we need
 *
 *  > *Note*: The documents hint that there is a way to index at lowered levels
 *  > but it it is unclear how to do it.  If it is possible it may be better
 *  > than the splitting that is done here.
 *
 *  @param props props
 *  @param name  name
 *  @param enc   enc
 */
- (void)setPropertyIn:(NSMutableDictionary *)props withName:(NSString *)name forEncoding:(NSArray *)enc
{
    NSString *data = [enc lastObject];
    props[name] = data;
    // pop the last one off
    NSRange r = NSMakeRange(0, [enc count] - 1);
    NSArray *meta = [enc subarrayWithRange:r];
    props[makeMeta(name)] = meta;
}

/**
 *  Join the two properties in to the singel tuple. @See setPropertyIn
 *
 *  @param props props
 *  @param name  name
 *
 *  @return encoded tuple in array, or nil if there is no contents
 */
- (NSArray *)getPropertyFrom:(NSDictionary *)props withName:(NSString *)name
{
    NSString *prop = props[name];
    NSArray *meta = props[makeMeta(name)];

    // We use this method so if meta is nil enc will be nil
    NSArray *enc = [meta arrayByAddingObject:prop];

    return enc;
}

- (CDTIndexType)indexTypeFromAttributeType:(NSAttributeType)type
{
    CDTIndexType it;
    switch (type) {
        default:
        case NSUndefinedAttributeType:
        case NSBinaryDataAttributeType:
        case NSTransformableAttributeType:
        case NSObjectIDAttributeType:
            oops(@"can't index on these!");
            break;

        case NSStringAttributeType:
            it = CDTIndexTypeString;

        case NSBooleanAttributeType:
        case NSDateAttributeType:
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
        case NSInteger64AttributeType:
        case NSDecimalAttributeType:
        case NSDoubleAttributeType:
        case NSFloatAttributeType:
            it = CDTIndexTypeInteger;
    }
    return it;
}

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
 *  Backing Store does not handle special values
 *
 *  So we encode them as separate types
 *  > *Warning*: This means that sort and predicates can't really
 *  > work on these values. Not sure what will happen.
 *
 *  @param num NSNumber of type float or double
 *
 *  @return <#return value description#>
 */
static NSArray *encodeFP(NSNumber *num)
{
    // We use our own string representation for special in case they change
    if ([num isEqual:@(INFINITY)]) {
        return @[ kCDTISFPInfinity, @"Infinity" ];
    }
    if ([num isEqual:@(-INFINITY)]) {
        return @[ kCDTISFPNegInfinity, @"-Infinity" ];
    }
    if ([num isEqual:@(NAN)]) {
        return @[ kCDTISFPNaN, @"NaN" ];
    }
    return nil;
}

/**
 *  Make sure the double is in the range that JOSN can handle
 *
 *  @param d NSNumber that represents a double
 *
 *  @return NSnumber that represents a value that JSON can handle
 */
static NSNumber *JSONDouble(NSNumber *d)
{
    // Todo: just send a float right now
    float f = [d floatValue];
    if (f == INFINITY) {
        f = FLT_MAX;
    } else if (f == -INFINITY) {
        f = -FLT_MAX;
    }
    return [NSNumber numberWithFloat:f];
}

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

    // Keep this
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
        case NSDoubleAttributeType: {
            NSNumber *num = obj;
            NSArray *enc = encodeFP(num);
            if (enc) {
                return enc;
            }
            /**
             *  JSON cannot handle the full range of double so we store 
             *  two values:
             *  1. `long long` "image" so we can store accurately
             *  > This could be a problematic when replicating to other arches
             *  2. A JSON range value so predicates and sort order can work
             */
            NSNumber *jsonNum = JSONDouble(num);
            double jd = [num doubleValue];

            // copy the image into the `long long`, note the pointer swizzling
            NSNumber *ll = @(*(long long *)&jd);
            return @[ kCDTISDoubleAttributeType, ll, jsonNum];
        }

        case NSFloatAttributeType: {
            NSNumber *num = obj;
            NSArray *enc = encodeFP(num);
            if (enc) {
                return enc;
            }
            return @[ kCDTISFloatAttributeType, num];
        }

        case NSInteger16AttributeType: {
            NSNumber *num = obj;
            return @[ kCDTISInteger16AttributeType, num];
        }

        case NSInteger32AttributeType: {
            NSNumber *num = obj;
            return @[ kCDTISInteger32AttributeType, num];
        }

        case NSInteger64AttributeType: {
            NSNumber *num = obj;
            return @[ kCDTISInteger64AttributeType, num];
        }
        default:
            break;
    }

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
        NSArray *enc = nil;
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
            oops(@"unknown property: %@", prop);
        }

        if (!enc) {
            oops(@"There should always be an encoding: %@: %@", prop, err);
        }

        [self setPropertyIn:props withName:name forEncoding:enc];
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
 *  @See encodeFP
 *
 *  @param str string
 *
 *  @return Returned Number
 */
static NSNumber *decodeFP(NSString *str)
{
    if ([str isEqualToString:kCDTISFPInfinity]) {
        return @(INFINITY);
    }
    if ([str isEqualToString:kCDTISFPNegInfinity]) {
        return @(-INFINITY);
    }
    if ([str isEqualToString:kCDTISFPNaN]) {
        return @(NAN);
    }
    return nil;
}

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
 *  @param prop    prop
 *  @param context context
 *
 *  @return object
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
    } else if ([type hasPrefix:kCDTISFPPrefix]) {
        // we don't care about value
        NSNumber *num = decodeFP(type);
        if (!num) oops(@"bad FP special type");
        obj = num;
    } else if ([type isEqualToString:kCDTISDoubleAttributeType]) {
        /**
         *  The value is stored as a `long long` image
         */
        NSNumber *llNum = value;
        long long ll = [llNum longLongValue];

        // copy the image into `double`, not wht pointer swizzling
        double dbl = *(double *)&ll;
        NSNumber *num = @(dbl);
        obj = num;
    } else if ([type isEqualToString:kCDTISFloatAttributeType]) {
        NSNumber *num = value;
        obj = num;
    } else if ([type isEqualToString:kCDTISInteger16AttributeType]) {
        NSNumber *num = value;
        obj = num;
    } else if ([type isEqualToString:kCDTISInteger32AttributeType]) {
        NSNumber *num = value;
        obj = num;
    } else if ([type isEqualToString:kCDTISInteger64AttributeType]) {
        NSNumber *num = value;
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
        oops(@"unknown encoding: %@", type);
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
        [self setPropertyIn:props withName:name forEncoding:enc];
    }

    // :( It makes me very sad that I have to fetch it
    CDTDocumentRevision *oldRev = [self.datastore getDocumentWithId:docID error:&err];
    if (!oldRev) {
        if (error) *error = err;
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

    // TODO: version HACK
    NSString *oldVersion = oldRev.body[kCDTISObjectVersionKey];
    uint64_t version = [oldVersion longLongValue];
    ++version;
    NSNumber *v = [NSNumber numberWithUnsignedLongLong:version];
    props[kCDTISObjectVersionKey] = [v stringValue];

    CDTMutableDocumentRevision *upRev = [oldRev mutableCopy];

    // delete all changed properies, in case they are being removed.
    [upRev.body removeObjectsForKeys:[props allKeys]];
    [upRev.body addEntriesFromDictionary:props];

    CDTDocumentRevision *upedRev = [self.datastore updateDocumentFromRevision:upRev error:&err];
    if (!upedRev) {
        if (error) *error = err;
        return NO;
    }
    // does not appear that I have to do this since we fetch it all again?
    self.revIDFromDocID[docID] = upedRev.revId;

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

    // If we get nil here, it just means we have never seen it.
    NSString *revID = self.revIDFromDocID[docID];
    // If we have never seen it before.. should we be deleting it?
    if (!revID) oops(@"Trying to delete an unknown object");

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
    if (!rev) {
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
        NSArray *prop = [self getPropertyFrom:rev.body withName:name];
        if (!prop) oops(@"we encoded baddly");

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
    NSString *path = [self pathToDBDirectory:&err];
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
        NSLog(@"Cannot create indexManager: %@", err);
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
        NSLog(@"cannot create default index: %@", err);
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
    if (!oldRev) {
        if (error) *error = err;
        NSLog(@"no metaData?: %@", err);
        return NO;
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
    if (!upedRev) {
        if (error) *error = err;
        NSLog(@"could not update metadata: %@", err);
        return NO;
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
        if (!rev) {
            if (error) *error = err;
            NSLog(@"unable to store metaData: %@", err);
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
    if (!upedRev) {
        if (error) *error = err;
        NSLog(@"upedRev: %@", err);
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
        oops(@"update metadata error: %@", err);
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

/**
 *  Create a dictionary of query options for the fetch query
 *
 *  @param fetchRequest fetchRequest
 *
 *  @return options dic
 */
- (NSDictionary *)sortByOptions:(NSFetchRequest *)fetchRequest
                          error:(NSError **)error
{
    NSError *err = nil;
    NSArray *sds = [fetchRequest sortDescriptors];
    if (sds.count) {
        if (sds.count > 1) oops(@"not sure what to do here");

        for (NSSortDescriptor *sd in sds) {
            NSString *sel = NSStringFromSelector([sd selector]);
            if (![sel isEqualToString:@"compare:"]) {
                oops(@"we do not allow custom compares");
            }
            NSString *key = [sd key];

            NSEntityDescription *entity = fetchRequest.entity;
            NSDictionary *props = [entity propertiesByName];
            id prop = props[key];
            if (![prop isKindOfClass:[NSAttributeDescription class]]) {
                oops(@"expected attribute");
            }
            NSAttributeDescription *attr = prop;

            CDTIndexType type = [self indexTypeFromAttributeType:attr.attributeType];

            if (![self ensureIndexExists:key
                               fieldName:key
                                    type:type
                                   error:&err]) {
                if (error) *error = err;
                oops(@"fail to ensure index: %@: %@", key, err);
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
 *  @return predicat dictionary
 */
- (NSDictionary *)comparisonPredicate:(NSComparisonPredicate *)cp
{
    NSExpression* lhs = [cp leftExpression];
    NSExpression* rhs = [cp rightExpression];

    NSString *key = @"";
    if ([lhs expressionType] == NSKeyPathExpressionType) {
        key = [lhs keyPath];
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
            result = @{ keyStr : @{ @"$max": value } };
            break;
        case NSEqualToPredicateOperatorType:
            result = @{ keyStr : value };
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            result = @{ keyStr : @{ @"min": value } };
            break;

        case NSInPredicateOperatorType: {
            if ([value isKindOfClass:[NSString class]]) {
                oops(@"Can't do substring matches");
                break;
            }
            // FIXME? I hope this deals with collections
            if ([value respondsToSelector:@selector(objectEnumerator)]) {
                NSMutableArray *set = [NSMutableArray array];
                for (id el in value) {
                    [set addObject:el];
                }
                result = @{ keyStr : [NSArray arrayWithArray:set] };
            }
            break;
        }

        case NSBetweenPredicateOperatorType: {
            NSArray *between = value;

            result = @{ keyStr: @{@"min": [between objectAtIndex:0],
                                  @"max": [between objectAtIndex:1]}};
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
            oops(@"Predicate with unsupported comparison operator: %@",
                 @(predType));
            break;

        default:
            oops(@"Predicate with unrecognized comparison operator: %@",
                 @(predType));
            break;
    }

    NSError *err = nil;

    oops(@"need to know the correct index type");

    if (![self ensureIndexExists:keyStr
                       fieldName:keyStr
                            type:CDTIndexTypeString
                           error:&err]) {
        oops(@"failed at creating index for key %@", keyStr);
        // it is unclear what happens if I perform a query with no index
        // I think we should let the backing store deal with it.
    }
    return result;
}

/**
 *  Process the predicates
 *
 *  @param fetchRequest fetchRequest
 *
 *  @return return value
 */
- (NSDictionary *)processPredicate:(NSPredicate *)p
{
    if (!p) {
        return nil;
    }

    if ([p isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *cp = (NSCompoundPredicate *)p;
        NSCompoundPredicateType predType = [cp compoundPredicateType];

        switch(predType) {
            case NSAndPredicateType: {
                oops(@"can we do this?");
                NSMutableDictionary *ands = [NSMutableDictionary dictionary];
                for (NSPredicate *sub in [cp subpredicates]) {
                    [ands addEntriesFromDictionary:[self processPredicate:sub]];
                }
                return [NSDictionary dictionaryWithDictionary:ands];
            }
            case NSOrPredicateType:
            case NSNotPredicateType:
                oops(@"Predicate with unsuported compound operator: %@",
                     @(predType));
                break;
            default:
                oops(@"Predicate with unrecognized compound operator: %@",
                     @(predType));
        }

        return nil;

    } else if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        return [self comparisonPredicate:(NSComparisonPredicate *)p];
    }
    oops(@"bad predicate class?");
    return nil;
}

/**
 *  create a query dictionaary for the backing store
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

    NSMutableDictionary *query = [@{kCDTISEntityNameKey : entityName} mutableCopy];
    NSDictionary *predicate = [self processPredicate:[fetchRequest predicate]];
    [query addEntriesFromDictionary:predicate];

    return [NSDictionary dictionaryWithDictionary:query];
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
    NSDictionary *options = [self sortByOptions:fetchRequest error:&err];
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
    CDTQueryResult *hits = [self.indexManager queryWithDictionary:query
                                                          options:options
                                                            error:&err];
    // hits == nil is valie, get rid of this once tested
    if (!hits) oops(@"no hits");
    if (!hits && err) {
        if (error) *error = err;
        return nil;
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
        }

        case NSDictionaryResultType:
            oops(@"NSDictionaryResultType: no idea");
            break;

        case NSCountResultType: {
            NSArray *docIDs = [hits documentIds];
            NSUInteger count = [docIDs count];
            return @[ [NSNumber numberWithUnsignedLong:count] ];
        }

        default:
            break;
    }
    NSString *s = [NSString
                   localizedStringWithFormat:
                   @"Unknown request fetch type: %@", fetchRequest];
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
            oops(@"inserted: %@", err);
        }
    }
    // Todo: Not sure how to deal with errors here
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

    if (CDTISDotMeUpdate) {
        NSLog(@"DotMe: %@", [self dotMe]);
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
        return [self executeFetchRequest:fetchRequest
                             withContext:context
                                   error:error];
    }

    if (requestType == NSSaveRequestType) {
        NSSaveChangesRequest *saveRequest = (NSSaveChangesRequest *)request;
        return [self executeSaveRequest:saveRequest
                            withContext:context
                                  error:error];
    }

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
    if (!rev) {
        if (error) *error = err;
        oops(@"no attributes: %@", err);
        return nil;
    }
    
    NSString *name = [relationship name];
    NSArray *rel = [self getPropertyFrom:rev.body withName:name];
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

#pragma mark - DOT
/**
 *  Quick function to write an `NSString` in UTF8 format.
 *
 *  @param out Object to write to.
 *  @param s   The string to write.
 */
static void DotWrite(NSMutableData *out, NSString *s)
{
    [out appendBytes:[s UTF8String]
              length:[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
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
- (NSString *)dotMe __attribute__ ((used))
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
                NSArray *prop = [self getPropertyFrom:rev.body
                                                   withName:name];
                NSString *ptype = [prop objectAtIndex:0];

                size_t idx = [props count] + 1;

                if ([ptype isEqualToString:kCDTISRelationToOneType]) {
                    NSString *str = [prop objectAtIndex:2];
                    [props addObject:[NSString stringWithFormat:@"<%zu> to-one", idx]];
                    DotWrite(out,
                             [NSString stringWithFormat:@"  \"%@\":%zu -> \"%@\":0 [label=\"one\", color=\"blue\"];\n",
                              rev.docId, idx, str]);

                } else if ([ptype isEqualToString:kCDTISRelationToManyType]) {
                    [props addObject:[NSString stringWithFormat:@"<%zu> to-many", idx]];
                    DotWrite(out,
                             [NSString stringWithFormat:@"  \"%@\":%zu -> { ",
                              rev.docId, idx]);
                    for (NSArray *r in [prop objectAtIndex:1] ) {
                        NSString *str = [r objectAtIndex:1];
                        DotWrite(out,
                                 [NSString stringWithFormat:@"\"%@\":0 ", str]);
                    }
                    DotWrite(out, @"} [label=\"many\", color=\"red\"];\n");

                } else if ([ptype isEqualToString:kCDTISDecimalAttributeType]) {
                    NSString *str = [prop objectAtIndex:1];
                    NSDecimalNumber *dec = [NSDecimalNumber
                                            decimalNumberWithString:str];
                    double dbl = [dec doubleValue];
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:%e",
                                      idx, name, dbl]];

                } else if ([ptype hasPrefix:kCDTISNumberPrefix]) {
                    id value = [prop objectAtIndex:1];
                    NSNumber *num;
                    if ([ptype isEqualToString:kCDTISDoubleAttributeType]) {
                        NSString *str = value;
                        double dbl = [str doubleValue];
                        num = [NSNumber numberWithDouble:dbl];
                    } else {
                        num = value;
                    }
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:%@",
                                      idx, name, num]];

                } else if ([ptype isEqualToString:kCDTISStringAttributeType] ||
                           [ptype hasPrefix:kCDTISFPPrefix]) {
                    NSString *str = [prop objectAtIndex:1];
                    if ([str length] > 16) {
                        str = [NSString stringWithFormat:@"%@...",
                               [str substringToIndex:16]];
                    }
                    str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@: %@",
                                      idx, name, str]];

                } else {
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:*",
                                      idx, name]];
                }
            }

            if (!entity) oops(@"no entity name?");
            DotWrite(out,
                     [NSString stringWithFormat:@"  \"%@\" [shape=record, label=\"{ <0> %@ ",
                      rev.docId, entity]);

            for (NSString *p in props) {
                DotWrite(out, [NSString stringWithFormat:@"| %@ ", p]);
            }
            DotWrite(out, @"}\" ];\n");

        } else if ([type isEqualToString:kCDTISTypeMetadata]) {
            //DotWrite(out, node);

        } else {
            oops(@"unknown type: %@", type);
        }
    }
    DotWrite(out, @"}\n");

    self.dotData = [NSData dataWithData:out];
    size_t length = [self.dotData length];
    return [NSString
            stringWithFormat:@"memory read --force --binary --outfile /tmp/CDTIS.dot --count %zu %p",
            length, [self.dotData bytes]];
}

@end
