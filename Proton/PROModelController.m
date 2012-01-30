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
#import "PROModelControllerPrivate.h"
#import "PROMultipleTransformation.h"
#import "PROTransformation.h"
#import "PROTransformationLog.h"
#import "PROUniqueIdentifier.h"
#import "PROUniqueTransformation.h"
#import "SDQueue.h"
#import <objc/runtime.h>

/**
 * A key into the thread dictionary, associated with an `NSNumber` indicating
 * whether the current thread is performing a transformation.
 *
 * Used to implement <[PROModelController performingTransformation]>.
 */
static NSString * const PROModelControllerPerformingTransformationKey = @"PROModelControllerPerformingTransformation";

@interface PROModelController ()
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
 */
- (void)replaceModelControllersAtKey:(NSString *)modelControllerKey forModelKeyPath:(NSString *)modelKeyPath;

/**
 * Contains <PROKeyValueObserver> objects observing each model controller
 * managed by the receiver (in no particular order).
 *
 * Notifications from these observers will be posted synchronously.
 *
 * @warning **Important:** Mutation of this array must be synchronized using the
 * receiver's <dispatchQueue>.
 */
@property (nonatomic, strong) NSMutableArray *modelControllerObservers;

/**
 * Whether <performTransformation:error:> is currently being executed on the
 * <dispatchQueue>.
 *
 * @warning **Important:** This should only be read or written while already
 * running on <dispatchQueue>. Use <performingTransformation> in all other
 * cases.
 */
@property (nonatomic, assign, getter = isPerformingTransformationOnDispatchQueue) BOOL performingTransformationOnDispatchQueue;

/**
 * A transformation log representing updates to the receiver's <model> over
 * time.
 *
 * @warning **Important:** Mutation of this log must be synchronized using the
 * receiver's <dispatchQueue>.
 */
@property (nonatomic, strong, readonly) PROTransformationLog *transformationLog;

/**
 * A dictionary containing any blocks passed to
 * <transformationLogEntryWithModelPointer:willRemoveLogEntryBlock:>, keyed by
 * the log entry that they should be notified of.
 *
 * @warning **Important:** Mutation of this dictionary must be synchronized
 * using the receiver's <dispatchQueue>.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *willRemoveLogEntryBlocksByLogEntry;

/**
 * Invoked from the <[PROTransformationLog willRemoveLogEntryBlock]> of the
 * receiver's <transformationLog>.
 *
 * @param logEntry The log entry being removed.
 */
- (void)transformationLogWillRemoveLogEntry:(id)logEntry;
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
@synthesize transformationLog = m_transformationLog;
@synthesize uniqueIdentifier = m_uniqueIdentifier;
@synthesize willRemoveLogEntryBlocksByLogEntry = m_willRemoveLogEntryBlocksByLogEntry;

- (id)model {
    __block id model;

    [self.dispatchQueue runSynchronously:^{
        model = m_model;
    }];

    return model;
}

/*
 * This method should only be called externally, since it invokes
 * <performTransformation:> (which, called internally, could result in infinite
 * recursion).
 */
- (void)setModel:(id)newModel {
    NSParameterAssert([newModel isEqual:[EXTNil null]] || [newModel isKindOfClass:[PROModel class]]);

    [self.dispatchQueue runSynchronously:^{
        id currentModel = self.model;
        if (!currentModel) {
            // never pass 'nil' into a transformation
            currentModel = [EXTNil null];
        }

        if ([currentModel isEqual:newModel])
            return;

        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:currentModel outputValue:newModel];

        BOOL success = [self performTransformation:transformation error:NULL];
        PROAssert(success, @"Transformation %@ should never fail", transformation);
    }];
}

