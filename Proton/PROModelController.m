//
//  PROModelController.m
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelController.h"
#import "EXTNil.h"
#import "EXTScope.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROIndexedTransformation.h"
#import "PROKeyValueCodingMacros.h"
#import "PROKeyValueObserver.h"
#import "PROKeyedTransformation.h"
#import "PROLogging.h"
#import "PROModel.h"
#import "PROModelControllerTransformationLog.h"
#import "PROModelControllerTransformationLogEntry.h"
#import "PROMultipleTransformation.h"
#import "PROTransformation.h"
#import "PROUniqueIdentifier.h"
#import "PROUniqueTransformation.h"
#import "SDQueue.h"
#import <objc/runtime.h>

NSString * const PROModelControllerDidPerformTransformationNotification = @"PROModelControllerDidPerformTransformationNotification";
NSString * const PROModelControllerTransformationKey = @"PROModelControllerTransformation";
NSString * const PROModelControllerOldModelKey = @"PROModelControllerOldModel";
NSString * const PROModelControllerNewModelKey = @"PROModelControllerNewModelKey";

/**
 * A key into the thread dictionary, associated with an `NSNumber` indicating
 * whether the current thread is performing a transformation.
 *
 * Used to implement <[PROModelController performingTransformation]>.
 */
static NSString * const PROModelControllerPerformingTransformationKey = @"PROModelControllerPerformingTransformation";

/**
 * A concurrent dispatch queue shared by all <PROModelController> instances.
 *
 * Any reading of a model controller should be dispatched to this queue as
 * a non-barrier block. Any writing to a model controller should be dispatched
 * to this queue as a barrier block.
 */
static SDQueue *PROModelControllerConcurrentQueue = nil;

@interface PROModelController ()
@property (nonatomic, weak, readwrite) id parentModelController;
@property (nonatomic, copy, readwrite) PROUniqueIdentifier *uniqueIdentifier;

/**
 * Automatically implements the appropriate KVC-compliant model controller
 * methods on the receiver for the given model controller key.
 *
 * @param key A key present in <modelControllerClassesByKey>, indicating the
 * name of the model controller array property.
 * @param modelKeyPath The key path, relative to the <model>, where the model
 * objects managed by this array of model controllers are.
 */
+ (void)implementModelControllerMethodsForKey:(NSString *)key modelKeyPath:(NSString *)modelKeyPath;

/**
 * Replaces the model controllers responsible for managing the given key path.
 *
 * @param modelControllerKey The key, relative to the receiver, where the model
 * controllers reside.
 * @param modelKeyPath The key path, relative to the <model>, where the objects
 * that should be managed by the controllers reside.
 *
 * @warning **Important:** This method should only be invoked while on the
 * `PROModelControllerConcurrentQueue`.
 */
- (void)replaceModelControllersAtKey:(NSString *)modelControllerKey forModelKeyPath:(NSString *)modelKeyPath;

/**
 * Reverts every model controller owned by the receiver to the log entry
 * associated with it in `logEntry`.
 *
 * This will also restore each model controller's <uniqueIdentifier> from the
 * log entry.
 *
 * @warning **Important:** This method should only be invoked while on the
 * `PROModelControllerConcurrentQueue`.
 */
- (void)restoreModelControllersWithTransformationLogEntry:(PROModelControllerTransformationLogEntry *)logEntry;

/**
 * Contains <PROKeyValueObserver> objects observing each model controller
 * managed by the receiver.
 *
 * Notifications from these observers will be posted synchronously.
 *
 * This is a `CFDictionary` because the keys -- which are model controllers --
 * should not be copied, which `NSDictionary` would do.
 *
 * @warning **Important:** This dictionary should only be mutated while on the
 * `PROModelControllerConcurrentQueue`.
 */
@property (nonatomic, readonly) CFMutableDictionaryRef modelControllerObservers;

/**
 * Whether <performTransformation:error:> is currently being executed on the
 * `PROModelControllerConcurrentQueue`.
 */
@property (assign, getter = isPerformingTransformationOnDispatchQueue) BOOL performingTransformationOnDispatchQueue;

/**
 * Whether the receiver's <transformationLog> is currently being moved while
 * running on the `PROModelControllerConcurrentQueue`.
 */
@property (assign, getter = isUnwindingTransformationLogOnDispatchQueue) BOOL unwindingTransformationLogOnDispatchQueue;

