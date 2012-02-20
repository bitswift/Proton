//
//  PROMultipleTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROMultipleTransformation.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROKeyValueCodingMacros.h"

@implementation PROMultipleTransformation

#pragma mark Properties

@synthesize transformations = m_transformations;

- (PROTransformation *)reverseTransformation; {
    NSMutableArray *reverseTransformations = [[NSMutableArray alloc] initWithCapacity:self.transformations.count];

    // reverse each individual transformation, and reverse their order as well
    [self.transformations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PROTransformation *transformation, NSUInteger index, BOOL *stop){
        [reverseTransformations addObject:transformation.reverseTransformation];
    }];
    
    return [[[self class] alloc] initWithTransformations:reverseTransformations];
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithTransformations:nil];
}

- (id)initWithTransformations:(NSArray *)transformations; {
    self = [super init];
    if (!self)
        return nil;

    if (!transformations) {
        // the contract from PROTransformation says that the 'transformations'
        // property can never be nil for this class
        m_transformations = [NSArray array];
    } else {
        m_transformations = [transformations copy];
    }

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj error:(NSError **)error; {
    __block id currentValue = obj;
    __block NSError *strongError = nil;

    [self.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformation, NSUInteger index, BOOL *stop){
        currentValue = [transformation transform:currentValue error:&strongError];
        if (!currentValue) {
            if (error) {
                NSString *path = [NSString stringWithFormat:@"multipleTransformation(%lu).", (unsigned long)index];
                strongError = [self prependTransformationPath:path toError:strongError];
            }

            *stop = YES;
            return;
        }
    }];

    if (strongError && error) {
        *error = strongError;
    }

    return currentValue;
}

- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error; {
    __block id obj = *objPtr;
    __block NSError *strongError = nil;

    [self.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformation, NSUInteger index, BOOL *stop){
        if (![transformation transformInPlace:&obj error:&strongError]) {
            if (error) {
                NSString *path = [NSString stringWithFormat:@"multipleTransformation(%lu).", (unsigned long)index];
                strongError = [self prependTransformationPath:path toError:strongError];
            }

            obj = nil;
            *stop = YES;
            return;
        }
    }];

    if (strongError && error) {
        *error = strongError;
    }

    if (obj) {
        *objPtr = obj;
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);

    if (!self.transformations.count)
        return YES;

    /*
     * Unfortunately, for a multiple transformation, we have to redo the
     * actual work of the transformation in order to properly update
     * step-by-step. It would be unsafe to apply the blocks just with the final
     * result, because the child transformations may be granular and independent
     * enough that they need to be separately applied one-by-one.
     */

    // rewind the value to what it was before the transformation
    NSError *error = nil;
    id currentValue = [self.reverseTransformation transform:result error:&error];
    if (!PROAssert(currentValue, @"Reverse transformation of previous result %@ failed: %@", result, error))
        return NO;

    for (PROTransformation *transformation in self.transformations) {
        currentValue = [transformation transform:currentValue error:&error];
        if (!PROAssert(currentValue, @"Transformation %@ failed on the way to the original result: %@", transformation, error))
            return NO;

        if (![transformation applyBlocks:blocks transformationResult:currentValue keyPath:keyPath]) {
            PROTransformationNewValueForKeyPathBlock newValueBlock = [blocks objectForKey:PROTransformationNewValueForKeyPathBlockKey];
            if (!PROAssert(newValueBlock, @"%@ not provided", PROTransformationNewValueForKeyPathBlockKey)) {
                return NO;
            } else {
                return newValueBlock(transformation, result, keyPath);
            }
        }
    }

    return YES;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSArray *transformations = [coder decodeObjectForKey:@"transformations"];
    return [self initWithTransformations:transformations];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.transformations)
        [coder encodeObject:self.transformations forKey:@"transformations"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSUInteger)hash {
    return [self.transformations hash];
}

- (BOOL)isEqual:(PROMultipleTransformation *)transformation {
    if (![transformation isKindOfClass:[PROMultipleTransformation class]])
        return NO;

    return NSEqualObjects(self.transformations, transformation.transformations);
}

@end
