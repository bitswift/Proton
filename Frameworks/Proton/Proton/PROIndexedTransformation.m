//
//  PROIndexedTransformation.m
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROIndexedTransformation.h>
#import <Proton/EXTScope.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>

@implementation PROIndexedTransformation

#pragma mark Properties

@synthesize indexes = m_indexes;
@synthesize transformations = m_transformations;

#pragma mark Initialization

- (id)init {
    return [self initWithIndexes:nil transformations:nil];
}

- (id)initWithIndexes:(NSIndexSet *)indexes transformations:(NSArray *)transformations; {
    NSParameterAssert([indexes count] == [transformations count]);

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

    // don't save an empty index set -- consider it to be nil instead
    if ([indexes count]) {
        m_indexes = [indexes copy];
    }

    return self;
}

- (id)initWithIndex:(NSUInteger)index transformation:(PROTransformation *)transformation; {
    if (!transformation) {
        // just pass through everything
        return [self init];
    }

    return [self initWithIndexes:[NSIndexSet indexSetWithIndex:index] transformations:[NSArray arrayWithObject:transformation]];
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    return [super transform:obj];
}

- (PROTransformationBlock)transformationBlockUsingRewriterBlock:(PROTransformationRewriterBlock)block; {
    PROTransformationBlock baseTransformation = ^(id array){
        // Return the unmodified object if indexes is nil
        if (!self.indexes)
            return array;

        if (![array isKindOfClass:[NSArray class]])
            return nil;

        NSUInteger arrayCount = [array count];

        // if the index set goes out of bounds, return nil
        if (self.indexes.lastIndex >= arrayCount)
            return nil;

        NSUInteger indexCount = [self.indexes count];

        // we have to copy the indexes into a C array, since there's no way to
        // retrieve values from it one-by-one
        NSUInteger *indexes = malloc(sizeof(*indexes) * indexCount);
        if (!indexes) {
            return nil;
        }

        @onExit {
            free(indexes);
        };

        [self.indexes getIndexes:indexes maxCount:indexCount inIndexRange:nil];

        __block NSMutableArray *newArray = [array mutableCopy];

        [self.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformation, NSUInteger setIndex, BOOL *stop){
            NSUInteger index = indexes[setIndex];
            id inputValue = [array objectAtIndex:index];

            PROTransformationBlock transformationBlock = [transformation transformationBlockUsingRewriterBlock:block];
            id result = transformationBlock(inputValue);

            if (!result) {
                newArray = nil;

                *stop = YES;
                return;
            }

            [newArray replaceObjectAtIndex:index withObject:result];
        }];

        return [newArray copy];
    };

    return ^(id oldValue){
        id newValue;

        if (block) {
            newValue = block(self, baseTransformation, oldValue);
        } else {
            newValue = baseTransformation(oldValue);
        }

        return newValue;
    };
}

- (PROTransformation *)reverseTransformation {
    NSMutableArray *reversedTransformations = [[NSMutableArray alloc] initWithCapacity:self.transformations.count];

    for (PROTransformation *transformation in self.transformations) {
        [reversedTransformations addObject:transformation.reverseTransformation];
    }

    return [[[self class] alloc] initWithIndexes:self.indexes transformations:reversedTransformations];
}

#pragma mark Equality

- (BOOL)isEqual:(PROIndexedTransformation *)obj {
    if (![obj isKindOfClass:[PROIndexedTransformation class]])
        return NO;

    if (!NSEqualObjects(self.transformations, obj.transformations))
        return NO;

    if (!NSEqualObjects(self.indexes, obj.indexes))
        return NO;

    return YES;
}

- (NSUInteger)hash {
    return [self.transformations hash] ^ [self.indexes hash];
}

#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark Coding

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.transformations)
        [coder encodeObject:self.transformations forKey:@"transformations"];

    if (self.indexes)
        [coder encodeObject:self.indexes forKey:@"indexes"];
}

- (id)initWithCoder:(NSCoder *)coder {
    NSArray *transformations = [coder decodeObjectForKey:@"transformations"];
    NSIndexSet *indexes = [coder decodeObjectForKey:@"indexes"];

    return [self initWithIndexes:indexes transformations:transformations];
}

@end