/**
 * A transformation log representing updates to the receiver's <model> over
 * time.
 *
 * @warning **Important:** This log should only be mutated while on the
 * `PROModelControllerConcurrentQueue`.
 */
@property (nonatomic, strong, readonly) PROModelControllerTransformationLog *transformationLog;

/**
 * Enumerates all model controllers on the receiver, passing each array of model
 * controllers into the given block.
 *
 * @param shouldBeMutable Whether the arrays provided to the block should be
 * mutable (thus allowing addition, removal, reordering, etc. of managed model
 * controllers).
 * @param block The block to invoke with each array of model controllers. This
 * block will be passed the array of model controllers (mutable if
 * `shouldBeMutable` is `YES`), the key path in the model that the model
 * controllers are responsible for, and the key at which the model controllers
 * exist on the receiver.
 *
 * @warning **Important:** This method should only be invoked while on the
 * `PROModelControllerConcurrentQueue`.
 */
- (void)enumerateModelControllersWithMutableArrays:(BOOL)shouldBeMutable usingBlock:(void (^)(id modelControllers, NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop))block;

/**
 * Replaces the <model>, optionally updating other model controllers on the
 * receiver to match.
 *
 * @param model The new model object to set on the receiver.
 * @param replacing If `YES`, all existing model controllers will be destroyed
 * and recreated from the models in `model`. If `NO`, model controllers are
 * assumed to be updated elsewhere, and will not be modified.
 *
 * @warning **Important:** This method does not automatically generate KVO
 * notifications. This method should only be invoked while on the
 * `PROModelControllerConcurrentQueue`.
 */
- (void)setModel:(PROModel *)model replacingModelControllers:(BOOL)replacing;

/**
 * Attempts to perform the given transformation, optionally appending it to the
 * receiver's <transformationLog> upon success.
 *
 * @param transformation The transformation to attempt to perform.
 * @param shouldAppendTransformation Whether the transformation should be
 * appended to the transformation log upon success.
 * @param error If not `NULL`, this is set to any error that occurs. This
 * argument will only be set if the method returns `NO`.
 *
 * @warning **Important:** This method should only be invoked while on the
 * `PROModelControllerConcurrentQueue`.
 */
- (BOOL)performTransformation:(PROTransformation *)transformation appendToTransformationLog:(BOOL)shouldAppendTransformation error:(NSError **)error;

/**
 * Captures information about the receiver for the latest entry in the
 * receiver's <transformationLog>.
 *
 * @warning **Important:** This method should only be invoked while on the
 * `PROModelControllerConcurrentQueue`.
 */
- (void)captureInLatestLogEntry;

/**
 * The set of blocks that the receiver will pass to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]>.
 */
- (NSDictionary *)transformationBlocks;
@end

@implementation PROModelController

#pragma mark Class initialization

+ (void)initialize {
    // this method gets called once per class, so only create the dispatch queue
    // once
    if (self == [PROModelController class]) {
        PROModelControllerConcurrentQueue = [[SDQueue alloc] initWithPriority:DISPATCH_QUEUE_PRIORITY_DEFAULT concurrent:NO label:@"com.bitswift.Proton.PROModelControllerQueue"];
    }

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

@synthesize model = m_model;
@synthesize modelControllerObservers = m_modelControllerObservers;
@synthesize parentModelController = m_parentModelController;
@synthesize performingTransformationOnDispatchQueue = m_performingTransformationOnDispatchQueue;
@synthesize transformationLog = m_transformationLog;
@synthesize uniqueIdentifier = m_uniqueIdentifier;
@synthesize unwindingTransformationLogOnDispatchQueue = m_unwindingTransformationLogOnDispatchQueue;

- (id)model {
    __block id model;

    [PROModelControllerConcurrentQueue runSynchronously:^{
        model = m_model;
    }];

    return model;
}

- (void)setModel:(id)newModel {
    NSParameterAssert([newModel isKindOfClass:[PROModel class]]);

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        // don't duplicate KVO notifications posted from -performTransformation:
        if (!self.performingTransformationOnDispatchQueue) {
            [self willChangeValueForKey:PROKeyForObject(self, model)];
        }

        @onExit {
            if (!self.performingTransformationOnDispatchQueue) {
                [self didChangeValueForKey:PROKeyForObject(self, model)];
            }
        };

        PROUniqueTransformation *modelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:m_model outputValue:newModel];
        [self.transformationLog appendTransformation:modelTransformation];

        [self setModel:newModel replacingModelControllers:YES];
        [self captureInLatestLogEntry];
    }];
}

