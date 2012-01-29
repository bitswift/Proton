//
//  PROUniqueTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROUniqueTransformation.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROModelController.h"
#import "PROModelControllerPrivate.h"

@implementation PROUniqueTransformation

#pragma mark Properties

@synthesize inputValue = m_inputValue;
@synthesize outputValue = m_outputValue;

- (PROTransformation *)reverseTransformation; {
    // just flip our values around
    return [[[self class] alloc] initWithInputValue:self.outputValue outputValue:self.inputValue];
}

- (NSArray *)transformations {
    // we don't have any child transformations
    return nil;
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithInputValue:nil outputValue:nil];
}

- (id)initWithInputValue:(id)inputValue outputValue:(id)outputValue; {
    self = [super init];
    if (!self)
        return nil;

    // if both are nil, leave them nil
    // if one is nil, make it NSNull
    // copy non-nil values
    if (inputValue) {
        m_inputValue = [inputValue copy];

        if (outputValue) {
            m_outputValue = [outputValue copy];
        } else {
            m_outputValue = [NSNull null];
        }
    } else if (outputValue) {
        m_inputValue = [NSNull null];
        m_outputValue = [outputValue copy];
    }

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj error:(NSError **)error; {
    if (!self.inputValue)
        return obj;

    if (![self.inputValue isEqual:obj]) {
        if (error)
            *error = [self errorWithCode:PROTransformationErrorMismatchedInput format:@"Input value %@ is not equal to expected value", obj];

        return nil;
    }

    return self.outputValue;
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    /*
     * A unique transformation can mean one of two things:
     *
     *  1. We're replacing the entire model of the model controller. In this
     *  case, we simply replace its 'model' property, and depend on the model
     *  controller to reset its own model controllers as necessary.
     *
     *  2. We're replacing a property or sub-model of the top-level model
     *  object. In this case, we need to update the reference held by the
     *  associated model controller.
     */

    if (!modelKeyPath) {
        // update the top-level model
        [modelController setModel:result replacingModelControllers:YES];
        return YES;
    }

    NSString *ownedModelControllersKey = [[[modelController class] modelControllerKeysByModelKeyPath] objectForKey:modelKeyPath];
    if (!ownedModelControllersKey)
        return NO;

    NSAssert([self.outputValue isKindOfClass:[NSArray class]], @"Model controller %@ key \"%@\" doesn't make any sense without an array at model key path \"%@\"", modelController, ownedModelControllersKey, modelKeyPath);

    Class ownedModelControllerClass = [[[modelController class] modelControllerClassesByKey] objectForKey:ownedModelControllersKey];

    NSArray *newControllers = [self.outputValue mapWithOptions:NSEnumerationConcurrent usingBlock:^(id model){
        return [[ownedModelControllerClass alloc] initWithModel:model];
    }];

    NSMutableArray *mutableControllers = [modelController mutableArrayValueForKey:ownedModelControllersKey];
    NSUInteger count = [mutableControllers count];

    // replace the controllers outright, since we replaced the associated models
    // outright
    [mutableControllers replaceObjectsInRange:NSMakeRange(0, count) withObjectsFromArray:newControllers];

    return YES;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    id inputValue = [coder decodeObjectForKey:@"inputValue"];
    id outputValue = [coder decodeObjectForKey:@"outputValue"];
    return [self initWithInputValue:inputValue outputValue:outputValue];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.inputValue)
        [coder encodeObject:self.inputValue forKey:@"inputValue"];

    if (self.outputValue)
        [coder encodeObject:self.outputValue forKey:@"outputValue"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ old = %@, new = %@ }", [self class], (__bridge void *)self, self.inputValue, self.outputValue];
}

- (NSUInteger)hash {
    return [self.inputValue hash] ^ [self.outputValue hash];
}

- (BOOL)isEqual:(PROUniqueTransformation *)transformation {
    if (![transformation isKindOfClass:[PROUniqueTransformation class]])
        return NO;

    if (!NSEqualObjects(self.inputValue, transformation.inputValue))
        return NO;

    if (!NSEqualObjects(self.outputValue, transformation.outputValue))
        return NO;

    return YES;
}

@end
