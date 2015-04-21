//
//  CDTISObjectModel.m
//
//
//  Created by Jimi Xenidis on 2/13/15.
//
//

#import "CDTISObjectModel.h"

NSString *const CDTISPrefix = @"CDTIS";
NSString *const CDTISMeta = @"CDTISMeta_";
NSString *const CDTISMetaDataDocID = @"CDTISMetaData";
NSString *const CDTISEntityNameKey = @"CDTISEntityName";

NSString *const CDTISFPNonFiniteKey = @"nonFinite";
NSString *const CDTISFPInfinity = @"infinity";
NSString *const CDTISFPNegInfinity = @"-infinity";
NSString *const CDTISFPNaN = @"nan";

NSString *const CDTISTypeStringKey = @"type";
NSString *const CDTISMIMETypeKey = @"mime-type";
NSString *const CDTISFloatImageKey = @"ieee754_single";
NSString *const CDTISDoubleImageKey = @"ieee754_double";
NSString *const CDTISDecimalImageKey = @"nsdecimal";

NSString *CDTISStringFromData(NSData *data)
{
    NSMutableString *s = [NSMutableString string];
    const unsigned char *d = (const unsigned char *)[data bytes];
    size_t sz = [data length];

    for (size_t i = 0; i < sz; i++) {
        [s appendString:[NSString stringWithFormat:@"%02x", d[i]]];
    }
    return [NSString stringWithString:s];
}

NSData *CDTISDataFromString(NSString *str)
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

NSString *CDTISMakeMeta(NSString *s) { return [CDTISMeta stringByAppendingString:s]; }

// encodings for floating point special values
NSString *const CDTISUndefinedAttributeType = @"undefined";
NSString *const CDTISInteger16AttributeType = @"int16";
NSString *const CDTISInteger32AttributeType = @"int32";
NSString *const CDTISInteger64AttributeType = @"int64";
NSString *const CDTISFloatAttributeType = @"float";
NSString *const CDTISDoubleAttributeType = @"double";

static NSString *const CDTISDecimalAttributeTypeStr = @"decimal";
static NSString *const CDTISStringAttributeTypeStr = @"utf8";
static NSString *const CDTISBooleanAttributeTypeStr = @"bool";
static NSString *const CDTISDateAttributeTypeStr = @"date1970";
static NSString *const CDTISBinaryDataAttributeTypeStr = @"binary";
static NSString *const CDTISTransformableAttributeTypeStr = @"xform";
static NSString *const CDTISObjectIDAttributeTypeStr = @"id";
static NSString *const CDTISRelationToOneTypeStr = @"relation-to-one";
static NSString *const CDTISRelationToManyTypeStr = @"relation-to-many";

static NSString *const CDTISPropertyNameKey = @"typeName";
static NSString *const CDTISVersionHashKey = @"versionHash";
static NSString *const CDTISTransformerClassKey = @"xform";
static NSString *const CDTISRelationDesitinationKey = @"destination";
static NSString *const CDTISPropertiesKey = @"properties";

@implementation CDTISProperty

/**
 * Defines the attribute meta data that is stored in the object.
 *
 *  @param att
 *
 *  @return initialized object
 */
- (instancetype)initWithAttribute:(NSAttributeDescription *)attribute
{
    self = [super init];
    if (self) {
        _isRelationship = NO;
        NSAttributeType type = attribute.attributeType;
        _typeCode = type;
        _versionHash = attribute.versionHash;

        switch (type) {
            case NSUndefinedAttributeType:
                _typeName = @"NSUndefinedAttributeType";
                break;

            case NSStringAttributeType:
                _typeName = CDTISStringAttributeTypeStr;
                break;

            case NSBooleanAttributeType:
                _typeName = CDTISBooleanAttributeTypeStr;
                break;

            case NSDateAttributeType:
                _typeName = CDTISDateAttributeTypeStr;
                break;

            case NSBinaryDataAttributeType:
                _typeName = CDTISBinaryDataAttributeTypeStr;
                break;

            case NSTransformableAttributeType:
                _typeName = CDTISTransformableAttributeTypeStr;
                _xform = [attribute valueTransformerName];
                break;

            case NSObjectIDAttributeType:
                _typeName = CDTISObjectIDAttributeTypeStr;
                break;

            case NSDecimalAttributeType:
                _typeName = CDTISDecimalAttributeTypeStr;
                break;

            case NSDoubleAttributeType:
                _typeName = CDTISDoubleAttributeType;
                break;

            case NSFloatAttributeType:
                _typeName = CDTISFloatAttributeType;
                break;

            case NSInteger16AttributeType:
                _typeName = CDTISInteger16AttributeType;
                break;

            case NSInteger32AttributeType:
                _typeName = CDTISInteger32AttributeType;
                break;

            case NSInteger64AttributeType:
                _typeName = CDTISInteger64AttributeType;
                break;

            default:
                return nil;
        }
    }
    return self;
}

- (instancetype)initWithRelationship:(NSRelationshipDescription *)relationship
{
    self = [super init];
    if (self) {
        _isRelationship = YES;
        _versionHash = relationship.versionHash;

        NSEntityDescription *ent = [relationship destinationEntity];
        _destination = [ent name];

        if (relationship.isToMany) {
            _typeName = CDTISRelationToManyTypeStr;
            _typeCode = CDTISRelationToManyType;
        } else {
            _typeName = CDTISRelationToOneTypeStr;
            _typeCode = CDTISRelationToOneType;
        }
    }
    return self;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[CDTISPropertyNameKey] = self.typeName;
    dic[CDTISVersionHashKey] = CDTISStringFromData(self.versionHash);

    if (self.xform) {
        dic[CDTISTransformerClassKey] = self.xform;
    }
    if (self.isRelationship && self.destination) {
        dic[CDTISRelationDesitinationKey] = self.destination;
    }
    return [NSDictionary dictionaryWithDictionary:dic];
}