- (void)setModel:(PROModel *)newModel replacingModelControllers:(BOOL)replacing; {
    NSParameterAssert([newModel isKindOfClass:[PROModel class]]);

    NSAssert(PROModelControllerConcurrentQueue.currentQueue, @"%s should only be invoked while running on the dispatch queue", __func__);

    m_model = [newModel copy];
    if (replacing) {
        // figure out where the model controllers are, and replace them all
        NSDictionary *modelControllerKeys = [[self class] modelControllerKeysByModelKeyPath];
        if (![modelControllerKeys count])
            return;

        for (NSString *modelKeyPath in modelControllerKeys) {
            NSString *modelControllerKey = [modelControllerKeys objectForKey:modelKeyPath];
            [self replaceModelControllersAtKey:modelControllerKey forModelKeyPath:modelKeyPath];
        }
    }
}

- (BOOL)isPerformingTransformation {
    if (!PROModelControllerConcurrentQueue.currentQueue) {
        // impossible that a transformation could be getting performed on the
        // current thread if we're not on the dispatch queue
        return NO;
    }

    return self.performingTransformationOnDispatchQueue;
}

- (NSUInteger)archivedTransformationLogLimit {
    __block NSUInteger limit;

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        limit = self.transformationLog.maximumNumberOfArchivedLogEntries;
    }];

    return limit;
}

- (void)setArchivedTransformationLogLimit:(NSUInteger)limit {
    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        self.transformationLog.maximumNumberOfArchivedLogEntries = limit;
    }];
}

- (CFMutableDictionaryRef)modelControllerObservers {
    if (!m_modelControllerObservers) {
        m_modelControllerObservers = CFDictionaryCreateMutable(
            NULL,
            0,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks
        );
    }

    return m_modelControllerObservers;
}

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (!self)
        return nil;
    
    // this must be set up before the transformation log is created
    self.uniqueIdentifier = [[PROUniqueIdentifier alloc] init];

    m_transformationLog = [[PROModelControllerTransformationLog alloc] initWithModelController:self];
    m_transformationLog.maximumNumberOfArchivedLogEntries = 50;

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        [self captureInLatestLogEntry];
    }];

    return self;
}

- (id)initWithModel:(PROModel *)model {
    self = [self init];
    if (!self)
        return nil;

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        // don't need to grow the transformation log yet
        [self setModel:model replacingModelControllers:YES];
        [self captureInLatestLogEntry];
    }];

    return self;
}

- (void)dealloc {
    // make sure to tear down model controller observers first thing
    if (m_modelControllerObservers) {
        CFRelease(m_modelControllerObservers);
        m_modelControllerObservers = NULL;
    }
}

#pragma mark Model controllers

