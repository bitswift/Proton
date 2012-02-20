//
//  PROUniqueTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROUniqueTransformation.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"

@implementation PROUniqueTransformation

#pragma mark Properties

@synthesize inputValue = m_inputValue;
@synthesize outputValue = m_outputValue;

- (PROTransformation *)reverseTransformation; {
    // just flip our values around
    return [[[self class] alloc] initWithInputValue:self.outputValue outputValue:self.inputValue];
}

- (NSArray *)transformations {
    // we don't have any child transformations
    return nil;
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithInputValue:nil outputValue:nil];
}

- (id)initWithInputValue:(id)inputValue outputValue:(id)outputValue; {
    self = [super init];
    if (!self)
        return nil;

    // if both are nil, leave them nil
    // if one is nil, make it NSNull
    // copy non-nil values
    if (inputValue) {
        m_inputValue = [inputValue copy];

        if (outputValue) {
            m_outputValue = [outputValue copy];
        } else {
            m_outputValue = [NSNull null];
        }
    } else if (outputValue) {
        m_inputValue = [NSNull null];
        m_outputValue = [outputValue copy];
    }

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj error:(NSError **)error; {
    if ([self transformInPlace:&obj error:error])
        return obj;
    else
        return nil;
}

- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error; {
    NSParameterAssert(objPtr != NULL);

    if (!self.inputValue)
        return YES;

    if (![self.inputValue isEqual:*objPtr]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorMismatchedInput format:@"Input value %@ is not equal to expected value", *objPtr];

        return NO;
    }

    *objPtr = self.outputValue;
    return YES;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);

    PROTransformationNewValueForKeyPathBlock newValueBlock = [blocks objectForKey:PROTransformationNewValueForKeyPathBlockKey];
    if (!PROAssert(newValueBlock, @"%@ not provided", PROTransformationNewValueForKeyPathBlockKey, __func__))
        return NO;

    return newValueBlock(self, result, keyPath);
}

- (PROTransformation *)coalesceWithTransformation:(PROUniqueTransformation *)transformation; {
    if (![transformation isKindOfClass:[PROUniqueTransformation class]])
        return nil;

    if (!NSEqualObjects(transformation.inputValue, self.outputValue))
        return nil;

    return [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:transformation.outputValue];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    id inputValue = [coder decodeObjectForKey:@"inputValue"];
    id outputValue = [coder decodeObjectForKey:@"outputValue"];
    return [self initWithInputValue:inputValue outputValue:outputValue];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.inputValue)
        [coder encodeObject:self.inputValue forKey:@"inputValue"];

    if (self.outputValue)
        [coder encodeObject:self.outputValue forKey:@"outputValue"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ old = %@, new = %@ }", [self class], (__bridge void *)self, self.inputValue, self.outputValue];
}

- (NSUInteger)hash {
    return [self.inputValue hash] ^ [self.outputValue hash];
}

- (BOOL)isEqual:(PROUniqueTransformation *)transformation {
    if (![transformation isKindOfClass:[PROUniqueTransformation class]])
        return NO;

    if (!NSEqualObjects(self.inputValue, transformation.inputValue))
        return NO;

    if (!NSEqualObjects(self.outputValue, transformation.outputValue))
        return NO;

    return YES;
}

@end