- (void)setModel:(PROModel *)newModel replacingModelControllers:(BOOL)replacing; {
    NSParameterAssert([newModel isKindOfClass:[PROModel class]]);

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

            for (NSString *modelKeyPath in modelControllerKeys) {
                NSString *modelControllerKey = [modelControllerKeys objectForKey:modelKeyPath];
                [self replaceModelControllersAtKey:modelControllerKey forModelKeyPath:modelKeyPath];
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

- (NSUInteger)transformationLogLimit {
    __block NSUInteger limit;

    [self.dispatchQueue runSynchronously:^{
        limit = self.transformationLog.maximumNumberOfLogEntries;
    }];

    return limit;
}

- (void)setTransformationLogLimit:(NSUInteger)limit {
    [self.dispatchQueue runSynchronously:^{
        self.transformationLog.maximumNumberOfLogEntries = limit;
    }];
}

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_dispatchQueue = [[SDQueue alloc] init];
    m_transformationLog = [[PROTransformationLog alloc] init];
    m_uniqueIdentifier = [[PROUniqueIdentifier alloc] init];
    m_willRemoveLogEntryBlocksByLogEntry = [[NSMutableDictionary alloc] init];

    __weak PROModelController *weakSelf = self;

    m_transformationLog.willRemoveLogEntryBlock = ^(id logEntry){
        [weakSelf transformationLogWillRemoveLogEntry:logEntry];
    };

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

- (id)modelControllerWithIdentifier:(PROUniqueIdentifier *)identifier; {
    NSParameterAssert(identifier != nil);

    NSDictionary *modelControllerKeysByModelKeyPath = [[self class] modelControllerKeysByModelKeyPath];
    
    __block PROModelController *matchingController = nil;

    [self.dispatchQueue runSynchronously:^{
        // TODO: this could be optimized
        [modelControllerKeysByModelKeyPath enumerateKeysAndObjectsUsingBlock:^(NSString *modelKeyPath, NSString *controllerKey, BOOL *stop){
            NSArray *controllers = [self valueForKey:controllerKey];

            matchingController = [controllers objectWithOptions:NSEnumerationConcurrent passingTest:^(PROModelController *controller, NSUInteger index, BOOL *stop){
                return [controller.uniqueIdentifier isEqual:identifier];
            }];

            if (matchingController)
                *stop = YES;
        }];
    }];

    return matchingController;
}

- (void)replaceModelControllersAtKey:(NSString *)modelControllerKey forModelKeyPath:(NSString *)modelKeyPath; {
    NSDictionary *modelControllerClasses = [[self class] modelControllerClassesByKey];
    Class modelControllerClass = [modelControllerClasses objectForKey:modelControllerKey];

    NSArray *models = [m_model valueForKeyPath:modelKeyPath];

    NSAssert(!models || [models isKindOfClass:[NSArray class]], @"Model key path \"%@\", bound to model controller key \"%@\", should be associated with an array: %@", modelKeyPath, modelControllerKey, models);

    NSArray *newModelControllers = [models mapWithOptions:NSEnumerationConcurrent usingBlock:^(PROModel *model){
        return [[modelControllerClass alloc] initWithModel:model];
    }];

    NSMutableArray *modelControllers = [self mutableArrayValueForKey:modelControllerKey];
    [modelControllers setArray:newModelControllers];
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

        id oldModel = self.model;
        if (!oldModel) {
            // never pass 'nil' into a transformation
            oldModel = [EXTNil null];
        }

        PROModel *newModel = [transformation transform:oldModel error:error];

        if (!newModel) {
            // fail immediately, before any side effects
            success = NO;
            return;
        }

        // update the transformation log before setting the new model
        [self.transformationLog addLogEntryWithTransformation:transformation];

        // the below call to -updateModelController:… should replace our model
        // controllers if necessary
        [self setModel:newModel replacingModelControllers:NO];

        success = [transformation updateModelController:self transformationResult:newModel forModelKeyPath:nil];
        if (!PROAssert(success, @"Transformation %@ failed to update %@ with new model object %@", transformation, self, newModel)) {
            // do our best to back out of that failure -- this probably
            // won't be 100%, since model controllers may already have
            // updated references, and we've already recorded the failing
            // transformation in the log
            [self.transformationLog addLogEntryWithTransformation:transformation.reverseTransformation];
            [self setModel:oldModel replacingModelControllers:NO];
        }
    }];

    return success;
}

- (id<NSCoding, NSCopying>)transformationLogEntryWithModelPointer:(PROModel **)modelPointer; {
    return [self transformationLogEntryWithModelPointer:modelPointer willRemoveLogEntryBlock:nil];
}