+ (void)implementModelControllerMethodsForKey:(NSString *)key modelKeyPath:(NSString *)modelKeyPath; {
    NSAssert([key length] > 0, @"Should be at least one character in model controller key");
    NSAssert([modelKeyPath length] > 0, @"Should be at least one character in model key path");

    NSAssert([[self modelControllerClassesByKey] objectForKey:key], @"Model controller class should not be nil for key \"%@\"", key);

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

        PROAssert(class_addMethod(self, selector, methodIMP, [typeEncoding UTF8String]), @"Could not add method %s to %@ -- perhaps it already exists?", selector, self);
    };

    /*
     * Returns the mutable array for model controllers of this class, creating
     * it first if necessary.
     *
     * Use of this block should be synchronized with the
     * `PROModelControllerConcurrentQueue`.
     *
     * @warning **Important:** This is not actually a public method -- just an
     * internal helper block.
     */
    NSMutableArray *(^modelControllersArray)(PROModelController *) = ^(PROModelController *self){
        NSAssert(PROModelControllerConcurrentQueue.currentQueue, @"Model controllers are only safe to retrieve while on the dispatch queue");

        NSMutableArray *array = objc_getAssociatedObject(self, getterSelector);
        if (!array) {
            array = [NSMutableArray array];

            objc_setAssociatedObject(self, getterSelector, array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        return array;
    };

    /*
     * Public getter for the model controllers.
     */
    id getter = ^(PROModelController *self){
        __block NSArray *controllers;

        [PROModelControllerConcurrentQueue runSynchronously:^{
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
                [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
                    if (weakSelf.unwindingTransformationLogOnDispatchQueue) {
                        // ignore model changes while unwinding the
                        // transformation log
                        return;
                    }

                    NSArray *models = [weakSelf.model valueForKeyPath:modelKeyPath];
                    NSUInteger index = [models indexOfObjectIdenticalTo:oldSubModel];

                    if (!PROAssert(index != NSNotFound, @"Could not find model object %@ to replace in array: %@", oldSubModel, models)) {
                        return;
                    }

                    PROUniqueTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:oldSubModel outputValue:newSubModel];
                    PROIndexedTransformation *modelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:modelsTransformation forKeyPath:modelKeyPath];

                    PROModel *newModel = [modelTransformation transform:weakSelf.model error:NULL];
                    if (!PROAssert(newModel, @"Could not create new model object from %@ with transformation %@", weakSelf.model, modelTransformation)) {
                        return;
                    }

                    [weakSelf willChangeValueForKey:PROKeyForObject(self, model)];
                    @onExit {
                        [weakSelf didChangeValueForKey:PROKeyForObject(self, model)];
                    };

                    // the model controllers are already up-to-date; we just
                    // want to drop in the new model object and record the
                    // transformation in the log
                    [weakSelf.transformationLog appendTransformation:modelTransformation];
                    [weakSelf setModel:newModel replacingModelControllers:NO];
                    [weakSelf captureInLatestLogEntry];
                }];
            }
        ];

        // post synchronously
        observer.queue = nil;

        [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
            [modelControllersArray(self) insertObject:controller atIndex:index];
            controller.parentModelController = self;

            CFDictionarySetValue(self.modelControllerObservers, (__bridge void *)controller, (__bridge void *)observer);
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
        [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
            NSMutableArray *controllers = modelControllersArray(self);
            PROModelController *controller = [controllers objectAtIndex:index];

            // tear down the observer first
            CFDictionaryRemoveValue(self.modelControllerObservers, (__bridge void *)controller);

            [controllers removeObjectAtIndex:index];
            controller.parentModelController = nil;
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

- (void)enumerateModelControllersWithMutableArrays:(BOOL)shouldBeMutable usingBlock:(void (^)(id modelControllers, NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop))block; {
    NSAssert(PROModelControllerConcurrentQueue.currentQueue, @"%s should only be invoked while running on the dispatch queue", __func__);

    NSDictionary *modelControllerKeys = [[self class] modelControllerKeysByModelKeyPath];

    [modelControllerKeys enumerateKeysAndObjectsUsingBlock:^(NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
        id modelControllers;

        if (shouldBeMutable)
            modelControllers = [self mutableArrayValueForKey:modelControllerKey];
        else
            modelControllers = [self valueForKey:modelControllerKey];

        block(modelControllers, modelKeyPath, modelControllerKey, stop);
    }];
}

- (void)replaceModelControllersAtKey:(NSString *)modelControllerKey forModelKeyPath:(NSString *)modelKeyPath; {
    NSDictionary *modelControllerClasses = [[self class] modelControllerClassesByKey];
    Class modelControllerClass = [modelControllerClasses objectForKey:modelControllerKey];

    NSArray *models = [m_model valueForKeyPath:modelKeyPath];

    NSAssert(!models || [models isKindOfClass:[NSArray class]], @"Model key path \"%@\", bound to model controller key \"%@\", should be associated with an array: %@", modelKeyPath, modelControllerKey, models);

    NSArray *newModelControllers = [models mapUsingBlock:^(PROModel *model){
        return [[modelControllerClass alloc] initWithModel:model];
    }];

    NSMutableArray *modelControllers = [self mutableArrayValueForKey:modelControllerKey];
    [modelControllers setArray:newModelControllers];
}

#pragma mark Model Controller Identifiers

- (id)modelControllerWithIdentifier:(PROUniqueIdentifier *)identifier; {
    NSParameterAssert(identifier != nil);
    
    __block PROModelController *matchingController = nil;

    [PROModelControllerConcurrentQueue runSynchronously:^{
        // TODO: this could be optimized
        [self enumerateModelControllersWithMutableArrays:NO usingBlock:^(NSArray *controllers, NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
            matchingController = [controllers objectPassingTest:^(PROModelController *controller, NSUInteger index, BOOL *stop){
                return [controller.uniqueIdentifier isEqual:identifier];
            }];

            if (matchingController)
                *stop = YES;
        }];
    }];

    return matchingController;
}

#pragma mark Performing Transformations

- (BOOL)performTransformation:(PROTransformation *)transformation error:(NSError **)error; {
    __block BOOL success = NO;

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        success = [self performTransformation:transformation appendToTransformationLog:YES error:error];
    }];

    return success;
}

