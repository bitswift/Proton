//
//  PROOrderTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROOrderTransformation.h>
#import <Proton/EXTScope.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROModelController.h>

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

- (id)transform:(id)array; {
    // if our index sets are nil (both are or neither are), pass all objects
    // through
    if (!self.startIndexes)
        return array;

    if (![array isKindOfClass:[NSArray class]])
        return nil;

    // if either index set goes out of bounds, return nil
    NSUInteger count = [array count];
    if ([self.startIndexes lastIndex] >= count || [self.endIndexes lastIndex] >= count)
        return nil;

    NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:count];

    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger originalIndex, BOOL *stop){
        // if this index isn't moved,
        if (![self.startIndexes containsIndex:originalIndex]) {
            // add the object into the new array
            [newArray addObject:obj];
        }
    }];

    NSUInteger indexCount = [self.startIndexes count];
    NSAssert(indexCount == [self.endIndexes count], @"%@ should have the same number of start and end indexes", self);

    // we have to copy the indexes into C arrays, since there's no way to
    // retrieve values from them one-by-one
    NSUInteger startIndexes[indexCount];
    [self.startIndexes getIndexes:startIndexes maxCount:indexCount inIndexRange:nil];

    NSUInteger endIndexes[indexCount];
    [self.endIndexes getIndexes:endIndexes maxCount:indexCount inIndexRange:nil];

    // for every index that was moved, insert the objects into the proper
    // place after the fact
    for (NSUInteger setIndex = 0; setIndex < indexCount; ++setIndex) {
        NSUInteger originalIndex = startIndexes[setIndex];
        NSUInteger newIndex = endIndexes[setIndex];

        id obj = [array objectAtIndex:originalIndex];
        [newArray insertObject:obj atIndex:newIndex];
    }

    return [newArray copy];
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    /*
     * An order transformation means that we're going to be reordering objects
     * in an array of the model (e.g., model.submodels), so we need to reorder
     * the model controllers identically.
     */

    if (!modelKeyPath)
        return NO;

    NSString *ownedModelControllersKeyPath = [modelController modelControllersKeyPathForModelKeyPath:modelKeyPath];
    if (!ownedModelControllersKeyPath)
        return NO;

    NSMutableArray *associatedControllers = [modelController mutableArrayValueForKeyPath:ownedModelControllersKeyPath];

    NSArray *movedControllers = [associatedControllers objectsAtIndexes:self.startIndexes];
    [associatedControllers removeObjectsAtIndexes:self.startIndexes];
    [associatedControllers insertObjects:movedControllers atIndexes:self.endIndexes];

    return YES;
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
