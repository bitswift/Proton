//
//  PROKeyedTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROKeyedTransformation.h"
#import "NSDictionary+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROKeyedObject.h"
#import "PROModel.h"
#import "PROMultipleTransformation.h"
#import "PROTransformationProtected.h"

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

- (NSArray *)transformations {
    if (self.valueTransformations)
        return [self.valueTransformations allValues];
    else
        return [NSArray array];
}

- (PROTransformation *)flattenedTransformation {
    NSMutableDictionary *valueTransformations = [NSMutableDictionary dictionaryWithCapacity:self.valueTransformations.count];

    [self.valueTransformations enumerateKeysAndObjectsUsingBlock:^(NSString *key, PROTransformation *transformation, BOOL *stop){
        [valueTransformations setObject:transformation.flattenedTransformation forKey:key];
    }];

    if ([valueTransformations isEqualToDictionary:self.valueTransformations])
        return self;
    else
        return [[PROKeyedTransformation alloc] initWithValueTransformations:valueTransformations];
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

- (id)initWithTransformation:(PROTransformation *)transformation forKey:(NSString *)key {
    if (!transformation && !key) {
        // pass everything through
        return [self init];
    }

    NSDictionary *dict = [NSDictionary dictionaryWithObject:transformation forKey:key];
    return [self initWithValueTransformations:dict];
}

- (id)initWithTransformation:(PROTransformation *)transformation forKeyPath:(NSString *)keyPath; {
    if (!transformation && !keyPath) {
        // pass everything through
        return [self init];
    }

    // break down the key path into individual keys, which we'll use to
    // construct multiple keyed transformations
    NSArray *keyPathComponents = [keyPath componentsSeparatedByString:@"."];

    __block PROTransformation *nestedTransformation = transformation;
    [keyPathComponents enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *key, NSUInteger index, BOOL *stop){
        if (index == 0) {
            // this is the key with which we'll initialize 'self'
            *stop = YES;
            return;
        }

        PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:nestedTransformation forKey:key];
        nestedTransformation = keyedTransformation;

        if (!nestedTransformation) {
            *stop = YES;
            return;
        }
    }];

    if (!nestedTransformation)
        return nil;

    NSString *firstKey = [keyPathComponents objectAtIndex:0];
    return [self initWithTransformation:nestedTransformation forKey:firstKey];
}

#pragma mark Transformation

