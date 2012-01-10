//
//  PROModelController.m
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Emerald Lark. All rights reserved.
//

#import <Proton/PROModelController.h>
#import <Proton/EXTScope.h>
#import <Proton/PROKeyValueCodingMacros.h>
#import <Proton/PROModel.h>
#import <Proton/PROTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <Proton/SDQueue.h>

/*
 * A key into the thread dictionary, associated with an `NSNumber` indicating
 * whether the current thread is performing a transformation.
 *
 * Used to implement <[PROModelController performingTransformation]>.
 */
static NSString * const PROModelControllerPerformingTransformationKey = @"PROModelControllerPerformingTransformation";

@interface PROModelController ()
/*
 * Whether <performTransformation:> is currently being executed on the
 * <dispatchQueue>.
 *
 * @warning **Important:** This should only be read or written while already
 * running on <dispatchQueue>. Use <performingTransformation> in all other
 * cases.
 */
@property (nonatomic, assign, getter = isPerformingTransformationOnDispatchQueue) BOOL performingTransformationOnDispatchQueue;
@end

@implementation PROModelController

#pragma mark Properties

@synthesize dispatchQueue = m_dispatchQueue;
@synthesize model = m_model;
@synthesize performingTransformationOnDispatchQueue = m_performingTransformationOnDispatchQueue;

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

- (BOOL)isPerformingTransformation {
    if (![self.dispatchQueue isCurrentQueue]) {
        // impossible that a transformation could be getting performed on the
        // current thread if we're not on the dispatch queue
        return NO;
    }

    return self.performingTransformationOnDispatchQueue;
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

+ (NSDictionary *)modelControllerClassesByKey; {
    NSAssert(NO, @"%s must be implemented if +modelControllerKeysByModelKeyPath returns non-nil", __func__);
    return nil;
}

+ (NSDictionary *)modelControllerKeysByModelKeyPath; {
    return nil;
}

#pragma mark Transformations

- (BOOL)performTransformation:(PROTransformation *)transformation; {
    NSAssert(!self.performingTransformation, @"%s should not be invoked recursively", __func__);

    __block BOOL success = NO;
    
    // TODO: seems like this should synchronize with child model controllers as
    // well, to prevent deadlocks from jumping back and forth
    [self.dispatchQueue runSynchronously:^{
        self.performingTransformationOnDispatchQueue = YES;

        @onExit {
            self.performingTransformationOnDispatchQueue = NO;
        };

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

            // TODO: changing this as an ivar sucks!
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
