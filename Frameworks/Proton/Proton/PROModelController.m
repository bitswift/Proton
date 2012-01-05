//
//  PROModelController.m
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Emerald Lark. All rights reserved.
//

#import <Proton/PROModelController.h>
#import <Proton/PROKeyValueCodingMacros.h>
#import <Proton/PROModel.h>
#import <Proton/PROTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <Proton/SDQueue.h>

@implementation PROModelController

#pragma mark Properties

@synthesize dispatchQueue = m_dispatchQueue;
@synthesize model = m_model;

- (id)model {
    __block id model;

    [self.dispatchQueue runSynchronously:^{
        model = m_model;
    }];

    return model;
}

- (void)setModel:(id)newModel {
    NSParameterAssert([newModel isKindOfClass:[PROModel class]]);

    [self.dispatchQueue runSynchronously:^{
        // invoke KVO methods while on the dispatch queue, so synchronous
        // observers can perform operations that will be atomic with this method
        [self willChangeValueForKey:PROKeyForObject(self, model)];

        m_model = [newModel copy];
        
        [self didChangeValueForKey:PROKeyForObject(self, model)];
    }];
}

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_dispatchQueue = [[SDQueue alloc] init];
    return self;
}

- (id)initWithModel:(PROModel *)model {
    self = [self init];
    if (!self)
        return nil;

    self.model = model;
    return self;
}

#pragma mark Model controllers

- (Class)modelControllerClassAtKeyPath:(NSString *)modelControllersKeyPath; {
    NSAssert(NO, @"%s must be implemented if -modelControllersKeyPathForModelKeyPath: returns non-nil", __func__);
    return nil;
}

- (NSString *)modelControllersKeyPathForModelKeyPath:(NSString *)modelsKeyPath; {
    return nil;
}

#pragma mark Transformations

- (BOOL)performTransformation:(PROTransformation *)transformation; {
    __block BOOL success = NO;
    
    // TODO: seems like this should synchronize with child model controllers as
    // well, to prevent deadlocks from jumping back and forth
    [self.dispatchQueue runSynchronously:^{
        id model = [transformation transform:self.model];

        if (!model) {
            // fail immediately, before any side effects
            success = NO;
            return;
        }

        if ([transformation isKindOfClass:[PROUniqueTransformation class]]) {
            // for a unique transformation, we want to use the proper setter for
            // 'model' to make sure that all model controllers are replaced
            self.model = model;
        } else {
            // for any other kind of transformation, we don't necessarily want
            // to replace all of the model controllers
            [self willChangeValueForKey:PROKeyForObject(self, model)];

            m_model = model;
            [transformation updateModelController:self transformationResult:model forModelKeyPath:nil];

            [self didChangeValueForKey:PROKeyForObject(self, model)];
        }

        success = YES;
    }];

    return success;
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    // nothing will actually be done with this nil value -- we just need the
    // first argument to PROKeyForObject() to be the TYPE of an instance
    PROModelController *controller = nil;
    NSString *modelKey = PROKeyForObject(controller, model);

    if ([key isEqualToString:modelKey]) {
        // don't auto-generate KVO notifications when changing 'model' -- we'll
        // do it ourselves
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:key];
}

@end