- (id)transform:(id<PROKeyedObject>)obj error:(NSError **)error; {
    if (!self.valueTransformations) {
        return obj;
    }

    if (![obj conformsToProtocol:@protocol(PROKeyedObject)]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ does not conform to <PROKeyedObject>", obj];

        return nil;
    }

    NSMutableDictionary *values = [[obj dictionaryValue] mutableCopy];

    for (NSString *key in self.valueTransformations) {
        NSAssert([key isKindOfClass:[NSString class]], @"Key for %@ is not a string: %@", self, key);

        id value = [values objectForKey:key];
        if (!value) {
            // the key to transform does not exist -- consider it to be NSNull
            value = [NSNull null];
        }

        PROTransformation *transformation = [self.valueTransformations objectForKey:key];

        value = [transformation transform:value error:error];
        if (!value) {
            if (error) {
                NSString *path = [NSString stringWithFormat:@"%@.", key];
                *error = [self prependTransformationPath:path toError:*error];
            }

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
        return [[[obj class] alloc] initWithDictionary:values error:error];
    }
}

- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error; {
    NSParameterAssert(objPtr != NULL);

    if (!self.valueTransformations) {
        return YES;
    }

    id obj = *objPtr;

    for (NSString *key in self.valueTransformations) {
        NSAssert([key isKindOfClass:[NSString class]], @"Key for %@ is not a string: %@", self, key);

        id value = [obj valueForKey:key];
        if (!value) {
            // consider the value to be NSNull
            value = [NSNull null];
        } else if ([value isKindOfClass:[NSArray class]]) {
            // pull the value out as a mutable array instead
            value = [obj mutableArrayValueForKey:key];
        }

        PROTransformation *transformation = [self.valueTransformations objectForKey:key];

        id modifiedValue = value;
        if (![transformation transformInPlace:&modifiedValue error:error]) {
            if (error) {
                NSString *path = [NSString stringWithFormat:@"%@.", key];
                *error = [self prependTransformationPath:path toError:*error];
            }

            // invalid transformation
            return NO;
        }

        if (modifiedValue != value) {
            // got a new object back
            [obj setValue:modifiedValue forKey:key];
        }
    }

    return YES;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);

    BOOL allModelUpdatesSuccessful = YES;

    for (NSString *key in self.valueTransformations) {
        PROTransformation *transformation = [self.valueTransformations objectForKey:key];

        NSString *newKeyPath;

        if (keyPath) {
            newKeyPath = [keyPath stringByAppendingFormat:@".%@", key];
        } else {
            // a nil key path means that we're at the top level, so we need to
            // start keeping track of the properties we're going into
            newKeyPath = key;
        }

        id value = [result valueForKey:key];
        if (!value) {
            value = [NSNull null];
        }

        allModelUpdatesSuccessful &= [transformation applyBlocks:blocks transformationResult:value keyPath:newKeyPath];
    }

    if (!allModelUpdatesSuccessful) {
        // not all changes correctly propagated, so fall back to a replacement
        // at the top level
        PROTransformationNewValueForKeyPathBlock newValueBlock = [blocks objectForKey:PROTransformationNewValueForKeyPathBlockKey];
        if (PROAssert(newValueBlock, @"%@ not provided", PROTransformationNewValueForKeyPathBlockKey)) {
            allModelUpdatesSuccessful = newValueBlock(self, result, keyPath);
        }
    }

    return allModelUpdatesSuccessful;
}

- (PROTransformation *)coalesceWithTransformation:(PROKeyedTransformation *)transformation; {
    if (!self.valueTransformations)
        return transformation;

    if (![transformation isKindOfClass:[PROKeyedTransformation class]])
        return nil;

    if (!transformation.valueTransformations)
        return self;

    NSMutableDictionary *newValueTransformations = [NSMutableDictionary dictionaryWithCapacity:self.valueTransformations.count + transformation.valueTransformations.count];

    [self.valueTransformations enumerateKeysAndObjectsUsingBlock:^(NSString *key, PROTransformation *valueTransformation, BOOL *stop){
        [newValueTransformations setObject:valueTransformation.flattenedTransformation forKey:key];
    }];

    [transformation.valueTransformations enumerateKeysAndObjectsUsingBlock:^(NSString *key, PROTransformation *valueTransformation, BOOL *stop){
        valueTransformation = valueTransformation.flattenedTransformation;

        PROTransformation *existingTransformation = [newValueTransformations objectForKey:key];
        if (!existingTransformation) {
            [newValueTransformations setObject:valueTransformation forKey:key];
            return;
        }

        PROTransformation *combinedTransformation = [existingTransformation coalesceWithTransformation:valueTransformation];
        if (!combinedTransformation) {
            NSArray *transformations = [NSArray arrayWithObjects:existingTransformation, valueTransformation, nil];

            combinedTransformation = [[PROMultipleTransformation alloc] initWithTransformations:transformations];
        }

        [newValueTransformations setObject:combinedTransformation forKey:key];
    }];

    return [[PROKeyedTransformation alloc] initWithValueTransformations:newValueTransformations];
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

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>: %@", [self class], (__bridge void *)self, self.valueTransformations];
}

- (NSUInteger)hash {
    return [self.valueTransformations hash];
}

- (BOOL)isEqual:(PROKeyedTransformation *)transformation {
    if (![transformation isKindOfClass:[PROKeyedTransformation class]])
        return NO;

    return NSEqualObjects(self.valueTransformations, transformation.valueTransformations);
}

@end