- (BOOL)performTransformation:(PROTransformation *)transformation appendToTransformationLog:(BOOL)shouldAppendTransformation error:(NSError **)error; {
    NSAssert(!self.performingTransformation, @"%s should not be invoked recursively", __func__);
    NSAssert(PROModelControllerConcurrentQueue.currentQueue, @"%s should only be invoked while running on the dispatch queue", __func__);

    self.performingTransformationOnDispatchQueue = YES;

    @onExit {
        self.performingTransformationOnDispatchQueue = NO;
    };

    id oldModel = self.model;
    if (!oldModel) {
        // never pass 'nil' into a transformation
        oldModel = [EXTNil null];
    }

    PROModel *newModel = [transformation transform:oldModel error:error];
    if (!newModel) {
        // fail immediately, before any side effects
        return NO;
    }

    [self willChangeValueForKey:PROKeyForObject(self, model)];

    @onExit {
        [self didChangeValueForKey:PROKeyForObject(self, model)];
    };

    PROModelControllerTransformationLogEntry *lastLogEntry = self.transformationLog.latestLogEntry;
    PROModelControllerTransformationLogEntry *newLogEntry = nil;

    if (shouldAppendTransformation) {
        [self.transformationLog appendTransformation:transformation];

        newLogEntry = self.transformationLog.latestLogEntry;
    }

    [self setModel:newModel replacingModelControllers:NO];
    [transformation applyBlocks:self.transformationBlocks transformationResult:newModel keyPath:nil];

    // only capture 'self' in the log entry if it hasn't changed in the
    // interim
    if (shouldAppendTransformation && NSEqualObjects(self.transformationLog.latestLogEntry, newLogEntry)) {
        [self captureInLatestLogEntry];
    }

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        transformation, PROModelControllerTransformationKey,
        oldModel, PROModelControllerOldModelKey,
        newModel, PROModelControllerNewModelKey,
        nil
    ];

    [[NSNotificationCenter defaultCenter] postNotificationName:PROModelControllerDidPerformTransformationNotification object:self userInfo:userInfo];
    return YES;
}

- (NSDictionary *)transformationBlocks; {
    PROTransformationNewValueForKeyPathBlock transformationNewValueForKeyPathBlock = ^(id value, NSString *keyPath){
        if (!keyPath) {
            // this was a change or replacement of a top-level model property
            self.model = value;
            return YES;
        }

        NSString *controllersKey = [[[self class] modelControllerKeysByModelKeyPath] objectForKey:keyPath];
        if (!controllersKey) {
            // this was a change to some nested property we don't care about
            return NO;
        }

        // this was a replacement of a model array
        Class controllerClass = [[[self class] modelControllerClassesByKey] objectForKey:controllersKey];

        NSArray *newControllers = [value mapUsingBlock:^(PROModel *model){
            return [[controllerClass alloc] initWithModel:model];
        }];

        NSMutableArray *mutableControllers = [self mutableArrayValueForKey:controllersKey];

        // replace the controllers outright, since we replaced the associated models
        // outright
        [mutableControllers setArray:newControllers];
        return YES;
    };

    PROTransformationMutableArrayForKeyPathBlock transformationMutableArrayForKeyPathBlock = ^ id (NSString *keyPath){
        NSString *controllersKey = [[[self class] modelControllerKeysByModelKeyPath] objectForKey:keyPath];
        if (!controllersKey)
            return nil;

        return [self mutableArrayValueForKey:controllersKey];
    };

    PROTransformationWrappedValueForKeyPathBlock transformationWrappedValueForKeyPathBlock = ^ id (id value, NSString *keyPath){
        NSString *controllersKey = [[[self class] modelControllerKeysByModelKeyPath] objectForKey:keyPath];
        if (!controllersKey)
            return nil;

        Class controllerClass = [[[self class] modelControllerClassesByKey] objectForKey:controllersKey];
        return [[controllerClass alloc] initWithModel:value];
    };

    PROTransformationBlocksForIndexAtKeyPathBlock transformationBlocksForIndexAtKeyPathBlock = ^(NSUInteger index, NSString *keyPath, NSDictionary *blocks){
        NSString *controllersKey = [[[self class] modelControllerKeysByModelKeyPath] objectForKey:keyPath];
        if (!controllersKey)
            return blocks;

        NSArray *controllers = [self valueForKey:controllersKey];
        return [[controllers objectAtIndex:index] transformationBlocks];
    };

    return [NSDictionary dictionaryWithObjectsAndKeys:
        [transformationNewValueForKeyPathBlock copy], PROTransformationNewValueForKeyPathBlockKey,
        [transformationMutableArrayForKeyPathBlock copy], PROTransformationMutableArrayForKeyPathBlockKey,
        [transformationWrappedValueForKeyPathBlock copy], PROTransformationWrappedValueForKeyPathBlockKey,
        [transformationBlocksForIndexAtKeyPathBlock copy], PROTransformationBlocksForIndexAtKeyPathBlockKey,
        nil
    ];
}

