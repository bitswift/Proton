//
//  PROModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROModel.h>
#import <Proton/EXTRuntimeExtensions.h>
#import <Proton/EXTScope.h>
#import <Proton/NSDictionary+HigherOrderAdditions.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <objc/runtime.h>

NSString * const PROModelPropertyKeyErrorKey = @"PROModelPropertyKey";

const NSInteger PROModelErrorUndefinedKey = 1;
const NSInteger PROModelErrorValidationFailed = 2;

@interface PROModel ()
/*
 * Enumerates all the properties of the receiver and any superclasses, up until
 * (and excluding) <PROModel>.
 */
+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property))block;
@end

@implementation PROModel

#pragma mark Lifecycle

- (id)init {
    return [self initWithDictionary:nil error:NULL];
}

- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    self = [super init];
    if (!self)
        return nil;

    void (^setErrorFromUndefinedKeyException)(NSDictionary *, NSException *) = ^(NSDictionary *attemptedValues, NSException *exception){
        if (!error)
            return;

        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

        // no idea why this is not defined as a constant
        NSString *failingKey = [exception.userInfo objectForKey:@"NSUnknownUserInfoKey"];

        if (failingKey) {
            [userInfo setObject:failingKey forKey:PROModelPropertyKeyErrorKey];

            // does not need to be localized, as it should never be displayed to
            // the user
            NSString *description = [NSString stringWithFormat:@"Property key \"%@\" does not exist on %@", failingKey, [self class]];
            [userInfo setObject:description forKey:NSLocalizedDescriptionKey];
        } else {
            // does not need to be localized, as it should never be displayed to
            // the user
            NSString *description = [NSString stringWithFormat:@"Dictionary contained a property key which does not exist on %@: %@", [self class], attemptedValues];
            [userInfo setObject:description forKey:NSLocalizedDescriptionKey];
        }

        *error = [NSError
            errorWithDomain:[PROModel errorDomain]
            code:PROModelErrorUndefinedKey
            userInfo:userInfo
        ];
    };

    NSDictionary *defaultValues = [[self class] defaultValuesForKeys];
    if (defaultValues) {
        @try {
            [self setValuesForKeysWithDictionary:defaultValues];
        } @catch (NSException *ex) {
            if (![ex.name isEqualToString:NSUndefinedKeyException])
                @throw;

            setErrorFromUndefinedKeyException(defaultValues, ex);
            return nil;
        }
    }

    for (NSString *key in dictionary) {
        // mark this as being autoreleased, because validateValue may return
        // a new object to be stored in this variable (and we don't want ARC to
        // double-free or leak the old or new values)
        __autoreleasing id value = [dictionary objectForKey:key];

        // consider NSNull to be nil if it comes in the dictionary
        if ([value isEqual:[NSNull null]]) {
            value = nil;
        }

        NSError *validationError = nil;
        if (![self validateValue:&value forKey:key error:(error ? &validationError : NULL)]) {
            if (error) {
                NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

                if (validationError) {
                    [userInfo addEntriesFromDictionary:validationError.userInfo];
                    [userInfo setObject:validationError forKey:NSUnderlyingErrorKey];
                }

                [userInfo setObject:key forKey:PROModelPropertyKeyErrorKey];

                *error = [NSError
                    errorWithDomain:[PROModel errorDomain]
                    code:PROModelErrorValidationFailed
                    userInfo:userInfo
                ];
            }

            return nil;
        }

        if (value) {
            @try {
                [self setValue:value forKey:key];
            } @catch (NSException *ex) {
                if (![ex.name isEqualToString:NSUndefinedKeyException])
                    @throw;

                setErrorFromUndefinedKeyException(defaultValues, ex);
                return nil;
            }
        }
    }

    return self;
}

#pragma mark Error handling

+ (NSString *)errorDomain {
    return @"com.bitswift.Proton.PROModelErrorDomain";
}

#pragma mark Reflection

+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property))block; {
    for (Class cls = self; cls != [PROModel class]; cls = [cls superclass]) {
        unsigned count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);

        if (!properties)
            continue;

        for (unsigned i = 0;i < count;++i) {
            block(properties[i]);
        }

        free(properties);
    }
}

+ (NSArray *)propertyKeys {
    NSMutableArray *names = [[NSMutableArray alloc] init];

    [self enumeratePropertiesUsingBlock:^(objc_property_t property){
        const char *cName = property_getName(property);
        NSString *str = [[NSString alloc] initWithUTF8String:cName];

        [names addObject:str];
    }];

    if ([names count])
        return names;
    else
        return nil;
}

