//
//  PROInsertionTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROInsertionTransformation.h"
#import "EXTScope.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PRORemovalTransformation.h"
#import "PROTransformationProtected.h"

@implementation PROInsertionTransformation

#pragma mark Properties

@synthesize insertionIndexes = m_insertionIndexes;
@synthesize objects = m_objects;

- (PROTransformation *)reverseTransformation; {
    return [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.insertionIndexes expectedObjects:self.objects];
}

- (NSArray *)transformations {
    // we don't have any child transformations
    return nil;
}

#pragma mark Initialization

- (id)init; {
    return [self initWithInsertionIndexes:nil objects:nil];
}

- (id)initWithInsertionIndex:(NSUInteger)index object:(id)object; {
    if (!object)
        return [self init];

    return [self initWithInsertionIndexes:[NSIndexSet indexSetWithIndex:index] objects:[NSArray arrayWithObject:object]];
}

- (id)initWithInsertionIndexes:(NSIndexSet *)insertionIndexes objects:(NSArray *)objects; {
    NSParameterAssert([insertionIndexes count] == [objects count]);

    self = [super init];
    if (!self)
        return nil;

    // don't save empty collections -- consider them to be nil instead
    if ([insertionIndexes count])
        m_insertionIndexes = [insertionIndexes copy];

    if ([objects count])
        m_objects = [objects copy];

    return self;
}

#pragma mark Transformation

- (id)transform:(NSArray *)array error:(NSError **)error; {
    // if we don't have indexes, pass all objects through
    if (!self.insertionIndexes)
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

    if (!self.insertionIndexes)
        return YES;

    NSMutableArray *array = *objPtr;
    if (![array isKindOfClass:[NSArray class]]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ is not an array", array];

        return NO;
    }

    NSUInteger count = [array count];

    // if the index set goes out of bounds (including empty slots at the end
    // for insertion), return nil
    if ([self.insertionIndexes lastIndex] >= count + [self.insertionIndexes count]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorIndexOutOfBounds format:@"Index %lu is out of bounds for array %@", (unsigned long)self.insertionIndexes.lastIndex, array];

        return NO;
    }

    [array insertObjects:self.objects atIndexes:self.insertionIndexes];
    return YES;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);
    
    PROTransformationMutableArrayForKeyPathBlock mutableArrayBlock = [blocks objectForKey:PROTransformationMutableArrayForKeyPathBlockKey];
    if (!PROAssert(mutableArrayBlock, @"%@ not provided", PROTransformationMutableArrayForKeyPathBlockKey))
        return NO;
    
    PROTransformationWrappedValueForKeyPathBlock wrappedValueBlock = [blocks objectForKey:PROTransformationWrappedValueForKeyPathBlockKey];
    if (!PROAssert(wrappedValueBlock, @"%@ not provided", PROTransformationWrappedValueForKeyPathBlockKey))
        return NO;

    if (!PROAssert(keyPath, @"No key path for %@", self))
        return NO;

    NSArray *newObjects = [self.objects mapUsingBlock:^(id obj){
        return wrappedValueBlock(self, obj, keyPath);
    }];

    NSMutableArray *mutableArray = mutableArrayBlock(self, keyPath);
    [mutableArray insertObjects:newObjects atIndexes:self.insertionIndexes];
    
    return YES;
}