- (id<NSCoding, NSCopying>)transformationLogEntryWithModelPointer:(PROModel **)modelPointer willRemoveLogEntryBlock:(void (^)(void))block; {
    __block PROModel *strongModel = nil;
    __block id<NSCoding, NSCopying> logEntry = nil;

    [self.dispatchQueue runSynchronously:^{
        if (modelPointer) {
            // necessary to make sure this object escapes any autorelease pool
            strongModel = self.model;
        }

        logEntry = [self.transformationLog.nextLogEntry copy];

        if (block) {
            void (^existingBlock)(void) = [self.willRemoveLogEntryBlocksByLogEntry objectForKey:logEntry];
            void (^newBlock)(void);

            if (existingBlock) {
                // compose the two blocks
                newBlock = [^{
                    existingBlock();
                    block();
                } copy];
            } else {
                newBlock = block;
            }

            [self.willRemoveLogEntryBlocksByLogEntry setObject:newBlock forKey:logEntry];
        }
    }];

    if (modelPointer)
        *modelPointer = strongModel;

    return logEntry;
}

- (id)modelWithTransformationLogEntry:(id)transformationLogEntry; {
    NSParameterAssert(transformationLogEntry != nil);

    __block PROModel *currentModel = nil;
    __block PROTransformation *transformationFromOldModel = nil;

    [self.dispatchQueue runSynchronously:^{
        transformationFromOldModel = [self.transformationLog multipleTransformationStartingFromLogEntry:transformationLogEntry];
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

- (void)transformationLogWillRemoveLogEntry:(id)logEntry; {
    // we should already be on the dispatch queue, but just in case...
    [self.dispatchQueue runSynchronously:^{
        void (^willRemoveBlock)(void) = [self.willRemoveLogEntryBlocksByLogEntry objectForKey:logEntry];

        if (!willRemoveBlock)
            return;

        // won't need this block anymore
        [self.willRemoveLogEntryBlocksByLogEntry removeObjectForKey:logEntry];

        willRemoveBlock();
    }];
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
    m_uniqueIdentifier = [decodedIdentifier copy];

    // we need to set up the model controllers manually anyways
    [self setModel:model replacingModelControllers:NO];

    NSDictionary *modelControllerKeys = [[self class] modelControllerKeysByModelKeyPath];

    for (NSString *modelKeyPath in modelControllerKeys) {
        NSString *modelControllerKey = [modelControllerKeys objectForKey:modelKeyPath];
        NSArray *decodedModelControllers = [coder decodeObjectForKey:modelControllerKey];

        if (!decodedModelControllers) {
            DDLogError(@"Could not decode model controllers at key \"%@\", reconstructing them manually", modelControllerKey);
            [self replaceModelControllersAtKey:modelControllerKey forModelKeyPath:modelKeyPath];
            continue;
        }

        NSMutableArray *modelControllers = [self mutableArrayValueForKey:modelControllerKey];
        [modelControllers setArray:decodedModelControllers];
    }

    PROTransformationLog *decodedLog = [coder decodeObjectForKey:PROKeyForObject(self, transformationLog)];
    if (decodedLog) {
        // replace the default transformation log created in -init
        m_transformationLog = decodedLog;

        __weak PROModelController *weakSelf = self;

        m_transformationLog.willRemoveLogEntryBlock = ^(id logEntry){
            [weakSelf transformationLogWillRemoveLogEntry:logEntry];
        };
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.uniqueIdentifier forKey:PROKeyForObject(self, uniqueIdentifier)];

    id model = self.model;
    if (!model)
        model = [EXTNil null];

    [coder encodeObject:model forKey:PROKeyForObject(self, model)];

    NSDictionary *modelControllerKeys = [[self class] modelControllerKeysByModelKeyPath];

    [modelControllerKeys enumerateKeysAndObjectsUsingBlock:^(NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
        NSArray *modelControllers = [self valueForKey:modelControllerKey];
        if (!modelControllers) {
            return;
        }

        [coder encodeObject:modelControllers forKey:modelControllerKey];
    }];

    if (self.transformationLog)
        [coder encodeObject:self.transformationLog forKey:PROKeyForObject(self, transformationLog)];
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

    if (!NSEqualObjects(self.model, controller.model)) {
        return NO;
    }

    __block BOOL equal = YES;

    // recursively compare model controllers
    [[[self class] modelControllerKeysByModelKeyPath] enumerateKeysAndObjectsUsingBlock:^(NSString *modelKeyPath, NSString *modelControllerKey, BOOL *stop){
        if (!NSEqualObjects([self valueForKey:modelControllerKey], [controller valueForKey:modelControllerKey])) {
            equal = NO;
            *stop = YES;
        }
    }];

    return equal;
}

@end