static NSInteger typeCodeFromName(NSString *name)
{
    if ([name isEqualToString:CDTISStringAttributeTypeStr]) {
        return NSStringAttributeType;
    }
    if ([name isEqualToString:CDTISBooleanAttributeTypeStr]) {
        return NSBooleanAttributeType;
    }
    if ([name isEqualToString:CDTISDateAttributeTypeStr]) {
        return NSDateAttributeType;
    }
    if ([name isEqualToString:CDTISBinaryDataAttributeTypeStr]) {
        return NSBinaryDataAttributeType;
    }
    if ([name isEqualToString:CDTISTransformableAttributeTypeStr]) {
        return NSTransformableAttributeType;
    }
    if ([name isEqualToString:CDTISObjectIDAttributeTypeStr]) {
        return NSObjectIDAttributeType;
    }
    if ([name isEqualToString:CDTISDecimalAttributeTypeStr]) {
        return NSDecimalAttributeType;
    }
    if ([name isEqualToString:CDTISInteger16AttributeType]) {
        return NSInteger16AttributeType;
    }
    if ([name isEqualToString:CDTISInteger32AttributeType]) {
        return NSInteger16AttributeType;
    }
    if ([name isEqualToString:CDTISInteger64AttributeType]) {
        return NSInteger16AttributeType;
    }
    if ([name isEqualToString:CDTISRelationToOneTypeStr]) {
        return CDTISRelationToOneType;
    }
    if ([name isEqualToString:CDTISRelationToManyTypeStr]) {
        return CDTISRelationToManyType;
    }

    return 0;
}

- (instancetype)initWithDictionary:(NSDictionary *)dic
{
    self = [super init];
    if (self) {
        _typeName = dic[CDTISPropertyNameKey];
        _typeCode = typeCodeFromName(_typeName);
        _versionHash = CDTISDataFromString(dic[CDTISVersionHashKey]);

        _xform = dic[CDTISTransformerClassKey];
        _destination = dic[CDTISRelationDesitinationKey];

        if (_destination) {
            _isRelationship = YES;
        }
    }
    return self;
}

- (NSString *)description
{
    NSDictionary *dic = [self dictionary];
    return [dic description];
}

@end

@implementation CDTISEntity : NSObject

- (instancetype)initWithEntities:(NSEntityDescription *)ent
{
    self = [super init];
    if (self) {
        CDTISProperty *enc = nil;
        NSMutableDictionary *props = [NSMutableDictionary dictionary];
        for (id prop in [ent properties]) {
            if ([prop isTransient]) {
                continue;
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
        _properties = props;
        _versionHash = ent.versionHash;
    }
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
        CDTISPropertiesKey : [NSDictionary dictionaryWithDictionary:dic],
        CDTISVersionHashKey : CDTISStringFromData(self.versionHash)
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        NSString *vh = dictionary[CDTISVersionHashKey];
        _versionHash = CDTISDataFromString(vh);

        NSMutableDictionary *dic = [NSMutableDictionary dictionary];

        NSDictionary *props = dictionary[CDTISPropertiesKey];
        for (NSString *name in props) {
            NSDictionary *desc = props[name];
            dic[name] = [[CDTISProperty alloc] initWithDictionary:desc];
        }
        _properties = [NSDictionary dictionaryWithDictionary:dic];
    }
    return self;
}

- (NSString *)description
{
    NSDictionary *dic = [self dictionary];
    return [dic description];
}

@end

@implementation CDTISObjectModel

- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel *)mom
{
    self = [super init];
    if (self) {
        NSMutableDictionary *ents = [NSMutableDictionary dictionary];
        for (NSEntityDescription *ent in mom.entities) {
            if ([ent superentity]) {
                continue;
            }
            ents[ent.name] = [[CDTISEntity alloc] initWithEntities:ent];
        }
        _entities = [NSDictionary dictionaryWithDictionary:ents];
    }
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

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super self];
    if (self) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];

        for (NSString *name in dictionary) {
            NSDictionary *desc = dictionary[name];
            dic[name] = [[CDTISEntity alloc] initWithDictionary:desc];
        }
        _entities = [NSDictionary dictionaryWithDictionary:dic];
    }
    return self;
}

- (NSInteger)propertyTypeWithName:(NSString *)name withEntityName:(NSString *)ent
{
    CDTISEntity *ents = self.entities[ent];
    CDTISProperty *prop = ents.properties[name];
    return prop.typeCode;
}

- (NSString *)destinationWithName:(NSString *)name withEntityName:(NSString *)ent
{
    CDTISEntity *ents = self.entities[ent];
    CDTISProperty *prop = ents.properties[name];
    return prop.destination;
}

- (NSString *)xformWithName:(NSString *)name withEntityName:(NSString *)ent
{
    CDTISEntity *ents = self.entities[ent];
    CDTISProperty *prop = ents.properties[name];
    return prop.xform;
}

- (NSDictionary *)versionHashes
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (NSString *e in self.entities) {
        CDTISEntity *ent = self.entities[e];
        dic[e] = ent.versionHash;
    }
    return [NSDictionary dictionaryWithDictionary:dic];
}

- (NSString *)description { return [self.entities description]; }
@end
