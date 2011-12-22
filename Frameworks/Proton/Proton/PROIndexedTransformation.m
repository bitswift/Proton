//
//  PROIndexedTransformation.m
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROIndexedTransformation.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>

@implementation PROIndexedTransformation

#pragma mark Properties

@synthesize index = m_index;
@synthesize transformation = m_transformation;

#pragma mark Initialization

- (id)init {
    return [self initWithTransformation:nil index:0];
}

- (id)initWithTransformation:(PROTransformation *)transformation index:(NSUInteger)index {
    self = [super init];
    if (!self)
        return nil;

    m_transformation = [transformation copy];

    m_index = index;

    return self;
}

#pragma mark Transformation

- (id)transform:(NSArray *)array {
    // Return the unmodified object if transformation is nil
    if (!self.transformation)
        return array;

    if (![array isKindOfClass:[NSArray class]])
        return nil;

    if (self.index >= [array count])
        return nil;

    id inputValue = [array objectAtIndex:self.index];

    id result = [self.transformation transform:inputValue];
    if (!result)
        return nil;

    NSMutableArray *mutableArray = [array mutableCopy];
    [mutableArray replaceObjectAtIndex:self.index withObject:result];
    return [mutableArray copy];
}

- (PROTransformation *)reverseTransformation {
    PROTransformation *reverseSubtransformation = self.transformation.reverseTransformation;
    return [[[self class] alloc] initWithTransformation:reverseSubtransformation index:self.index];
}

#pragma mark Equality

- (BOOL)isEqual:(PROIndexedTransformation *)obj {
    if (![obj isKindOfClass:[PROIndexedTransformation class]])
        return NO;

    if (!NSEqualObjects(self.transformation, obj.transformation))
        return NO;

    // if the objects don't have a transformation, they're equal
    if (self.transformation) {
        if (self.index != obj.index)
            return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    return [self.transformation hash] ^ self.index;
}

#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark Coding

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.transformation)
        [coder encodeObject:self.transformation forKey:@"transformation"];

    [coder encodeInteger:self.index forKey:@"index"];
}

- (id)initWithCoder:(NSCoder *)coder {
    PROTransformation *transformation = [coder decodeObjectForKey:@"transformation"];
    NSUInteger index = [coder decodeIntegerForKey:@"index"];

    return [self initWithTransformation:transformation index:index];
}

@end
