//
//  PROKeyedTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROKeyedTransformation.h>
#import <Proton/NSObject+ComparisonAdditions.h>

@implementation PROKeyedTransformation

#pragma mark Properties

@synthesize valueTransformations = m_valueTransformations;

- (PROTransformation *)reverseTransformation; {
    NSMutableDictionary *reverseTransformations = [[NSMutableDictionary alloc] initWithCapacity:self.valueTransformations.count];

    // simply reverse each transformation and keep it associated with the same
    // key
    for (id key in self.valueTransformations) {
        PROTransformation *transformation = [self.valueTransformations objectForKey:key];
        [reverseTransformations setObject:transformation.reverseTransformation forKey:key];
    }

    return [[[self class] alloc] initWithValueTransformations:reverseTransformations];
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithValueTransformations:nil];
}

- (id)initWithValueTransformations:(NSDictionary *)valueTransformations; {
    self = [super init];
    if (!self)
        return nil;

    m_valueTransformations = [valueTransformations copy];
    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    if (!self.valueTransformations) {
        return obj;
    }

    if (![obj respondsToSelector:@selector(dictionaryValue)]) {
        // doesn't conform to <PROKeyedObject>
        return nil;
    }
    
    // check with the class for this method, since runtime magic could
    // (potentially) hide an init method after it's already initialized, or
    // perhaps proxy this message to another object
    if (![[obj class] instancesRespondToSelector:@selector(initWithDictionary:)]) {
        // doesn't conform to <PROKeyedObject>
        return nil;
    }

    NSMutableDictionary *values = [[obj dictionaryValue] mutableCopy];

    for (NSString *key in self.valueTransformations) {
        NSAssert2([key isKindOfClass:[NSString class]], @"Key for %@ is not a string: %@", self, key);

        id value = [values valueForKey:key];
        if (!value) {
            // the key to transform does not exist -- consider it to be NSNull
            value = [NSNull null];
        }

        PROTransformation *transformation = [self.valueTransformations objectForKey:key];
        value = [transformation transform:value];

        if (!value) {
            // invalid transformation
            return nil;
        }

        [values setObject:value forKey:key];
    }

    // construct the object with its changed values and return it
    if ([obj isKindOfClass:[NSDictionary class]]) {
        // special-case NSDictionary, since it's a class cluster
        return [values copy];
    } else {
        return [[[obj class] alloc] initWithDictionary:values];
    }
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSDictionary *valueTransformations = [coder decodeObjectForKey:@"valueTransformations"];
    return [self initWithValueTransformations:valueTransformations];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.valueTransformations)
        [coder encodeObject:self.valueTransformations forKey:@"valueTransformations"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSUInteger)hash {
    return [self.valueTransformations hash];
}

- (BOOL)isEqual:(PROKeyedTransformation *)transformation {
    if (![transformation isKindOfClass:[PROKeyedTransformation class]])
        return NO;

    return NSEqualObjects(self.valueTransformations, transformation.valueTransformations);
}

@end
