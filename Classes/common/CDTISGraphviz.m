//
//  CDTISGraphviz.m
//
//
//  Created by Jimi Xenidis on 2/14/15.
//
//

#import "CDTISGraphviz.h"
#import "CDTISObjectModel.h"

@interface CDTISGraphviz ()

@property (nonatomic, strong) CDTIncrementalStore *iStore;
@property (nonatomic, strong) NSData *dotData;

@end

@implementation CDTISGraphviz

- (instancetype)initWithIncrementalStore:(CDTIncrementalStore *)is
{
    if (!is) return nil;

    self = [super self];
    if (self) {
        _iStore = is;
    }
    return self;
}

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

- (BOOL)dotMe
{
    if (!self.iStore) {
        return NO;
    }

    CDTDatastore *datastore = self.iStore.datastore;
    if (!datastore) {
        return NO;
    }
    NSArray *all = [datastore getAllDocuments];
    NSMutableData *out = [NSMutableData data];

    DotWrite(out, @"strict digraph CDTIS {\n");
    DotWrite(out, @"  overlap=false;\n");
    DotWrite(out, @"  splines=true;\n");

    for (CDTDocumentRevision *rev in all) {
        if ([rev.docId isEqualToString:CDTISMetaDataDocID]) {
            // we do not plot the metadata document
            continue;
        }
        NSString *entity = nil;
        NSMutableArray *props = [NSMutableArray array];

        for (NSString *name in rev.body) {
            if ([name isEqual:CDTISEntityNameKey]) {
                // the node
                entity = rev.body[name];
            }

            if ([name hasPrefix:CDTISPrefix]) {
                continue;
            }
            id value = rev.body[name];
            NSDictionary *meta = rev.body[CDTISMakeMeta(name)];
            NSInteger ptype = [self.iStore propertyTypeFromDoc:rev.body withName:name];

            size_t idx = [props count] + 1;
            switch (ptype) {
                case CDTISRelationToOneType: {
                    NSString *str = value;
                    [props addObject:[NSString stringWithFormat:@"<%zu> to-one", idx]];
                    DotWrite(out,
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
                    for (NSString *str in rels) {
                        DotWrite(out, [NSString stringWithFormat:@"\"%@\":0 ", str]);
                    }
                    DotWrite(out, @"} [label=\"many\", color=\"red\"];\n");
                } break;
                case NSDecimalAttributeType: {
                    NSString *str = value;
                    NSDecimalNumber *dec = [NSDecimalNumber decimalNumberWithString:str];
                    double dbl = [dec doubleValue];
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:%e", idx, name, dbl]];
                } break;
                case NSInteger16AttributeType:
                case NSInteger32AttributeType:
                case NSInteger64AttributeType: {
                    NSNumber *num = value;
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:%@", idx, name, num]];
                } break;
                case NSFloatAttributeType: {
                    NSNumber *i32Num = meta[CDTISFloatImageKey];
                    int32_t i32 = (int32_t)[i32Num integerValue];
                    float flt = *(float *)&i32;
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:%f", idx, name, flt]];
                } break;
                case NSDoubleAttributeType: {
                    NSNumber *i64Num = meta[CDTISDoubleImageKey];
                    int64_t i64 = [i64Num integerValue];
                    double dbl = *(double *)&i64;
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@:%f", idx, name, dbl]];
                } break;
                case NSStringAttributeType: {
                    NSString *str = value;
                    if ([str length] > 16) {
                        str = [NSString stringWithFormat:@"%@...", [str substringToIndex:16]];
                    }
                    str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                    [props addObject:[NSString stringWithFormat:@"<%zu> %@: %@", idx, name, str]];
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
    }
    DotWrite(out, @"}\n");

    self.dotData = [NSData dataWithData:out];

    return YES;
}

- (NSString *)extractLLDB:(NSString *)path
{
    if (self.dotData) {
        size_t length = [self.dotData length];

        return [NSString stringWithFormat:@"memory read --force --binary --outfile "
                @"%@ --count %zu %p",
                path, length, [self.dotData bytes]];
    }
    return nil;
}


@end