- (PROTransformation *)coalesceWithTransformation:(id)transformation; {
    if ([transformation isKindOfClass:[PRORemovalTransformation class]]) {
        PRORemovalTransformation *removalTransformation = transformation;

        if ([self.insertionIndexes containsIndexes:removalTransformation.removalIndexes]) {
            // find indexes and objects that would remain even after the
            // removal, and create a new insertion from just those
            NSMutableIndexSet *newIndexes = [NSMutableIndexSet indexSet];
            NSMutableArray *newObjects = [NSMutableArray array];

            __block NSUInteger setIndex = 0;
            __block BOOL compatible = YES;
            
            [self.insertionIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
                @onExit {
                    ++setIndex;
                };

                if ([removalTransformation.removalIndexes containsIndex:index]) {
                    compatible = NSEqualObjects([self.objects objectAtIndex:setIndex], [removalTransformation.expectedObjects objectAtIndex:setIndex]);
                    if (!compatible)
                        *stop = YES;
                } else {
                    [newIndexes addIndex:index];
                    [newObjects addObject:[self.objects objectAtIndex:setIndex]];
                }
            }];
            
            if (compatible) {
                return [[PROInsertionTransformation alloc] initWithInsertionIndexes:newIndexes objects:newObjects];
            }
        } else if ([removalTransformation.removalIndexes containsIndexes:self.insertionIndexes]) {
            // find indexes and objects that would be removed regardless of the
            // insertion, and create a new removal from just those
            NSMutableIndexSet *newIndexes = [NSMutableIndexSet indexSet];
            NSMutableArray *newObjects = [NSMutableArray array];

            __block NSUInteger setIndex = 0;
            __block BOOL compatible = YES;
            
            [removalTransformation.removalIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
                @onExit {
                    ++setIndex;
                };

                if ([self.insertionIndexes containsIndex:index]) {
                    compatible = NSEqualObjects([self.objects objectAtIndex:setIndex], [removalTransformation.expectedObjects objectAtIndex:setIndex]);
                    if (!compatible)
                        *stop = YES;
                } else {
                    [newIndexes addIndex:index];
                    [newObjects addObject:[removalTransformation.expectedObjects objectAtIndex:setIndex]];
                }
            }];
            
            if (compatible) {
                return [[PRORemovalTransformation alloc] initWithRemovalIndexes:newIndexes expectedObjects:newObjects];
            }
        }

        return nil;
    }

    if (![transformation isKindOfClass:[PROInsertionTransformation class]]) {
        return nil;
    }

    PROInsertionTransformation *insertionTransformation = transformation;

    NSMutableIndexSet *newIndexes = [self.insertionIndexes mutableCopy];
    NSMutableArray *newObjects = [NSMutableArray arrayWithCapacity:self.objects.count + insertionTransformation.objects.count];

    [newObjects addObjectsFromArray:self.objects];

    __block NSUInteger originalArrayIndex = 0;
    [insertionTransformation.insertionIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop){
        @onExit {
            ++originalArrayIndex;
        };

        if (index < newIndexes.lastIndex) {
            [newIndexes shiftIndexesStartingAtIndex:index by:1];
        }

        [newIndexes addIndex:index];

        // go back through the index set, and figure out _where_ in the index
        // set this index is -- that position is where in the array we should
        // insert
        //
        // TODO: this could be optimized
        __block NSUInteger newArrayIndex = 0;
        [newIndexes enumerateIndexesUsingBlock:^(NSUInteger testIndex, BOOL *stop){
            if (testIndex == index) {
                *stop = YES;
                return;
            }

            ++newArrayIndex;
        }];

        id object = [insertionTransformation.objects objectAtIndex:originalArrayIndex];
        [newObjects insertObject:object atIndex:newArrayIndex];
    }];

    return [[PROInsertionTransformation alloc] initWithInsertionIndexes:newIndexes objects:newObjects];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSIndexSet *insertionIndexes = [coder decodeObjectForKey:@"insertionIndexes"];
    NSArray *objects = [coder decodeObjectForKey:@"objects"];

    return [self initWithInsertionIndexes:insertionIndexes objects:objects];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.insertionIndexes)
        [coder encodeObject:self.insertionIndexes forKey:@"insertionIndexes"];

    if (self.objects)
        [coder encodeObject:self.objects forKey:@"objects"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ insertionIndexes = %@, objects = %@ }", [self class], (__bridge void *)self, self.insertionIndexes, self.objects];
}

- (NSUInteger)hash {
    return [self.insertionIndexes hash] ^ [self.objects hash];
}

- (BOOL)isEqual:(PROInsertionTransformation *)transformation {
    if (![transformation isKindOfClass:[PROInsertionTransformation class]])
        return NO;

    if (!NSEqualObjects(self.insertionIndexes, transformation.insertionIndexes))
        return NO;

    if (!NSEqualObjects(self.objects, transformation.objects))
        return NO;

    return YES;
}

@end