#pragma mark Transformation Log

- (PROModelControllerTransformationLogEntry *)transformationLogEntryWithModelPointer:(PROModel **)modelPointer; {
    __block PROModel *strongModel = nil;
    __block PROModelControllerTransformationLogEntry *logEntry = nil;

    [PROModelControllerConcurrentQueue runSynchronously:^{
        if (modelPointer) {
            // necessary to make sure this object escapes any autorelease pool
            strongModel = self.model;
        }

        logEntry = [self.transformationLog.latestLogEntry copy];
    }];

    if (modelPointer)
        *modelPointer = strongModel;

    return logEntry;
}

- (id)modelWithTransformationLogEntry:(PROModelControllerTransformationLogEntry *)transformationLogEntry; {
    NSParameterAssert(transformationLogEntry != nil);

    __block PROModel *currentModel = nil;
    __block PROTransformation *transformationFromOldModel = nil;

    [PROModelControllerConcurrentQueue runSynchronously:^{
        transformationFromOldModel = [self.transformationLog multipleTransformationFromLogEntry:transformationLogEntry toLogEntry:self.transformationLog.latestLogEntry];
        if (transformationFromOldModel)
            currentModel = self.model;
    }];

    if (!transformationFromOldModel)
        return nil;

    PROTransformation *transformationToOldModel = transformationFromOldModel.reverseTransformation;
    PROModel *oldModel = [transformationToOldModel transform:currentModel error:NULL];
    NSAssert(oldModel != nil, @"Transformation from current model %@ to previous model should never fail: %@", currentModel, transformationToOldModel);

    return oldModel;
}

- (NSArray *)modelControllerModelsWithTransformationLogEntries:(NSArray *)logEntries; {
    NSMutableArray *models = [[NSMutableArray alloc] initWithCapacity:logEntries.count];

    for (PROModelControllerTransformationLogEntry *logEntry in logEntries) {
        if (!logEntry.modelControllerIdentifier)
            return nil;

        PROModelController *subController = [self modelControllerWithIdentifier:logEntry.modelControllerIdentifier];
        PROModel *model = [subController modelWithTransformationLogEntry:logEntry];

        if (!model)
            return nil;

        [models addObject:model];
    }

    return models;
}

- (BOOL)restoreModelFromTransformationLogEntry:(PROModelControllerTransformationLogEntry *)transformationLogEntry; {
    NSParameterAssert(transformationLogEntry != nil);

    __block BOOL success = NO;

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        PROTransformation *transformationFromLogEntryModel = [self.transformationLog multipleTransformationFromLogEntry:transformationLogEntry toLogEntry:self.transformationLog.latestLogEntry];
        if (!transformationFromLogEntryModel)
            return;

        PROTransformation *transformationToLogEntryModel = transformationFromLogEntryModel.reverseTransformation;

        PROModel *oldModel = self.model;
        PROModel *newModel = [transformationToLogEntryModel transform:oldModel error:NULL];
        if (!PROAssert(newModel, @"Transformation from current model %@ to previous model should never fail: %@", self.model, transformationToLogEntryModel))
            return;

        [self willChangeValueForKey:PROKeyForObject(self, model)];
        @onExit {
            [self didChangeValueForKey:PROKeyForObject(self, model)];
        };

        if (![self.transformationLog moveToLogEntry:transformationLogEntry])
            return;

        [self setModel:newModel replacingModelControllers:NO];
        [self restoreModelControllersWithTransformationLogEntry:transformationLogEntry];

        success = YES;

        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            transformationToLogEntryModel, PROModelControllerTransformationKey,
            oldModel, PROModelControllerOldModelKey,
            newModel, PROModelControllerNewModelKey,
            nil
        ];

        [[NSNotificationCenter defaultCenter] postNotificationName:PROModelControllerDidPerformTransformationNotification object:self userInfo:userInfo];
    }];

    return success;
}

