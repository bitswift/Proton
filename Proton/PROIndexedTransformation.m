//
//  PROIndexedTransformation.m
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROIndexedTransformation.h>
#import <Proton/EXTScope.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROModelController.h>

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

        id result = [transformation transform:inputValue error:error];
        if (!result) {
            newArray = nil;

            *stop = YES;
            return;
        }

        [newArray replaceObjectAtIndex:index withObject:result];
    }];

    return [newArray copy];
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    /*
     * An indexed transformation usually means that we're starting to get to
     * a nested model (e.g., model.submodels[index]), so we need to descend into
     * the specific model controller associated with that nested model (e.g.,
     * modelControllers[index]).
     */

    if (!modelKeyPath)
        return NO;

    NSString *ownedModelControllersKey = [[[modelController class] modelControllerKeysByModelKeyPath] objectForKey:modelKeyPath];
    if (!ownedModelControllersKey)
        return NO;

    NSArray *associatedControllers = [modelController valueForKey:ownedModelControllersKey];
    NSAssert([associatedControllers count] == [result count], @"Should be exactly as many model controllers at key path \"%@\" from %@ as models at key path \"%@\": %@", ownedModelControllersKey, modelController, modelKeyPath, result);

    NSUInteger indexCount = [self.indexes count];
    
    // we have to copy the indexes into a C array, since there's no way to
    // retrieve values from it one-by-one
    NSUInteger *indexes = malloc(sizeof(*indexes) * indexCount);
    if (!indexes) {
        return NO;
    }

    @onExit {
        free(indexes);
    };

    [self.indexes getIndexes:indexes maxCount:indexCount inIndexRange:nil];

    [self.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformation, NSUInteger setIndex, BOOL *stop){
        /*
         * For each sub-transformation, update the nested model controller with
         * that transformation's result.
         */

        NSUInteger index = indexes[setIndex];
        id object = [result objectAtIndex:index];

        PROModelController *controller = [associatedControllers objectAtIndex:index];
        if (![transformation updateModelController:controller transformationResult:object forModelKeyPath:nil]) {
            // no model below here, so update the top-level object
            controller.model = object;
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
