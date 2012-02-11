//
//  PROIndexedTransformation.m
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROIndexedTransformation.h"
#import "EXTScope.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROModelController.h"

@interface PROIndexedTransformation ()
/**
 * Transforms the given array in-place, optionally also mutating the actual
 * indexes of the array in-place as well.
 *
 * @param objPtr A pointer to the object to attempt to transform. This may be
 * set if the transformation cannot be performed in-place. This pointer should
 * not be `NULL`, nor should the object it points to be `nil`. **If the
 * transformation fails, this object may be left in an invalid state.**
 * @param deeplyMutable Whether indexes of the array are expected to be mutable,
 * and should thus be modified in-place as well.
 * @param error If not `NULL`, and this method returns `NO`, this is set to the
 * error that occurred if the receiver (or one of its <transformations>) failed.
 * **This error should not be presented to the user**, as it is unlikely to
 * contain useful information for them.
 */
- (BOOL)transformInPlace:(id *)objPtr deeplyMutable:(BOOL)deeplyMutable error:(NSError **)error;
@end

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

- (id)transform:(NSArray *)array error:(NSError **)error; {
    // Return the unmodified object if indexes is nil
    if (!self.indexes)
        return array;

    if (![array isKindOfClass:[NSArray class]]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ is not an array", array];

        return nil;
    }

    NSMutableArray *newArray = [array mutableCopy];
    if ([self transformInPlace:&newArray deeplyMutable:NO error:error])
        return [newArray copy];
    else
        return nil;
}

- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error; {
    return [self transformInPlace:objPtr deeplyMutable:YES error:error];
}

- (BOOL)transformInPlace:(id *)objPtr deeplyMutable:(BOOL)deeplyMutable error:(NSError **)error; {
    NSParameterAssert(objPtr != NULL);

    if (!self.indexes)
        return YES;

    NSMutableArray *array = *objPtr;

    if (![array isKindOfClass:[NSArray class]]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorUnsupportedInputType format:@"%@ is not an array", array];

        return NO;
    }

    NSUInteger arrayCount = [array count];

    // if the index set goes out of bounds, return nil
    if (self.indexes.lastIndex >= arrayCount) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorIndexOutOfBounds format:@"Index %lu is out of bounds for array %@", (unsigned long)self.indexes.lastIndex, array];

        return NO;
    }

    NSUInteger indexCount = [self.indexes count];

    // we have to copy the indexes into a C array, since there's no way to
    // retrieve values from it one-by-one
    NSUInteger *indexes = malloc(sizeof(*indexes) * indexCount);
    if (!PROAssert(indexes, @"Could not allocate memory for %lu indexes", (unsigned long)indexCount)) {
        return NO;
    }

    @onExit {
        free(indexes);
    };

    [self.indexes getIndexes:indexes maxCount:indexCount inIndexRange:nil];

    __block BOOL success = YES;
    __block NSError *strongError = nil;

    [self.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformation, NSUInteger setIndex, BOOL *stop){
        NSUInteger index = indexes[setIndex];
        id inputValue = [array objectAtIndex:index];

        id newValue;

        if (deeplyMutable) {
            newValue = inputValue;
            success = [transformation transformInPlace:&newValue error:&strongError];
        } else {
            newValue = [transformation transform:inputValue error:&strongError];
            success = (newValue != nil);
        }

        if (!success) {
            *stop = YES;

            if (strongError) {
                NSString *path = [NSString stringWithFormat:@"[%lu]", (unsigned long)setIndex];
                strongError = [self prependTransformationPath:path toError:strongError];
            }

            return;
        }

        if (newValue != inputValue)
            [array replaceObjectAtIndex:index withObject:newValue];
    }];

    if (error && strongError) {
        *error = strongError;
    }

    return success;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSParameterAssert(result != nil);

    if (!PROAssert(keyPath, @"No key path for %@", self))
        return NO;

    PROTransformationBlocksForIndexAtKeyPathBlock blocksForIndexBlock = [blocks objectForKey:PROTransformationBlocksForIndexAtKeyPathBlockKey];
    if (!PROAssert(blocksForIndexBlock, @"%@ not provided", PROTransformationBlocksForIndexAtKeyPathBlockKey))
        return NO;
    
    PROTransformationMutableArrayForKeyPathBlock mutableArrayBlock = [blocks objectForKey:PROTransformationMutableArrayForKeyPathBlockKey];
    if (!PROAssert(mutableArrayBlock, @"%@ not provided", PROTransformationMutableArrayForKeyPathBlockKey))
        return NO;

    NSMutableArray *mutableArray = mutableArrayBlock(keyPath);
    NSUInteger indexCount = [self.indexes count];
    
    // we have to copy the indexes into a C array, since there's no way to
    // retrieve values from it one-by-one
    NSUInteger *indexes = malloc(sizeof(*indexes) * indexCount);
    if (!PROAssert(indexes, @"Could not allocate space for %lu indexes", (unsigned long)indexCount)) {
        return NO;
    }

    @onExit {
        free(indexes);
    };

    [self.indexes getIndexes:indexes maxCount:indexCount inIndexRange:nil];

    [self.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformation, NSUInteger setIndex, BOOL *stop){
        NSUInteger index = indexes[setIndex];
        id object = [result objectAtIndex:index];

        NSDictionary *newBlocks = blocksForIndexBlock(index, keyPath, blocks);
        if (![transformation applyBlocks:newBlocks transformationResult:object keyPath:nil]) {
            // fall back to updating the top-level object
            PROTransformationNewValueForKeyPathBlock newValueBlock = [newBlocks objectForKey:PROTransformationNewValueForKeyPathBlockKey];
            if (PROAssert(newValueBlock, @"%@ not provided", PROTransformationNewValueForKeyPathBlockKey)) {
                newValueBlock(object, nil);
            }
        }
    }];

    return YES;
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