+ (NSDictionary *)propertyClassesByKey; {
    NSMutableDictionary *classesByKey = [[NSMutableDictionary alloc] init];

    [self enumeratePropertiesUsingBlock:^(objc_property_t property){
        ext_propertyAttributes *attributes = ext_copyPropertyAttributes(property);
        if (!attributes)
            return;

        @onExit {
            free(attributes);
        };

        Class objectClass = attributes->objectClass;
        if (!objectClass)
            return;

        NSString *key = [[NSString alloc] initWithUTF8String:property_getName(property)];
        [classesByKey setObject:objectClass forKey:key];
    }];

    return classesByKey;
}

#pragma mark Transformation

- (PROKeyedTransformation *)transformationForKey:(NSString *)key value:(id)value; {
    if (!value) {
        value = [NSNull null];
    }

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:value forKey:key];
    return [self transformationForKeysWithDictionary:dictionary];
}

- (PROKeyedTransformation *)transformationForKeysWithDictionary:(NSDictionary *)dictionary; {
    NSMutableDictionary *transformations = [[NSMutableDictionary alloc] initWithCapacity:[dictionary count]];

    for (NSString *key in dictionary) {
        NSAssert2([key isKindOfClass:[NSString class]], @"Key passed to %s is not a string: %@", __func__, key);

        id value = [dictionary objectForKey:key];
        id originalValue = [self valueForKey:key];

        if (!originalValue) {
            // 'nil' needs to be represented as NSNull for PROKeyedTransformation
            originalValue = [NSNull null];
        }

        if (NSEqualObjects(value, originalValue)) {
            // nothing to do for this key
            continue;
        }

        // create the transformation for the specific property
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:originalValue outputValue:value];
        [transformations setObject:transformation forKey:key];
    }

    if (![transformations count]) {
        // nothing to do for any of the keys
        return nil;
    }

    // set up a key-based transformation for self
    return [[PROKeyedTransformation alloc] initWithValueTransformations:transformations];
}

#pragma mark Default values

+ (NSDictionary *)defaultValuesForKeys; {
    NSDictionary *defaultValues = [[self propertyClassesByKey] mapValuesUsingBlock:^(NSString *key, Class class){
        // try to use the "autoreleasing" constructors, since they should be
        // optimized to use a singleton empty collection (resulting in no memory
        // allocation)

        if ([class isSubclassOfClass:[NSArray class]])
            return [class array];

        if ([class isSubclassOfClass:[NSDictionary class]])
            return [class dictionary];

        if ([class isSubclassOfClass:[NSSet class]])
            return [class set];

        if ([class isSubclassOfClass:[NSOrderedSet class]])
            return [class orderedSet];

        return nil;
    }];

    return defaultValues;
}

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    return [self dictionaryWithValuesForKeys:[[self class] propertyKeys]];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSDictionary *dictionaryValue = [coder decodeObjectForKey:@"dictionaryValue"];
    return [self initWithDictionary:dictionaryValue error:NULL];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.dictionaryValue forKey:@"dictionaryValue"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    NSMutableString *str = [[NSMutableString alloc] initWithFormat:@"<%@: %p>{", [self class], (__bridge void *)self];

    NSDictionary *dictionaryValue = self.dictionaryValue;
    NSArray *sortedKeys = [[dictionaryValue allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    [sortedKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop){
        id value = [dictionaryValue objectForKey:key];

        if (index != 0)
            [str appendString:@","];

        [str appendFormat:@"\n\t\"%@\" = %@", key, value];
    }];

    [str appendString:@"\n}"];
    return str;
}

- (NSUInteger)hash {
    return [self.dictionaryValue hash];
}

- (BOOL)isEqual:(PROModel *)model {
    if (![model isKindOfClass:[PROModel class]])
        return NO;

    return [self.dictionaryValue isEqualToDictionary:model.dictionaryValue];
}

- (NSDictionary *)propertyListRepresentation {
    NSMutableDictionary *encodedProperties = [NSMutableDictionary dictionary];
    unsigned int outCount, i;
    objc_property_t *propertyList = class_copyPropertyList([self class], &outCount);

    for (i = 0; i < outCount; i++) {
        objc_property_t property = propertyList[i];
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];

        id (^propertyListRepresentationBlock)(id obj) = ^(id obj) {
            return [obj respondsToSelector:@selector(propertyListRepresentation)] ? [obj propertyListRepresentation] : obj;
        };

        id propertyValue = [self valueForKey:propertyName];
        if (propertyValue) {
            if ([propertyValue respondsToSelector:@selector(propertyListRepresentation)]) {
                propertyValue = [propertyValue dictionaryRepresentation];
            } else if ([propertyValue isKindOfClass:[NSArray class]]) {
                propertyValue = [propertyValue mapUsingBlock:propertyListRepresentationBlock];
            } else if ([propertyValue isKindOfClass:[NSDictionary class]]) {
                propertyValue = [propertyValue mapValuesUsingBlock:^id(id key, id obj) {
                    return propertyListRepresentationBlock(obj);
                }];
            }

            [encodedProperties setObject:propertyValue forKey:propertyName];
        }
    }

    free(propertyList);
    return [encodedProperties copy];
}

@end
