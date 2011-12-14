//
//  PROModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROModel.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <objc/runtime.h>

NSString * const PROModelDidTransformNotification = @"PROModelDidTransformNotification";
NSString * const PROModelTransformationFailedNotification = @"PROModelTransformationFailedNotification";
NSString * const PROModelTransformedObjectKey = @"PROModelTransformedObjectKey";
NSString * const PROModelTransformationKey = @"PROModelTransformationKey";

@interface PROModel () {
    BOOL m_initialized;
}

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

    [self setValuesForKeysWithDictionary:dictionary];
    
    m_initialized = YES;
    return self;
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

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    return [self dictionaryWithValuesForKeys:[[self class] propertyKeys]];
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

- (void)setValue:(id)value forKey:(NSString *)key; {
    if (!m_initialized) {
        // use superclass implementation (no magic) while initializing ourself
        [super setValue:value forKey:key];
        return;
    }

    if (!value) {
        value = [NSNull null];
    }

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:value forKey:key];
    [self setValuesForKeysWithDictionary:dictionary];
}

- (void)setValuesForKeysWithDictionary:(NSDictionary *)dictionary; {
    if (!m_initialized) {
        // use superclass implementation (no magic) while initializing ourself
        [super setValuesForKeysWithDictionary:dictionary];
        return;
    }

    NSMutableDictionary *transformations = [[NSMutableDictionary alloc] initWithCapacity:[dictionary count]];

    for (NSString *key in dictionary) {
        NSAssert2([key isKindOfClass:[NSString class]], @"Key passed to %s is not a string: %@", __func__, key);

        id value = [dictionary objectForKey:key];
        id originalValue = [self valueForKey:key];

        if (NSEqualObjects(value, originalValue)) {
            // nothing to do
            continue;
        }

        if (!originalValue) {
            // 'nil' needs to be represented as NSNull for PROUniqueTransformation
            originalValue = [NSNull null];
        }

        // create the transformation for the specific property
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:originalValue outputValue:value];
        [transformations setObject:transformation forKey:key];
    }

    if (![transformations count]) {
        // nothing to do
        return;
    }
    
    // set up a key-based transformation for self
    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithValueTransformations:transformations];
    
    id transformedObject = [keyedTransformation transform:self];

    if (transformedObject) {
        // transformation succeeded
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            keyedTransformation, PROModelTransformationKey,
            transformedObject, PROModelTransformedObjectKey,
            nil
        ];
        
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PROModelDidTransformNotification
            object:self
            userInfo:userInfo
        ];
    } else {
        // transformation failed
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            keyedTransformation, PROModelTransformationKey,
            nil
        ];
        
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PROModelTransformationFailedNotification
            object:self
            userInfo:userInfo
        ];
    }
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

- (NSUInteger)hash {
    return [self.dictionaryValue hash];
}

- (BOOL)isEqual:(PROModel *)model {
    if (![model isKindOfClass:[PROModel class]])
        return NO;

    return [self.dictionaryValue isEqualToDictionary:model.dictionaryValue];
}

@end
