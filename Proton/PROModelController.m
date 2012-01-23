//
//  PROModelController.m
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROModelController.h>
#import <Proton/EXTScope.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/PROAssert.h>
#import <Proton/PROIndexedTransformation.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROKeyValueCodingMacros.h>
#import <Proton/PROKeyValueObserver.h>
#import <Proton/PROLogging.h>
#import <Proton/PROModel.h>
#import <Proton/PROTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <Proton/SDQueue.h>
#import <objc/runtime.h>

/*
 * A key into the thread dictionary, associated with an `NSNumber` indicating
 * whether the current thread is performing a transformation.
 *
 * Used to implement <[PROModelController performingTransformation]>.
 */
static NSString * const PROModelControllerPerformingTransformationKey = @"PROModelControllerPerformingTransformation";

@interface PROModelController ()
/*
 * Automatically implements the appropriate KVC-compliant model controller
 * methods on the receiver for the given model controller key.
 *
 * @param key A key present in <modelControllerClassesByKey>, indicating the
 * name of the model controller array property.
 * @param modelKeyPath The key path, relative to the <model>, where the model
 * objects managed by this array of model controllers are.
 */
+ (void)implementModelControllerMethodsForKey:(NSString *)key modelKeyPath:(NSString *)modelKeyPath;

/*
 * Replaces the <model>, optionally updating other model controllers on the
 * receiver to match.
 *
 * @param model The new model object to set on the receiver.
 * @param replacing If `YES`, all existing model controllers will be destroyed
 * and recreated from the models in `model`. If `NO`, model controllers are
 * assumed to be updated elsewhere, and will not be modified.
 */
- (void)setModel:(PROModel *)model replacingModelControllers:(BOOL)replacing;

/*
 * Contains <PROKeyValueObserver> objects observing each model controller
 * managed by the receiver (in no particular order).
 *
 * Notifications from these observers will be posted synchronously.
 *
 * @warning **Important:** Mutation of this array must be synchronized using the
 * receiver's <dispatchQueue>.
 */
@property (nonatomic, strong) NSMutableArray *modelControllerObservers;

/*
 * Whether <performTransformation:error:> is currently being executed on the
 * <dispatchQueue>.
 *
 * @warning **Important:** This should only be read or written while already
 * running on <dispatchQueue>. Use <performingTransformation> in all other
 * cases.
 */
@property (nonatomic, assign, getter = isPerformingTransformationOnDispatchQueue) BOOL performingTransformationOnDispatchQueue;
@end

@implementation PROModelController

#pragma mark Class initialization

+ (void)initialize {
    // automatically set up model controller properties for subclasses
    NSDictionary *modelControllerKeys = [self modelControllerKeysByModelKeyPath];
    if (![modelControllerKeys count])
        return;

    for (NSString *modelKeyPath in modelControllerKeys) {
        NSString *modelControllerKey = [modelControllerKeys objectForKey:modelKeyPath];

        SEL getterSelector = NSSelectorFromString(modelControllerKey);
        if ([self instancesRespondToSelector:getterSelector]) {
            // this property is implemented already
            continue;
        }

        [self implementModelControllerMethodsForKey:modelControllerKey modelKeyPath:modelKeyPath];
    }
}

#pragma mark Properties

@synthesize dispatchQueue = m_dispatchQueue;
@synthesize model = m_model;
@synthesize modelControllerObservers = m_modelControllerObservers;
@synthesize performingTransformationOnDispatchQueue = m_performingTransformationOnDispatchQueue;

- (id)model {
    __block id model;

    [self.dispatchQueue runSynchronously:^{
        model = m_model;
    }];

    return model;
}

- (void)setModel:(id)newModel {
    [self setModel:newModel replacingModelControllers:YES];
}