- (void)restoreModelControllersWithTransformationLogEntry:(PROModelControllerTransformationLogEntry *)logEntry; {
    NSAssert(PROModelControllerConcurrentQueue.currentQueue, @"%s should only be invoked while running on the dispatch queue", __func__);

    self.unwindingTransformationLogOnDispatchQueue = YES;
    @onExit {
        self.unwindingTransformationLogOnDispatchQueue = NO;
    };

    NSDictionary *savedControllers = [self.transformationLog.modelControllersByLogEntry objectForKey:logEntry];
    NSDictionary *savedLogEntries = [self.transformationLog.modelControllerLogEntriesByLogEntry objectForKey:logEntry];

    if (!PROAssert([savedLogEntries count] == [savedControllers count], @"Log entries %@ do not match controllers %@", savedLogEntries, savedControllers)) {
        return;
    }

    [self enumerateModelControllersWithMutableArrays:YES usingBlock:^(NSMutableArray *controllers, NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
        NSArray *existingModels = [self.model valueForKey:modelKeyPath];

        NSArray *replacementControllers = [savedControllers objectForKey:modelControllerKey];
        NSArray *logEntriesForControllers = [savedLogEntries objectForKey:modelControllerKey];

        if (!PROAssert(replacementControllers.count == logEntriesForControllers.count, @"Log entries %@ do not match controllers: %@", logEntriesForControllers, replacementControllers))
            return;

        if (!replacementControllers.count) {
            // didn't save anything because there were no model controllers
            replacementControllers = [NSArray array];
        }

        NSMutableArray *replacementModels = [[NSMutableArray alloc] initWithCapacity:replacementControllers.count];

        [replacementControllers enumerateObjectsUsingBlock:^(PROModelController *controller, NSUInteger index, BOOL *stop){
            PROModelControllerTransformationLogEntry *logEntry = [logEntriesForControllers objectAtIndex:index];
            PROAssert([controller restoreModelFromTransformationLogEntry:logEntry], @"Could not restore log entry %@ for controller %@", logEntry, controller);

            // this MUST be done only after restoring this controller's model!
            [replacementModels addObject:controller.model];
        }];

        [controllers setArray:replacementControllers];

        PROUniqueTransformation *modelsTransformation = [[PROUniqueTransformation alloc] initWithInputValue:existingModels outputValue:replacementModels];
        PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:modelsTransformation forKeyPath:modelKeyPath];

        PROModel *newModel = [modelTransformation transform:self.model error:NULL];
        if (!PROAssert(newModel, @"Replacement of models at key path \"%@\" in %@ to previous models should never fail: %@", modelKeyPath, self.model, modelTransformation))
            return;

        [self setModel:newModel replacingModelControllers:NO];
    }];
}

