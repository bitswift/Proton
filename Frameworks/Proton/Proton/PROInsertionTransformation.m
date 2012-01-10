//
//  PROInsertionTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROInsertionTransformation.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROModelController.h>
#import <Proton/PRORemovalTransformation.h>

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

- (id)transform:(id)array; {
    // if we don't have indexes, pass all objects through
    if (!self.insertionIndexes)
        return array;

    if (![array isKindOfClass:[NSArray class]])
        return nil;

    NSUInteger count = [array count];

    // if the index set goes out of bounds (including empty slots at the end
    // for insertion), return nil
    if ([self.insertionIndexes lastIndex] >= count + [self.insertionIndexes count])
        return nil;

    NSMutableArray *newArray = [array mutableCopy];
    [newArray insertObjects:self.objects atIndexes:self.insertionIndexes];

    return [newArray copy];
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    /*
     * An insertion transformation means that we're going to be inserting
     * objects into an array of the model (e.g., model.submodels), so we need to
     * create and insert a new model controller for each such insertion.
     */

    if (!modelKeyPath)
        return NO;

    NSString *ownedModelControllersKey = [[[modelController class] modelControllerKeysByModelKeyPath] objectForKey:modelKeyPath];
    if (!ownedModelControllersKey)
        return NO;

    Class ownedModelControllerClass = [[[modelController class] modelControllerClassesByKey] objectForKey:ownedModelControllersKey];

    NSArray *newControllers = [self.objects mapWithOptions:NSEnumerationConcurrent usingBlock:^(id model){
        return [[ownedModelControllerClass alloc] initWithModel:model];
    }];

    NSMutableArray *mutableControllers = [modelController mutableArrayValueForKey:ownedModelControllersKey];
    [mutableControllers insertObjects:newControllers atIndexes:self.insertionIndexes];

    return YES;
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
