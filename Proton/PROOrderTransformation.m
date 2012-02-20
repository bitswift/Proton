//
//  PROOrderTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROOrderTransformation.h"
#import "EXTScope.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"

@implementation PROOrderTransformation

#pragma mark Properties

@synthesize startIndexes = m_startIndexes;
@synthesize endIndexes = m_endIndexes;

- (PROTransformation *)reverseTransformation; {
    // just flip our index sets around
    return [[[self class] alloc] initWithStartIndexes:self.endIndexes endIndexes:self.startIndexes];
}

- (NSArray *)transformations {
    // we don't have any child transformations
    return nil;
}

#pragma mark Initialization

- (id)init; {
    return [self initWithStartIndexes:nil endIndexes:nil];
}

- (id)initWithStartIndexes:(NSIndexSet *)startIndexes endIndexes:(NSIndexSet *)endIndexes; {
    NSParameterAssert([startIndexes count] == [endIndexes count]);

    self = [super init];
    if (!self)
        return nil;

    // don't save empty index sets -- consider them to be nil instead
    if ([startIndexes count]) {
        m_startIndexes = [startIndexes copy];
        m_endIndexes = [endIndexes copy];
    }

    return self;
}

- (id)initWithStartIndex:(NSUInteger)startIndex endIndex:(NSUInteger)endIndex {
    return [self initWithStartIndexes:[NSIndexSet indexSetWithIndex:startIndex] endIndexes:[NSIndexSet indexSetWithIndex:endIndex]];
}

#pragma mark Transformation

- (id)transform:(NSArray *)array error:(NSError **)error; {
    // if our index sets are nil (both are or neither are), pass all objects
    // through
    if (!self.startIndexes)
        return array;

    if (![array isKindOfClass:[NSArray class]]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ is not an array", array];

        return nil;
    }

    NSMutableArray *newArray = [array mutableCopy];
    if ([self transformInPlace:&newArray error:error])
        return [newArray copy];
    else
        return nil;
}

- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error; {
    if (!self.startIndexes)
        return YES;

    NSMutableArray *array = *objPtr;
    if (![array isKindOfClass:[NSArray class]]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ is not an array", array];

        return NO;
    }

    // if either index set goes out of bounds, return nil
    NSUInteger count = [array count];
    if ([self.startIndexes lastIndex] >= count) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorIndexOutOfBounds format:@"Index %lu is out of bounds for array %@", (unsigned long)self.startIndexes.lastIndex, array];

        return NO;
    }

    if ([self.endIndexes lastIndex] >= count) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorIndexOutOfBounds format:@"Index %lu is out of bounds for array %@", (unsigned long)self.endIndexes.lastIndex, array];

        return NO;
    }

    NSArray *objectsFromIndexes = [array objectsAtIndexes:self.startIndexes];
    [array removeObjectsAtIndexes:self.startIndexes];
    [array insertObjects:objectsFromIndexes atIndexes:self.endIndexes];

    return YES;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);

    if (!self.startIndexes)
        return YES;
    
    PROTransformationMutableArrayForKeyPathBlock mutableArrayBlock = [blocks objectForKey:PROTransformationMutableArrayForKeyPathBlockKey];
    if (!PROAssert(mutableArrayBlock, @"%@ not provided", PROTransformationMutableArrayForKeyPathBlockKey))
        return NO;

    if (!PROAssert(keyPath, @"No key path for %@", self))
        return NO;

    NSMutableArray *mutableArray = mutableArrayBlock(self, keyPath);
    NSArray *movedObjects = [mutableArray objectsAtIndexes:self.startIndexes];

    [mutableArray removeObjectsAtIndexes:self.startIndexes];
    [mutableArray insertObjects:movedObjects atIndexes:self.endIndexes];

    return YES;
}

- (PROTransformation *)coalesceWithTransformation:(PROTransformation *)transformation; {
    if (!self.startIndexes)
        return transformation;

    // TODO: implement merging logic for ordered transformations
    return nil;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSIndexSet *startIndexes = [coder decodeObjectForKey:@"startIndexes"];
    NSIndexSet *endIndexes = [coder decodeObjectForKey:@"endIndexes"];

    // if one is nil but the other is not,
    if (!startIndexes != !endIndexes) {
        // the object would fail an assertion
        return nil;
    }

    return [self initWithStartIndexes:startIndexes endIndexes:endIndexes];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.startIndexes)
        [coder encodeObject:self.startIndexes forKey:@"startIndexes"];

    if (self.endIndexes)
        [coder encodeObject:self.endIndexes forKey:@"endIndexes"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ from = %@, to = %@ }", [self class], (__bridge void *)self, self.startIndexes, self.endIndexes];
}

- (NSUInteger)hash {
    return [self.startIndexes hash] ^ [self.endIndexes hash];
}

- (BOOL)isEqual:(PROOrderTransformation *)transformation {
    if (![transformation isKindOfClass:[PROOrderTransformation class]])
        return NO;

    if (!NSEqualObjects(self.startIndexes, transformation.startIndexes))
        return NO;

    if (!NSEqualObjects(self.endIndexes, transformation.endIndexes))
        return NO;

    return YES;
}

@end
