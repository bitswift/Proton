//
//  PROMultipleTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROMultipleTransformation.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROModelController.h>

@implementation PROMultipleTransformation

#pragma mark Properties

@synthesize transformations = m_transformations;

- (PROTransformation *)reverseTransformation; {
    NSMutableArray *reverseTransformations = [[NSMutableArray alloc] initWithCapacity:self.transformations.count];

    // reverse each individual transformation, and reverse their order as well
    [self.transformations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PROTransformation *transformation, NSUInteger index, BOOL *stop){
        [reverseTransformations addObject:transformation.reverseTransformation];
    }];
    
    return [[[self class] alloc] initWithTransformations:reverseTransformations];
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithTransformations:nil];
}

- (id)initWithTransformations:(NSArray *)transformations; {
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

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    id currentValue = obj;

    for (PROTransformation *transformation in self.transformations) {
        currentValue = [transformation transform:currentValue];
        if (!currentValue)
            return nil;
    }

    return currentValue;
}

- (PROTransformationBlock)transformationBlockUsingRewriterBlock:(PROTransformationRewriterBlock)block; {
    PROTransformationBlock baseTransformation = ^ id (id obj){
        id currentValue = obj;

        for (PROTransformation *transformation in self.transformations) {
            PROTransformationBlock transformationBlock = [transformation transformationBlockUsingRewriterBlock:block];

            currentValue = transformationBlock(currentValue);
            if (!currentValue)
                return nil;
        }

        return currentValue;
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

- (void)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    NSString *fullModelKeyPath = @"model";
    if (modelKeyPath)
        fullModelKeyPath = [fullModelKeyPath stringByAppendingFormat:@".%@", modelKeyPath];

    id currentValue = [modelController valueForKeyPath:fullModelKeyPath];

    NSAssert([[self transform:currentValue] isEqual:result], @"Model at key path \"%@\" on %@ does not match the original value passed into %@", modelKeyPath, modelController, self);

    for (PROTransformation *transformation in self.transformations) {
        /*
         * Unfortunately, for a multiple transformation, we have to redo the
         * actual work in order to properly step the 'transformationResult'
         * parameter and be able to apply the effects of our children to the
         * model controller.
         */
        currentValue = [transformation transform:currentValue];

        [transformation updateModelController:modelController transformationResult:currentValue forModelKeyPath:modelKeyPath];
    }
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSArray *transformations = [coder decodeObjectForKey:@"transformations"];
    return [self initWithTransformations:transformations];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.transformations)
        [coder encodeObject:self.transformations forKey:@"transformations"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>: %@", [self class], (__bridge void *)self, self.transformations];
}

- (NSUInteger)hash {
    return [self.transformations hash];
}

- (BOOL)isEqual:(PROMultipleTransformation *)transformation {
    if (![transformation isKindOfClass:[PROMultipleTransformation class]])
        return NO;

    return NSEqualObjects(self.transformations, transformation.transformations);
}

@end