- (void)setModel:(PROModel *)newModel replacingModelControllers:(BOOL)replacing; {
    NSParameterAssert(!newModel || [newModel isKindOfClass:[PROModel class]]);

    [self.dispatchQueue runSynchronously:^{
        // invoke KVO methods while on the dispatch queue, so synchronous
        // observers can perform operations that will be atomic with this method
        [self willChangeValueForKey:PROKeyForObject(self, model)];

        @onExit {
            [self didChangeValueForKey:PROKeyForObject(self, model)];
        };

        m_model = [newModel copy];

        if (replacing) {
            // figure out where the model controllers are, and replace them all
            NSDictionary *modelControllerKeys = [[self class] modelControllerKeysByModelKeyPath];
            if (![modelControllerKeys count])
                return;

            NSDictionary *modelControllerClasses = [[self class] modelControllerClassesByKey];

            for (NSString *modelKeyPath in modelControllerKeys) {
                NSString *modelControllerKey = [modelControllerKeys objectForKey:modelKeyPath];
                Class modelControllerClass = [modelControllerClasses objectForKey:modelControllerKey];

                NSArray *models = [m_model valueForKeyPath:modelKeyPath];

                NSAssert(!models || [models isKindOfClass:[NSArray class]], @"Model key path \"%@\", bound to model controller key \"%@\", should be associated with an array: %@", modelKeyPath, modelControllerKey, models);

                NSArray *newModelControllers = [models mapWithOptions:NSEnumerationConcurrent usingBlock:^(PROModel *model){
                    return [[modelControllerClass alloc] initWithModel:model];
                }];

                NSMutableArray *modelControllers = [self mutableArrayValueForKey:modelControllerKey];
                [modelControllers replaceObjectsInRange:NSMakeRange(0, modelControllers.count) withObjectsFromArray:newModelControllers];
            }
        }
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

- (void)dealloc {
    // make sure to tear down model controller observers first thing
    self.modelControllerObservers = nil;
}

#pragma mark Model controllers

+ (void)implementModelControllerMethodsForKey:(NSString *)key modelKeyPath:(NSString *)modelKeyPath; {
    NSAssert([key length] > 0, @"Should be at least one character in model controller key");
    NSAssert([modelKeyPath length] > 0, @"Should be at least one character in model key path");

    Class controllerClass = [[self modelControllerClassesByKey] objectForKey:key];
    NSAssert(controllerClass, @"Model controller class should not be nil for key \"%@\"", key);

    NSMutableString *capitalizedKey = [[NSMutableString alloc] init];
    [capitalizedKey appendString:[[key substringToIndex:1] uppercaseString]];
    [capitalizedKey appendString:[key substringFromIndex:1]];

    SEL getterSelector = NSSelectorFromString(key);
    SEL insertControllerSelector = NSSelectorFromString([NSString stringWithFormat:@"insertObject:in%@AtIndex:", capitalizedKey]);

    // TODO: should this implement the (presumably faster) plural form?
    SEL removeControllerSelector = NSSelectorFromString([NSString stringWithFormat:@"removeObjectFrom%@AtIndex:", capitalizedKey]);

    void (^installBlockMethod)(SEL, id, NSString *) = ^(SEL selector, id block, NSString *typeEncoding){
        // purposely leaks (since methods, by their nature, are never really "released")
        IMP methodIMP = imp_implementationWithBlock((__bridge_retained void *)block);

        if (!class_addMethod(self, selector, methodIMP, [typeEncoding UTF8String])) {
            DDLogError(@"Could not add method %s to %@ -- perhaps it already exists?", selector, self);
        }
    };

    /*
     * Returns the mutable array for model controllers of this class, creating
     * it first if necessary.
     *
     * Use of this block should be synchronized with the <dispatchQueue> of the
     * instance.
     *
     * @warning **Important:** This is not actually a public method -- just an
     * internal helper block.
     */
    NSMutableArray *(^modelControllersArray)(PROModelController *) = ^(PROModelController *self){
        NSMutableArray *array = objc_getAssociatedObject(self, getterSelector);
        if (!array) {
            array = [[NSMutableArray alloc] init];

            objc_setAssociatedObject(self, getterSelector, array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        return array;
    };

    /*
     * Public getter for the model controllers.
     */
    id getter = ^(PROModelController *self){
        __block NSArray *controllers;

        [self.dispatchQueue runSynchronously:^{
            controllers = [modelControllersArray(self) copy];
        }];

        return controllers;
    };

    installBlockMethod(getterSelector, getter, [NSString stringWithFormat:
        // NSArray * (*)(PROModelController *self, SEL _cmd)
        @"%s%s%s",
        @encode(NSArray *),
        @encode(PROModelController *),
        @encode(SEL)
    ]);

    /*
     * KVC-compliant method for adding a new model controller to an instance.
     */
    id insertController = ^(PROModelController *self, PROModelController *controller, NSUInteger index){
        __weak PROModelController *weakSelf = self;

        // observe the model property of the controller
        PROKeyValueObserver *observer = [[PROKeyValueObserver alloc]
            initWithTarget:controller
            keyPath:PROKeyForObject(controller, model)
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            block:^(NSDictionary *changes){
                if (weakSelf.performingTransformation) {
                    // ignore changes that were instigated by ourselves in
                    // -performTransformation:error:
                    return;
                }

                PROModel *oldSubModel = [changes objectForKey:NSKeyValueChangeOldKey];
                PROModel *newSubModel = [changes objectForKey:NSKeyValueChangeNewKey];

                // synchronize our replacement of the model object
                [weakSelf.dispatchQueue runSynchronously:^{
                    NSArray *models = [weakSelf.model valueForKeyPath:modelKeyPath];
                    NSUInteger index = [models indexOfObjectIdenticalTo:oldSubModel];

                    if (index == NSNotFound) {
                        DDLogWarn(@"Could not find model object %@ to replace in array: %@", oldSubModel, models);
                        return;
                    }

                    PROUniqueTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:oldSubModel outputValue:newSubModel];
                    PROIndexedTransformation *modelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:modelsTransformation forKeyPath:modelKeyPath];

                    PROModel *newModel = [modelTransformation transform:weakSelf.model error:NULL];
                    if (!newModel) {
                        DDLogError(@"Could not create new model object from %@ with transformation %@", weakSelf.model, modelTransformation);
                    }

                    // the model controllers are already up-to-date; we just
                    // want to drop in the new model object
                    [self setModel:newModel replacingModelControllers:NO];
                }];
            }
        ];

        // post synchronously
        observer.queue = nil;

        [self.dispatchQueue runSynchronously:^{
            [modelControllersArray(self) insertObject:controller atIndex:index];

            if (!self.modelControllerObservers)
                self.modelControllerObservers = [[NSMutableArray alloc] init];

            // this array is unordered
            [self.modelControllerObservers addObject:observer];
        }];
    };

    installBlockMethod(insertControllerSelector, insertController, [NSString stringWithFormat:
        // void (*)(PROModelController *self, SEL _cmd, PROModelController *controller, NSUInteger index)
        @"%s%s%s%s%s",
        @encode(void),
        @encode(PROModelController *),
        @encode(SEL),
        @encode(PROModelController *),
        @encode(NSUInteger)
    ]);

    /*
     * KVC-compliant method for removing a model controller from an instance.
     */
    id removeController = ^(PROModelController *self, NSUInteger index) {
        [self.dispatchQueue runSynchronously:^{
            NSMutableArray *controllers = modelControllersArray(self);
            id controller = [controllers objectAtIndex:index];

            // find and tear down the observer first
            NSUInteger observerIndex = [self.modelControllerObservers
                indexOfObjectWithOptions:NSEnumerationConcurrent
                passingTest:^ BOOL (PROKeyValueObserver *observer, NSUInteger index, BOOL *stop){
                    return observer.target == controller;
                }
            ];

            if (observerIndex != NSNotFound)
                [self.modelControllerObservers removeObjectAtIndex:observerIndex];

            [controllers removeObjectAtIndex:index];
        }];
    };

    installBlockMethod(removeControllerSelector, removeController, [NSString stringWithFormat:
        // void (*)(PROModelController *self, SEL _cmd, NSUInteger index)
        @"%s%s%s%s",
        @encode(void),
        @encode(PROModelController *),
        @encode(SEL),
        @encode(NSUInteger)
    ]);
}

+ (NSDictionary *)modelControllerClassesByKey; {
    NSAssert(NO, @"%s must be implemented if +modelControllerKeysByModelKeyPath returns non-nil", __func__);
    return nil;
}

+ (NSDictionary *)modelControllerKeysByModelKeyPath; {
    return nil;
}

#pragma mark Transformations

- (BOOL)performTransformation:(PROTransformation *)transformation error:(NSError **)error; {
    NSAssert(!self.performingTransformation, @"%s should not be invoked recursively", __func__);

    __block BOOL success = YES;
    
    // TODO: seems like this should synchronize with child model controllers as
    // well, to prevent deadlocks from jumping back and forth
    [self.dispatchQueue runSynchronously:^{
        self.performingTransformationOnDispatchQueue = YES;

        @onExit {
            self.performingTransformationOnDispatchQueue = NO;
        };

        PROModel *oldModel = self.model;
        PROModel *newModel = [transformation transform:oldModel error:error];

        if (!newModel) {
            // fail immediately, before any side effects
            success = NO;
            return;
        }

        if ([transformation isKindOfClass:[PROUniqueTransformation class]]) {
            // for a unique transformation, we want to use the proper setter for
            // 'model' to make sure that all model controllers are replaced
            self.model = newModel;
        } else {
            // for any other kind of transformation, we don't necessarily want
            // to replace all of the model controllers
            [self setModel:newModel replacingModelControllers:NO];

            success = [transformation updateModelController:self transformationResult:newModel forModelKeyPath:nil];
            if (!PROAssert(success, @"Transformation %@ failed to update %@ with new model object %@", transformation, self, newModel)) {
                // do our best to back out of that failure -- this probably
                // won't be 100%, since model controllers may already have
                // updated references
                [self setModel:oldModel replacingModelControllers:NO];
            }
        }
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
