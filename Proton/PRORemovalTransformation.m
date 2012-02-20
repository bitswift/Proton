//
//  PRORemovalTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PRORemovalTransformation.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROInsertionTransformation.h"

@implementation PRORemovalTransformation

#pragma mark Properties

@synthesize removalIndexes = m_removalIndexes;
@synthesize expectedObjects = m_expectedObjects;

- (PROTransformation *)reverseTransformation; {
    return [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.removalIndexes objects:self.expectedObjects];
}

- (NSArray *)transformations {
    // we don't have any child transformations
    return nil;
}

#pragma mark Initialization

- (id)init; {
    return [self initWithRemovalIndexes:nil expectedObjects:nil];
}

- (id)initWithRemovalIndex:(NSUInteger)index expectedObject:(id)object; {
    if (!object)
        return [self init];

    return [self
        initWithRemovalIndexes:[NSIndexSet indexSetWithIndex:index]
        expectedObjects:[NSArray arrayWithObject:object]
    ];
}

- (id)initWithRemovalIndexes:(NSIndexSet *)removalIndexes expectedObjects:(NSArray *)expectedObjects; {
    NSParameterAssert([removalIndexes count] == [expectedObjects count]);

    self = [super init];
    if (!self)
        return nil;

    // don't save empty collections -- consider them to be nil instead
    if ([removalIndexes count])
        m_removalIndexes = [removalIndexes copy];

    if ([expectedObjects count])
        m_expectedObjects = [expectedObjects copy];

    return self;
}


#pragma mark Transformation

- (id)transform:(NSArray *)array error:(NSError **)error; {
    if (!self.removalIndexes)
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
    NSParameterAssert(objPtr != NULL);

    if (!self.removalIndexes)
        return YES;

    NSMutableArray *array = *objPtr;

    if (![array isKindOfClass:[NSArray class]]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ is not an array", array];

        return NO;
    }

    NSUInteger count = [array count];

    // if the index set goes out of bounds, return nil
    if ([self.removalIndexes lastIndex] >= count) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorIndexOutOfBounds format:@"Index %lu is out of bounds for array %@", (unsigned long)self.removalIndexes.lastIndex, array];

        return NO;
    }

    // if one or more objects doesn't match, return nil
    NSArray *objectsFromArray = [array objectsAtIndexes:self.removalIndexes];
    if (![objectsFromArray isEqualToArray:self.expectedObjects]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorMismatchedInput format:@"Array %@ does not have the expected objects at the indexes to be removed", array];

        return NO;
    }

    [array removeObjectsAtIndexes:self.removalIndexes];
    return YES;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);

    if (!self.removalIndexes)
        return YES;
    
    PROTransformationMutableArrayForKeyPathBlock mutableArrayBlock = [blocks objectForKey:PROTransformationMutableArrayForKeyPathBlockKey];
    if (!PROAssert(mutableArrayBlock, @"%@ not provided", PROTransformationMutableArrayForKeyPathBlockKey))
        return NO;

    if (!PROAssert(keyPath, @"No key path for %@", self))
        return NO;

    NSMutableArray *mutableArray = mutableArrayBlock(self, keyPath);
    [mutableArray removeObjectsAtIndexes:self.removalIndexes];
    
    return YES;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSIndexSet *removalIndexes = [coder decodeObjectForKey:@"removalIndexes"];
    NSArray *expectedObjects = [coder decodeObjectForKey:@"expectedObjects"];

    return [self initWithRemovalIndexes:removalIndexes expectedObjects:expectedObjects];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.removalIndexes)
        [coder encodeObject:self.removalIndexes forKey:@"removalIndexes"];

    if (self.expectedObjects)
        [coder encodeObject:self.expectedObjects forKey:@"expectedObjects"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ removalIndexes = %@, expectedObjects = %@ }", [self class], (__bridge void *)self, self.removalIndexes, self.expectedObjects];
}

- (NSUInteger)hash {
    return [self.removalIndexes hash] ^ [self.expectedObjects hash];
}

- (BOOL)isEqual:(PRORemovalTransformation *)transformation {
    if (![transformation isKindOfClass:[PRORemovalTransformation class]])
        return NO;

    if (!NSEqualObjects(self.removalIndexes, transformation.removalIndexes))
        return NO;

    if (!NSEqualObjects(self.expectedObjects, transformation.expectedObjects))
        return NO;

    return YES;
}

@end
