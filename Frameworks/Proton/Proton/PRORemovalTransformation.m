//
//  PRORemovalTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PRORemovalTransformation.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROInsertionTransformation.h>
#import <Proton/PROModelController.h>

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

- (id)transform:(id)array; {
    if (!self.removalIndexes)
        return array;

    if (![array isKindOfClass:[NSArray class]])
        return nil;

    NSUInteger count = [array count];

    // if the index set goes out of bounds, return nil
    if ([self.removalIndexes lastIndex] >= count)
        return nil;

    // if one or more objects doesn't match, return nil
    NSArray *objectsFromArray = [array objectsAtIndexes:self.removalIndexes];
    if (![objectsFromArray isEqualToArray:self.expectedObjects])
        return nil;

    NSMutableArray *newArray = [array mutableCopy];
    [newArray removeObjectsAtIndexes:self.removalIndexes];

    return [newArray copy];
}

- (void)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    /*
     * A removal transformation means that we're going to be removing objects
     * from an array of the model (e.g., model.submodels), so we need to remove
     * the associated model controllers from the same indexes.
     */

    if (!modelKeyPath)
        return;

    NSString *ownedModelControllersKeyPath = [modelController modelControllersKeyPathForModelKeyPath:modelKeyPath];
    if (!ownedModelControllersKeyPath)
        return;

    NSMutableArray *associatedControllers = [modelController mutableArrayValueForKeyPath:ownedModelControllersKeyPath];
    [associatedControllers removeObjectsAtIndexes:self.removalIndexes];
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
