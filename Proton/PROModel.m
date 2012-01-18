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
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <objc/runtime.h>

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
    return [self initWithDictionary:nil];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (!self)
        return nil;

    for (NSString *key in dictionary) {
        // mark this as being autoreleased, because validateValue may return
        // a new object to be stored in this variable (and we don't want ARC to
        // double-free or leak the old or new values)
        __autoreleasing id value = [dictionary objectForKey:key];
        
        // consider NSNull to be nil if it comes in the dictionary
        if ([value isEqual:[NSNull null]]) {
            value = nil;
        }
        
        if (![self validateValue:&value forKey:key error:NULL]) {
            // validation failed
            // TODO: logging?
            return nil;
        }

        if (value)
            [self setValue:value forKey:key];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

    if ([classesByKey count])
        return classesByKey;
    else
        return nil;
}

#pragma mark Transformation

- (id)transformValueForKey:(NSString *)key toValue:(id)value {
    return [[self transformationForKey:key value:value] transform:self];
}

- (id)transformValuesForKeysWithDictionary:(NSDictionary *)dictionary {
    return [[self transformationForKeysWithDictionary:dictionary] transform:self];   
}

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
            // 'nil' needs to be represented as NSNull for PROUniqueTransformation
            originalValue = [NSNull null];
        }

        if (NSEqualObjects(value, originalValue)) {
            // nothing to do
            continue;
        }

        // create the transformation for the specific property
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:originalValue outputValue:value];
        [transformations setObject:transformation forKey:key];
    }
    
    // set up a key-based transformation for self
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:transformations];
    
    if (![transformation transform:self]) {
        // this transformation cannot be validly applied to 'self'
        return nil;
    }
    
    return transformation;
}

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    return [self dictionaryWithValuesForKeys:[[self class] propertyKeys]];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSDictionary *dictionaryValue = [coder decodeObjectForKey:@"dictionaryValue"];
    return [self initWithDictionary:dictionaryValue];
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

@end
