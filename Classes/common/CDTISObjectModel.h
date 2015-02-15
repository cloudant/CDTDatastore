//
//  CDTISObjectModel.h
//
//
//  Created by Jimi Xenidis on 2/13/15.
//
//

#import <CoreData/CoreData.h>

/**
 *  This is how I like to assert, it stops me in the debugger.
 *
 *  *Why not use exceptions?*
 *  1. I can continue from this simply by using `jump +1`
 *  2. I don't need to "Add Exception Break-point"
 *  3. I don't need to hunt down which exception a test is using in an
 *  expected way
 *
 *  *Why is it a macro?*
 *  I want to stop *at* the `oops` line in the code and not have to "pop up"
 *  the stack if `oops` was not inlined due to optimization issues.
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

NSString *CDTISStringFromData(NSData *data);
NSData *CDTISDataFromString(NSString *str);
NSString *CDTISMakeMeta(NSString *s);

NSString *const CDTISUndefinedAttributeType;
NSString *const CDTISInteger16AttributeType;
NSString *const CDTISInteger32AttributeType;
NSString *const CDTISInteger64AttributeType;
NSString *const CDTISFloatAttributeType;
NSString *const CDTISDoubleAttributeType;

NSString *const CDTISMetaDataDocID;
NSString *const CDTISEntityNameKey;
NSString *const CDTISPrefix;
NSString *const CDTISMeta;

NSString *const CDTISFPNonFiniteKey;
NSString *const CDTISFPInfinity;
NSString *const CDTISFPNegInfinity;
NSString *const CDTISFPNaN;

NSString *const CDTISTypeStringKey;
NSString *const CDTISMIMETypeKey;
NSString *const CDTISFloatImageKey;
NSString *const CDTISDoubleImageKey;
NSString *const CDTISDecimalImageKey;

// These are in addition to NSAttributeType, which is unsigned
static NSInteger const CDTISRelationToOneType = -1;
static NSInteger const CDTISRelationToManyType = -2;

@interface CDTISProperty : NSObject
// Information about the object
@property (nonatomic) BOOL isRelationship;
@property (strong, nonatomic) NSString *typeName;
@property (nonatomic) NSInteger typeCode;
@property (strong, nonatomic) NSString *xform;
@property (strong, nonatomic) NSString *destination;
@property (strong, nonatomic) NSData *versionHash;

- (instancetype)initWithAttribute:(NSAttributeDescription *)attribute;
- (instancetype)initWithRelationship:(NSRelationshipDescription *)relationship;
- (instancetype)initWithDictionary:(NSDictionary *)dic;
- (NSDictionary *)dictionary;
@end

@interface CDTISEntity : NSObject
@property (strong, nonatomic) NSDictionary *properties;
@property (strong, nonatomic) NSData *versionHash;

- (instancetype)initWithEntities:(NSEntityDescription *)ent;
- (NSDictionary *)dictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end

@interface CDTISObjectModel : NSObject
@property (strong, nonatomic) NSDictionary *entities;

- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel *)mom;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionary;
- (NSInteger)propertyTypeWithName:(NSString *)name withEntityName:(NSString *)ent;
- (NSString *)destinationWithName:(NSString *)name withEntityName:(NSString *)ent;
- (NSString *)xformWithName:(NSString *)name withEntityName:(NSString *)ent;
- (NSDictionary *)versionHashes;
@end