- (void)captureInLatestLogEntry; {
    NSAssert(PROModelControllerConcurrentQueue.currentQueue, @"%s should only be invoked while running on the dispatch queue", __func__);

    PROModelControllerTransformationLogEntry *logEntry = self.transformationLog.latestLogEntry;

    NSArray *modelControllerKeys = [[[self class] modelControllerKeysByModelKeyPath] allValues];

    NSUInteger modelControllerKeyCount = modelControllerKeys.count;
    if (!modelControllerKeyCount) {
        [self.transformationLog.modelControllersByLogEntry removeObjectForKey:logEntry];
        [self.transformationLog.modelControllerLogEntriesByLogEntry removeObjectForKey:logEntry];
        return;
    }

    NSMutableArray *savedModelControllersArrays = [NSMutableArray arrayWithCapacity:modelControllerKeyCount];
    NSMutableArray *savedModelControllerLogEntriesArrays = [NSMutableArray arrayWithCapacity:modelControllerKeyCount];

    [modelControllerKeys enumerateObjectsUsingBlock:^(NSString *modelControllerKey, NSUInteger index, BOOL *stop){
        NSArray *modelControllers = [self valueForKey:modelControllerKey];
        [savedModelControllersArrays addObject:modelControllers];

        NSArray *savedLogEntries = [modelControllers mapUsingBlock:^ id (PROModelController *controller){
            PROModelControllerTransformationLogEntry *controllerEntry = [controller transformationLogEntryWithModelPointer:NULL];

            if (PROAssert(controllerEntry, @"Could not retrieve log entry from controller %@", controller)) {
                return controllerEntry;
            } else {
                return [EXTNil null];
            }
        }];

        [savedModelControllerLogEntriesArrays addObject:savedLogEntries];
    }];

    NSAssert([savedModelControllerLogEntriesArrays count] == [savedModelControllersArrays count], @"Log entries %@ do not match controllers %@", savedModelControllerLogEntriesArrays, savedModelControllersArrays);

    NSDictionary *savedModelControllers = [NSDictionary dictionaryWithObjects:savedModelControllersArrays forKeys:modelControllerKeys];
    [self.transformationLog.modelControllersByLogEntry setObject:savedModelControllers forKey:logEntry];

    NSDictionary *savedModelControllerLogEntries = [NSDictionary dictionaryWithObjects:savedModelControllerLogEntriesArrays forKeys:modelControllerKeys];
    [self.transformationLog.modelControllerLogEntriesByLogEntry setObject:savedModelControllerLogEntries forKey:logEntry];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROUniqueIdentifier *decodedIdentifier = [coder decodeObjectForKey:PROKeyForObject(self, uniqueIdentifier)];
    if (!decodedIdentifier)
        return nil;

    PROModel *model = [coder decodeObjectForKey:PROKeyForObject(self, model)];
    if (!model)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    // replace the UUID created in -init
    self.uniqueIdentifier = [decodedIdentifier copy];

    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        self.parentModelController = [coder decodeObjectForKey:PROKeyForObject(self, parentModelController)];

        // we need to set up the model controllers manually anyways
        [self setModel:model replacingModelControllers:NO];

        [self enumerateModelControllersWithMutableArrays:YES usingBlock:^(NSMutableArray *modelControllers, NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
            NSArray *decodedModelControllers = [coder decodeObjectForKey:modelControllerKey];

            if (!PROAssert(decodedModelControllers, @"Could not decode model controllers at key \"%@\", reconstructing them manually", modelControllerKey)) {
                [self replaceModelControllersAtKey:modelControllerKey forModelKeyPath:modelKeyPath];
                return;
            }

            [modelControllers setArray:decodedModelControllers];
        }];
    }];

    id decodedLog = [coder decodeObjectForKey:PROKeyForObject(self, transformationLog)];
    if (decodedLog) {
        // replace the default transformation log created in -init
        m_transformationLog = decodedLog;

        NSAssert(NSEqualObjects(self.transformationLog.modelController, self), @"Transformation log %@ is not actually owned by %@", self.transformationLog, self);
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [PROModelControllerConcurrentQueue runBarrierSynchronously:^{
        [coder encodeObject:self.uniqueIdentifier forKey:PROKeyForObject(self, uniqueIdentifier)];

        id model = self.model;
        if (!model)
            model = [EXTNil null];

        [coder encodeObject:model forKey:PROKeyForObject(self, model)];

        [self enumerateModelControllersWithMutableArrays:NO usingBlock:^(NSArray *modelControllers, NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
            [coder encodeObject:modelControllers forKey:modelControllerKey];
        }];

        if (self.transformationLog)
            [coder encodeObject:self.transformationLog forKey:PROKeyForObject(self, transformationLog)];

        if (self.parentModelController)
            [coder encodeConditionalObject:self.parentModelController forKey:PROKeyForObject(self, parentModelController)];
    }];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    NSString *modelKey = PROKeyForClass(PROModelController, model);

    if ([key isEqualToString:modelKey]) {
        // don't auto-generate KVO notifications when changing 'model' -- we'll
        // do it ourselves
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:key];
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p ID: %@>", [self class], (__bridge void *)self, self.uniqueIdentifier];
}

- (NSUInteger)hash {
    return [self.uniqueIdentifier hash];
}

- (BOOL)isEqual:(PROModelController *)controller {
    // be very strict about controller classes, since different classes should
    // be considered conceptually different
    if (![controller isMemberOfClass:[self class]]) {
        return NO;
    }

    if (![self.uniqueIdentifier isEqual:controller.uniqueIdentifier]) {
        return NO;
    }

    if (self.parentModelController != controller.parentModelController) {
        return NO;
    }

    if (!NSEqualObjects(self.model, controller.model)) {
        return NO;
    }

    return YES;
}

@end
