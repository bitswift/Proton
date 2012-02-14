//
//  PROMutableModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModel.h"
#import "EXTNil.h"
#import "EXTRuntimeExtensions.h"
#import "EXTScope.h"
#import "NSArray+HigherOrderAdditions.h"
#import "PROAssert.h"
#import "PROFuture.h"
#import "PROIndexedTransformation.h"
#import "PROInsertionTransformation.h"
#import "PROKeyValueCodingMacros.h"
#import "PROKeyedTransformation.h"
#import "PROLogging.h"
#import "PROModel.h"
#import "PROMultipleTransformation.h"
#import "PROMutableModelPrivate.h"
#import "PROMutableModelTransformationLog.h"
#import "PROMutableModelTransformationResultInfo.h"
#import "PRORemovalTransformation.h"
#import "PROTransformationLogEntry.h"
#import "PROUniqueTransformation.h"
#import "SDQueue.h"
#import <objc/runtime.h>

// import geometry stuctures
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    #import <AppKit/AppKit.h>
#else
    #import <UIKit/UIKit.h>
#endif

/**
 * Private serial queue used to synchronize the creation of dynamic
 * <PROMutableModel> subclasses at runtime.
 *
 * This is necessary to protect against accidentally creating or setting up the
 * same subclass twice (if multiple threads attempt to use it for the first time
 * simultaneously).
 */
static SDQueue *PROMutableModelClassCreationQueue = nil;

@interface PROMutableModel () {
    struct {
        unsigned applyingTransformation:1;
    } m_flags;
}

// NOTE: Be careful with property names below, since this class does try to be
// a proxy for its immutable model, and we don't want to conflict with property
// names used there.

/**
 * A dispatch queue used to synchronize modifications to this model hierarchy.
 *
 * Reads should be dispatched as non-barrier blocks, since multiple reads can
 * progress in parallel. Writes should be dispatched as barrier blocks, to lock
 * out all other readers and writers while working.
 *
 * If the receiver has a <parentMutableModel>, this property will return the
 * parent's dispatch queue. The net result is that every model in a given
 * hierachy is synchronized using the furthest ancestor's dispatch queue, to
 * minimize the number of queues to jump between.
 */
@property (nonatomic, strong, readonly) SDQueue *dispatchQueue;

/**
 * The dispatch queue directly owned by the receiver.
 *
 * This should be used instead of the <dispatchQueue> property when
 * transitioning the receiver between parents.
 */
@property (nonatomic, strong, readonly) SDQueue *localDispatchQueue;

/**
 * The immutable model underlying the receiver, as transformed by everything in
 * the <transformationLog>.
 *
 * @warning **Important:** This property should only be set or read while
 * running on the <dispatchQueue>.
 */
@property (nonatomic, copy) PROModel *immutableBackingModel;

/**
 * A log storing all of the transformations that have occurred to the receiver's
 * <immutableBackingModel>.
 *
 * Parts of the transformation log functionality are exposed to consumers of
 * this class, but they are not given the ability to mutate the log directly.
 *
 * @warning **Important:** This log should only be mutated while running on the
 * <dispatchQueue>.
 */
@property (nonatomic, strong, readonly) PROMutableModelTransformationLog *transformationLog;

/**
 * A parent model that the receiver is part of, or `nil` if the receiver is the
 * root of a model hierarchy.
 *
 * This property is independently atomic because it's used to provide the
 * receiver's <dispatchQueue>, and to avoid crazy deadlocking scenarios.
 */
@property (unsafe_unretained) PROMutableModel *parentMutableModel;

/**
 * The key at which the receiver exists relative to its <parentMutableModel>, or
 * `nil` if the receiver is the root of a model hierarchy.
 *
 * @warning **Important:** This property should only be set or read while
 * running on the <dispatchQueue>, and is only updated _after_ a new
 * <parentMutableModel> is set.
 */
@property (nonatomic, copy) NSString *keyFromParentMutableModel;

/**
 * If the value corresponding to the <keyFromParentMutableModel> is an
 * indexed collection, this is the index at which the receiver exists in the
 * collection. Otherwise, this is `NSNotFound`.
 *
 * @warning **Important:** This property should only be set or read while
 * running on the <dispatchQueue>, and is only updated _after_ a new
 * <parentMutableModel> is set.
 */
@property (nonatomic, assign) NSUInteger indexFromParentMutableModel;

/**
 * Contains any <PROMutableModel> instances that the receiver owns, keyed by
 * their corresponding keys on the <immutableBackingModel>.
 *
 * If the corresponding <immutableBackingModel> property is a collection, the
 * value in this dictionary will be a collection of the same type.
 *
 * @warning **Important:** This collection should only be mutated while running
 * on the <dispatchQueue>.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *childMutableModelsByKey;

/**
 * Whether the receiver is currently executing the <applyTransformation:error:>
 * method.
 *
 * @warning **Important:** This property should only be set or read while
 * running on the <dispatchQueue>.
 */
@property (nonatomic, assign, getter = isApplyingTransformation) BOOL applyingTransformation;

/**
 * Per the documentation for `<NSKeyValueObserving>`, this property is
 * overridden for improved performance.
 */
@property (assign) void *observationInfo;

/**
 * The class of <PROModel> that this class proxies and uses for its
 * <immutableBackingModel>.
 *
 * The default implementation returns `[PROModel class]`, but
 * dynamically-created subclasses will return the class they were built for.
 */
+ (Class)modelClass;

/**
 * Given a subclass of <PROModel>, this will create or return
 * a <PROMutableModel> subclass appropriate for proxying it.
 *
 * @param modelClass A subclass of <PROModel> to proxy.
 */
+ (Class)mutableModelClassForModelClass:(Class)modelClass;

/**
 * Creates, on `mutableModelClass`, the methods necessary for instances to be
 * mutable proxies for the given property.
 *
 * @param property The property for which to synthesize setter and mutator
 * methods.
 * @param mutableModelClass The <PROMutableModel> subclass for which to
 * synthesize methods.
 */
+ (void)synthesizeProperty:(objc_property_t)property forMutableModelClass:(Class)mutableModelClass;

/**
 * Creates, on `mutableModelClass`, the key-value coding methods necessary to
 * support a mutable, indexed to-many relationship for the given key.
 *
 * @param key The property for which to synthesize indexed accessor methods.
 * @param mutableModelClass The <PROMutableModel> subclass for which to
 * synthesize methods.
 */
+ (void)synthesizeMutableIndexedAccessorsForKey:(NSString *)key forMutableModelClass:(Class)mutableModelClass;

/**
 * Returns a new method implementation that implements a setter for the given
 * property.
 *
 * The method implementation will simply call through to `setValue:forKey:` on
 * `self`.
 *
 * @param propertyKey The key for which to generate a setter.
 * @param attributes The attributes of the property.
 */
+ (IMP)synthesizedSetterForPropertyKey:(NSString *)propertyKey attributes:(const ext_propertyAttributes *)attributes;

/**
 * A set of blocks to pass to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]> when applying a transformation
 * that may need to update sub-models.
 */
- (NSDictionary *)transformationBlocks;

/**
 * Given a transformation relative to the receiver, this will return a new
 * transformation which is relative to its <parentMutableModel>. If the receiver
 * does not have a parent, returns `nil`.
 *
 * @param transformation A transformation that is defined relative to the
 * receiver.
 *
 * @warning **Important:** This method should only be invoked while running on
 * the <dispatchQueue>.
 */
- (PROTransformation *)extendTransformationToParent:(PROTransformation *)transformation;

/**
 * Enumerates over a value obtained from <childMutableModelsByKey>, which may be
 * a single object or one of a few collection types, in a uniform way.
 *
 * @param childModels A value from <childMutableModelsByKey>.
 * @param block A block to apply to every element in `childModels` (or
 * `childModels` itself, if it's a single object).
 */
- (void)enumerateChildMutableModels:(id)childModels usingBlock:(void (^)(PROMutableModel *mutableModel, BOOL *stop))block;

/**
 * Creates new <PROMutableModel> objects to correspond to those at the given key
 * path in the given model.
 *
 * This will replace any existing value in <childMutableModelsByKey>.
 *
 * @param key The key at which to create mutable models, relative to the
 * receiver (and the receiver's <immutableBackingModel>).
 * @param value The new value being set at the specified key, from which to
 * create mutable models.
 */
- (void)replaceChildMutableModelsAtKey:(NSString *)key usingValue:(id)value;

/**
 * Replaces all of the objects in <childMutableModelsByKey> with new mutable
 * model objects created to represent the receiver's <immutableBackingModel>.
 */
- (void)replaceAllChildMutableModels;

/**
 * Creates an instance of <PROMutableModelTransformationResultInfo>, fills it in
 * with the current state of the receiver, and then associates it with the
 * latest log entry in the <transformationLog>.
 */
- (void)saveTransformationResultInfoForLatestLogEntry;

/**
 * Reverts each child mutable model to the log entry corresponding to the given
 * log entry.
 *
 * @warning **Important:** This method should only be invoked while running on
 * the <dispatchQueue>.
 */
- (void)restoreMutableModelsWithTransformationLogEntry:(PROTransformationLogEntry *)logEntry;

/**
 * Generates a KVO "will change" notification for the receiver being replaced in
 * its <parentMutableModel>.
 *
 * This is used when the corresponding immutable model was replaced, but the
 * mutable model will continue to track the new value.
 *
 * @warning **Important:** This method should only be invoked while running on
 * the <dispatchQueue>.
 */
- (void)willChangeInParentMutableModel;

/**
 * Generates a KVO "did change" notification for the receiver being replaced in
 * its <parentMutableModel>.
 *
 * This is used when the corresponding immutable model was replaced, but the
 * mutable model will continue to track the new value.
 *
 * @warning **Important:** This method should only be invoked while running on
 * the <dispatchQueue>.
 */
- (void)didChangeInParentMutableModel;

@end

@implementation PROMutableModel

#pragma mark Properties

@synthesize localDispatchQueue = m_localDispatchQueue;
@synthesize immutableBackingModel = m_immutableBackingModel;
@synthesize transformationLog = m_transformationLog;
@synthesize parentMutableModel = m_parentMutableModel;
@synthesize observationInfo = m_observationInfo;
@synthesize childMutableModelsByKey = m_childMutableModelsByKey;
@synthesize keyFromParentMutableModel = m_keyFromParentMutableModel;
@synthesize indexFromParentMutableModel = m_indexFromParentMutableModel;

- (BOOL)isApplyingTransformation {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    return m_flags.applyingTransformation;
}

- (void)setApplyingTransformation:(BOOL)applying {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    m_flags.applyingTransformation = applying;
}

- (NSUInteger)archivedTransformationLogLimit {
    __block NSUInteger limit;

    [self.dispatchQueue runSynchronously:^{
        limit = self.transformationLog.maximumNumberOfArchivedLogEntries;
    }];

    return limit;
}

- (void)setArchivedTransformationLogLimit:(NSUInteger)limit {
    [self.dispatchQueue runBarrierSynchronously:^{
        self.transformationLog.maximumNumberOfArchivedLogEntries = limit;
    }];
}

- (PROTransformationLogEntry *)transformationLogEntry {
    __block PROTransformationLogEntry *logEntry;

    [self.dispatchQueue runSynchronously:^{
        logEntry = [self.transformationLog.latestLogEntry copy];
    }];

    return logEntry;
}

- (SDQueue *)dispatchQueue {
    PROMutableModel *parent = self.parentMutableModel;
    if (parent)
        return parent.dispatchQueue;
    else
        return self.localDispatchQueue;
}

#pragma mark Reflection

+ (void)initialize {
    // short-circuit calls that should initialize subclasses
    if (self != [PROMutableModel class])
        return;

    PROMutableModelClassCreationQueue = [[SDQueue alloc] init];
}

+ (Class)modelClass; {
    return [PROModel class];
}

+ (Class)mutableModelClassForModelClass:(Class)modelClass; {
    NSParameterAssert([modelClass isSubclassOfClass:[PROModel class]]);

    if ([modelClass isEqual:[PROModel class]]) {
        return [PROMutableModel class];
    }

    __block Class mutableModelClass = nil;

    [PROMutableModelClassCreationQueue runSynchronously:^{
        NSString *modelClassName = NSStringFromClass(modelClass);
        NSString *mutableModelClassName = [modelClassName stringByAppendingString:@"_PROMutableModel"];

        mutableModelClass = objc_getClass([mutableModelClassName UTF8String]);
        if (mutableModelClass) {
            // class already exists
            return;
        }

        // create superclasses along the way until we hit PROModel
        Class mutableSuperclass = [self mutableModelClassForModelClass:[modelClass superclass]];

        mutableModelClass = [self createClass:mutableModelClassName superclass:mutableSuperclass usingBlock:^(Class mutableModelClass){
            Method originalModelClassMethod = class_getClassMethod([PROMutableModel class], @selector(modelClass));
            NSAssert(originalModelClassMethod, @"Could not find +modelClass method on PROMutableModel");

            // create a block to implement the +modelClass method
            id modelClassBlock = [^(Class self){
                return modelClass;
            } copy];

            // leak the block, since it's being used to implement a method
            IMP modelClassIMP = imp_implementationWithBlock((__bridge_retained void *)modelClassBlock);
            
            BOOL success = class_addMethod(mutableModelClass, method_getName(originalModelClassMethod), modelClassIMP, method_getTypeEncoding(originalModelClassMethod));
            PROAssert(success, @"Could not add %s method to dynamic subclass %@", sel_getName(method_getName(originalModelClassMethod)), mutableModelClassName);
            
            // create setters for every property (but just on this subclass)
            unsigned propertyCount = 0;
            objc_property_t *properties = class_copyPropertyList(modelClass, &propertyCount);

            if (!properties) {
                // all done, I guess
                return;
            }

            @onExit {
                free(properties);
            };

            for (unsigned i = 0; i < propertyCount; ++i) {
                [self synthesizeProperty:properties[i] forMutableModelClass:mutableModelClass];
            }
        }];

        if (!PROAssert(mutableModelClass, @"Error creating mutable model class %@", mutableModelClassName)) {
            return;
        }
    }];

    return mutableModelClass;
}

+ (void)synthesizeProperty:(objc_property_t)property forMutableModelClass:(Class)mutableModelClass {
    ext_propertyAttributes *attributes = ext_copyPropertyAttributes(property);
    @onExit {
        free(attributes);
    };

    if (attributes->readonly) {
        // this property is readonly, skip it
        return;
    }

    NSString *propertyKey = [[NSString alloc] initWithUTF8String:property_getName(property)];

    IMP setterIMP = [self synthesizedSetterForPropertyKey:propertyKey attributes:attributes];
    if (setterIMP) {
        NSString *setterType = [[NSString alloc] initWithFormat:
            // void (PROMutableModel *self, SEL _cmd, TYPE value)
            @"%s%s%s%s",
            @encode(void),
            @encode(PROMutableModel *),
            @encode(SEL),
            attributes->type
        ];

        // TODO: this could be changed to use +resolveInstanceMethod: instead,
        // which might be cheaper if not all setters are used
        BOOL success = class_addMethod(mutableModelClass, attributes->setter, setterIMP, [setterType UTF8String]);
        PROAssert(success, @"Could not add method %@ to %@", NSStringFromSelector(attributes->setter), mutableModelClass);
    }

    Class propertyClass = attributes->objectClass;

    if ([propertyClass isSubclassOfClass:[NSArray class]] || [propertyClass isSubclassOfClass:[NSOrderedSet class]]) {
        // synthesize indexed accessors
        [self synthesizeMutableIndexedAccessorsForKey:propertyKey forMutableModelClass:mutableModelClass];
    } else if ([propertyClass isSubclassOfClass:[NSDictionary class]] || [propertyClass isSubclassOfClass:[NSSet class]]) {
        // TODO: synthesize unordered accessors
        PROAssert(NO, @"Unordered key-value coding accessors are not currently supported by PROMutableModel, property %@ will not be implemented", propertyKey);
    }
}

+ (void)synthesizeMutableIndexedAccessorsForKey:(NSString *)key forMutableModelClass:(Class)mutableModelClass; {
    NSMutableString *capitalizedKey = [[NSMutableString alloc] init];
    [capitalizedKey appendString:[[key substringToIndex:1] uppercaseString]];
    [capitalizedKey appendString:[key substringFromIndex:1]];

    SEL getterSelector = NSSelectorFromString(key);
    SEL countOfSelector = NSSelectorFromString([NSString stringWithFormat:@"countOf%@", capitalizedKey]);
    SEL objectsAtIndexesSelector = NSSelectorFromString([NSString stringWithFormat:@"%@AtIndexes:", key]);

    SEL insertSelector = NSSelectorFromString([NSString stringWithFormat:@"insert%@:atIndexes:", capitalizedKey]);
    SEL removeSelector = NSSelectorFromString([NSString stringWithFormat:@"remove%@AtIndexes:", capitalizedKey]);
    SEL replaceSelector = NSSelectorFromString([NSString stringWithFormat:@"replace%@AtIndexes:with%@:", capitalizedKey, capitalizedKey]);

    void (^installBlockMethod)(SEL, id, NSString *) = ^(SEL selector, id block, NSString *typeEncoding){
        // purposely leaks (since methods, by their nature, are never really "released")
        IMP methodIMP = imp_implementationWithBlock((__bridge_retained void *)block);

        BOOL success = class_addMethod(mutableModelClass, selector, methodIMP, [typeEncoding UTF8String]);
        PROAssert(success, @"Could not add method %@ to %@", NSStringFromSelector(selector), mutableModelClass);
    };

    // array getter
    id getterBlock = ^(PROMutableModel *self){
        __block NSArray *array;

        [self.dispatchQueue runSynchronously:^{
            array = [[self.childMutableModelsByKey objectForKey:key] copy] ?: [self.immutableBackingModel valueForKey:key];
        }];

        return array;
    };

    installBlockMethod(getterSelector, getterBlock, [NSString stringWithFormat:
        // NSArray *(PROMutableModel *self, SEL _cmd)
        @"%s%s%s",
        @encode(NSArray *),
        @encode(PROMutableModel *),
        @encode(SEL)
    ]);

    // count of objects
    id countOfMethodBlock = ^(PROMutableModel *self){
        __block NSUInteger count;

        [self.dispatchQueue runSynchronously:^{
            id models = [self.childMutableModelsByKey objectForKey:key];
            if (models)
                count = [models count];
            else
                count = [[self.immutableBackingModel valueForKey:key] count];
        }];

        return count;
    };

    installBlockMethod(countOfSelector, countOfMethodBlock, [NSString stringWithFormat:
        // NSUInteger (PROMutableModel *self, SEL _cmd)
        @"%s%s%s",
        @encode(NSUInteger),
        @encode(PROMutableModel *),
        @encode(SEL)
    ]);

    // objects at indexes
    id objectsAtIndexesBlock = ^(PROMutableModel *self, NSIndexSet *indexes){
        __block NSArray *objects;

        [self.dispatchQueue runSynchronously:^{
            id collection = [self.childMutableModelsByKey objectForKey:key] ?: [self.immutableBackingModel valueForKey:key];
            objects = [collection objectsAtIndexes:indexes];
        }];

        return objects;
    };

    installBlockMethod(objectsAtIndexesSelector, objectsAtIndexesBlock, [NSString stringWithFormat:
        // NSArray * (PROMutableModel *self, SEL _cmd, NSIndexSet *indexes)
        @"%s%s%s%s",
        @encode(NSArray *),
        @encode(PROMutableModel *),
        @encode(SEL),
        @encode(NSIndexSet *)
    ]);

    // insertion
    id insertMethodBlock = ^(PROMutableModel *self, NSArray *objects, NSIndexSet *indexes){
        [self.dispatchQueue runBarrierSynchronously:^{
            if (!self.applyingTransformation) {
                // create a transformation and apply it
                PROTransformation *arrayTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:indexes objects:objects];
                PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:key];

                NSError *error = nil;
                PROAssert([self applyTransformation:keyedTransformation error:&error], @"Could not insert %@ at indexes %@ in \"%@\" on %@: %@", objects, indexes, key, self, error);

                return;
            }

            // we're in the middle of applying a transformation, so we should
            // actually update our mutable collections
            id mutableCollection = [self.childMutableModelsByKey objectForKey:key];
            if (!PROAssert(mutableCollection, @"No mutable collection exists at \"%@\" on %@", key, self))
                return;

            [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:key];
            @onExit {
                [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:key];
            };

            __block NSUInteger setIndex = 0;
            [indexes enumerateIndexesWithOptions:NSEnumerationConcurrent usingBlock:^(NSUInteger finalIndex, BOOL *stop){
                PROMutableModel *mutableModel = [objects objectAtIndex:setIndex++];
                NSAssert([mutableModel isKindOfClass:[PROMutableModel class]], @"Object to insert %@ at \"%@\" on %@ is not a PROMutableModel", mutableModel, key, self);

                // make sure this model finishes anything currently in progress
                [mutableModel.localDispatchQueue runBarrierSynchronously:^{
                    mutableModel.parentMutableModel = self;
                    mutableModel.keyFromParentMutableModel = key;
                    mutableModel.indexFromParentMutableModel = finalIndex;
                }];
            }];

            [mutableCollection insertObjects:objects atIndexes:indexes];
        }];
    };

    installBlockMethod(insertSelector, insertMethodBlock, [NSString stringWithFormat:
        // void (PROMutableModel *self, SEL _cmd, NSArray *objects, NSIndexSet *indexes)
        @"%s%s%s%s%s",
        @encode(void),
        @encode(PROMutableModel *),
        @encode(SEL),
        @encode(NSArray *),
        @encode(NSIndexSet *)
    ]);

    // removal
    id removeMethodBlock = ^(PROMutableModel *self, NSIndexSet *indexes){
        [self.dispatchQueue runBarrierSynchronously:^{
            if (!self.applyingTransformation) {
                // create a transformation and apply it
                NSArray *expectedObjects = [[self copy] valueForKey:key];

                PROTransformation *arrayTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexes expectedObjects:expectedObjects];
                PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:key];

                NSError *error = nil;
                PROAssert([self applyTransformation:keyedTransformation error:&error], @"Could not remove indexes %@ from \"%@\" on %@: %@", indexes, key, self, error);

                return;
            }
            
            // we're in the middle of applying a transformation, so we should
            // actually update our mutable collections
            id mutableCollection = [self.childMutableModelsByKey objectForKey:key];
            if (!PROAssert(mutableCollection, @"No mutable collection exists at \"%@\" on %@", key, self))
                return;

            [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:key];
            @onExit {
                [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:key];
            };

            NSArray *objectsBeingRemoved = [mutableCollection objectsAtIndexes:indexes];
            [objectsBeingRemoved enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(PROMutableModel *mutableModel, NSUInteger index, BOOL *stop){
                NSAssert([mutableModel isKindOfClass:[PROMutableModel class]], @"Object to insert %@ at \"%@\" on %@ is not a PROMutableModel", mutableModel, key, self);

                // take over this model's queue until we've successfully
                // detached it, to avoid any race conditions from it being used
                // in the tiny window when it won't use our queue anymore
                [mutableModel.localDispatchQueue runBarrierSynchronously:^{
                    mutableModel.indexFromParentMutableModel = NSNotFound;
                    mutableModel.keyFromParentMutableModel = nil;
                    mutableModel.parentMutableModel = nil;
                }];
            }];

            [mutableCollection removeObjectsAtIndexes:indexes];
        }];
    };

    installBlockMethod(removeSelector, removeMethodBlock, [NSString stringWithFormat:
        // void (PROMutableModel *self, SEL _cmd, NSIndexSet *indexes)
        @"%s%s%s%s",
        @encode(void),
        @encode(PROMutableModel *),
        @encode(SEL),
        @encode(NSIndexSet *)
    ]);

    // replacement
    id replaceMethodBlock = ^(PROMutableModel *self, NSIndexSet *indexes, NSArray *newObjects){
        [self.dispatchQueue runBarrierSynchronously:^{
            if (!self.applyingTransformation) {
                // create a transformation and apply it
                NSArray *originalObjects = [[[self copy] valueForKey:key] objectsAtIndexes:indexes];
                NSMutableArray *uniqueTransformations = [[NSMutableArray alloc] initWithCapacity:[indexes count]];

                [newObjects enumerateObjectsUsingBlock:^(id newObject, NSUInteger arrayIndex, BOOL *stop){
                    id originalObject = [originalObjects objectAtIndex:arrayIndex];
                    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:originalObject outputValue:newObject];

                    [uniqueTransformations addObject:uniqueTransformation];
                }];

                PROTransformation *arrayTransformation = [[PROIndexedTransformation alloc] initWithIndexes:indexes transformations:uniqueTransformations];
                PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:key];

                NSError *error = nil;
                PROAssert([self applyTransformation:keyedTransformation error:&error], @"Could not replace objects at indexes %@ with %@ in \"%@\" on %@: %@", indexes, newObjects, key, self, error);

                return;
            }
            
            // we're in the middle of applying a transformation, so we should
            // actually update our mutable collections
            id mutableCollection = [self.childMutableModelsByKey objectForKey:key];
            if (!PROAssert(mutableCollection, @"No mutable collection exists at \"%@\" on %@", key, self))
                return;

            [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:indexes forKey:key];
            @onExit {
                [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:indexes forKey:key];
            };

            NSArray *objectsBeingRemoved = [mutableCollection objectsAtIndexes:indexes];

            // the synchronization strategy here is a bit different, because we
            // need to protect both old and new values during the transition,
            // while also avoiding deadlocks, so... synchronize all the things!
            NSMutableSet *allQueues = [NSMutableSet setWithCapacity:[mutableCollection count] + [newObjects count]];

            [allQueues addObjectsFromArray:[objectsBeingRemoved mapUsingBlock:^(PROMutableModel *mutableModel){
                return mutableModel.localDispatchQueue;
            }]];

            [allQueues addObjectsFromArray:[newObjects mapUsingBlock:^(PROMutableModel *mutableModel){
                return mutableModel.localDispatchQueue;
            }]];

            [SDQueue synchronizeQueues:allQueues.allObjects runSynchronously:^{
                // order is important here: we detach all the old objects before
                // attaching the new ones in order to gracefully handle objects
                // common to both
                [objectsBeingRemoved enumerateObjectsUsingBlock:^(PROMutableModel *mutableModel, NSUInteger index, BOOL *stop){
                    mutableModel.indexFromParentMutableModel = NSNotFound;
                    mutableModel.keyFromParentMutableModel = nil;
                    mutableModel.parentMutableModel = nil;
                }];
                
                __block NSUInteger setIndex = 0;
                [indexes enumerateIndexesUsingBlock:^(NSUInteger finalIndex, BOOL *stop){
                    PROMutableModel *mutableModel = [newObjects objectAtIndex:setIndex++];

                    NSAssert([mutableModel isKindOfClass:[PROMutableModel class]], @"Expected a mutable model to insert, got %@ at \"%@\" on %@", mutableModel, key, self);

                    mutableModel.parentMutableModel = self;
                    mutableModel.keyFromParentMutableModel = key;
                    mutableModel.indexFromParentMutableModel = finalIndex;
                }];

                [mutableCollection replaceObjectsAtIndexes:indexes withObjects:newObjects];
            }];
        }];
    };

    installBlockMethod(replaceSelector, replaceMethodBlock, [NSString stringWithFormat:
        // void (PROMutableModel *self, SEL _cmd, NSIndexSet *indexes, NSArray *objects)
        @"%s%s%s%s%s",
        @encode(void),
        @encode(PROMutableModel *),
        @encode(SEL),
        @encode(NSIndexSet *),
        @encode(NSArray *)
    ]);
}

+ (IMP)synthesizedSetterForPropertyKey:(NSString *)propertyKey attributes:(const ext_propertyAttributes *)attributes {
    const char *type = attributes->type;

    // skip attributes in the provided type encoding
    while (
        *type == 'r' ||
        *type == 'n' ||
        *type == 'N' ||
        *type == 'o' ||
        *type == 'O' ||
        *type == 'R' ||
        *type == 'V'
    ) {
        ++type;
    }

    id methodBlock = nil;

    /*
     * Code dealing with individual Objective-C type encodings becomes very
     * redundant. These macros are only defined within the scope of this method
     * and are used to take care of the repetitive part.
     *
     * The goal of all the code below is to define a method which calls through
     * to `setValue:forKey:` with an autoboxed value, thus triggering all the
     * code to generate and store transformations.
     */

    #define NSNUMBER_METHOD_BLOCK(TYPE, NSNUMBERTYPE) \
        do { \
            methodBlock = [^(PROMutableModel *self, TYPE value){ \
                [self setValue:[NSNumber numberWith ## NSNUMBERTYPE :value] forKey:propertyKey]; \
            } copy]; \
        } while (0)

    #define NSVALUE_METHOD_BLOCK(TYPE) \
        do { \
            methodBlock = [^(PROMutableModel *self, TYPE value){ \
                [self setValue:[NSValue valueWithBytes:&value objCType:type] forKey:propertyKey]; \
            } copy]; \
        } while (0)

    switch (*type) {
        case 'c':
            NSNUMBER_METHOD_BLOCK(char, Char);
            break;

        case 'i':
            NSNUMBER_METHOD_BLOCK(int, Int);
            break;

        case 's':
            NSNUMBER_METHOD_BLOCK(short, Short);
            break;

        case 'l':
            NSNUMBER_METHOD_BLOCK(long, Long);
            break;

        case 'q':
            NSNUMBER_METHOD_BLOCK(long long, LongLong);
            break;

        case 'C':
            NSNUMBER_METHOD_BLOCK(unsigned char, UnsignedChar);
            break;

        case 'I':
            NSNUMBER_METHOD_BLOCK(unsigned int, UnsignedInt);
            break;

        case 'S':
            NSNUMBER_METHOD_BLOCK(unsigned short, UnsignedShort);
            break;

        case 'L':
            NSNUMBER_METHOD_BLOCK(unsigned long, UnsignedLong);
            break;

        case 'Q':
            NSNUMBER_METHOD_BLOCK(unsigned long long, UnsignedLongLong);
            break;

        case 'f':
            NSNUMBER_METHOD_BLOCK(float, Float);
            break;

        case 'd':
            NSNUMBER_METHOD_BLOCK(double, Double);
            break;

        case 'B':
            NSNUMBER_METHOD_BLOCK(_Bool, Bool);
            break;

        case '^':
        case '*':
            NSVALUE_METHOD_BLOCK(void *);
            break;

        case '#':
        case '@':
            {
                methodBlock = [^(PROModel *self, id value){
                    [self setValue:value forKey:propertyKey];
                } copy];
            }

            break;

        case ':':
            NSVALUE_METHOD_BLOCK(SEL);
            break;

        case '[':
            NSAssert(NO, @"*** Cannot generate setter for array with type code \"%s\"", type);
            break;

        case 'b':
            NSAssert(NO, @"*** Cannot generate setter for bitfield with type code \"%s\"", type);
            break;

        case '{':
            if (strcmp(type, @encode(CGRect)) == 0
            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                || strcmp(type, @encode(NSRect)) == 0
            #endif
            ) {
                methodBlock = [^(PROMutableModel *self, CGRect value){
                    NSValue *valueObj;

                    #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                        valueObj = [NSValue valueWithRect:value];
                    #else
                        valueObj = [NSValue valueWithCGRect:value];
                    #endif

                    [self setValue:valueObj forKey:propertyKey];
                } copy];

                break;
            }

            if (strcmp(type, @encode(CGSize)) == 0
            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                || strcmp(type, @encode(NSSize)) == 0
            #endif
            ) {
                methodBlock = [^(PROMutableModel *self, CGSize value){
                    NSValue *valueObj;

                    #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                        valueObj = [NSValue valueWithSize:value];
                    #else
                        valueObj = [NSValue valueWithCGSize:value];
                    #endif

                    [self setValue:valueObj forKey:propertyKey];
                } copy];

                break;
            }

            if (strcmp(type, @encode(CGPoint)) == 0
            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                || strcmp(type, @encode(NSPoint)) == 0
            #endif
            ) {
                methodBlock = [^(PROMutableModel *self, CGPoint value){
                    NSValue *valueObj;

                    #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                        valueObj = [NSValue valueWithPoint:value];
                    #else
                        valueObj = [NSValue valueWithCGPoint:value];
                    #endif

                    [self setValue:valueObj forKey:propertyKey];
                } copy];

                break;
            }

            if (strcmp(type, @encode(NSRange)) == 0) {
                NSVALUE_METHOD_BLOCK(NSRange);
                break;
            }

            NSAssert(NO, @"*** Cannot generate setter for struct with type code \"%s\"", type);
            break;

        case '(':
            NSAssert(NO, @"*** Cannot generate setter for union with type code \"%s\"", type);
            break;

        case '?':
            // this is PROBABLY a function pointer, but the documentation
            // leaves room open for uncertainty, so fall through to the error
            // case

        default:
            NSAssert(NO, @"*** Cannot generate setter for type code \"%s\"", type);
    }

    #undef NSNUMBER_METHOD_BLOCK
    #undef NSVALUE_METHOD_BLOCK

    if (!methodBlock)
        return NULL;

    // leak the block, since it'll be used for a method implementation, which
    // by its nature won't ever be deallocated anyways
    return imp_implementationWithBlock((__bridge_retained void *)methodBlock);
}

#pragma mark Lifecycle

- (id)init {
    NSAssert(NO, @"Use -initWithModel: to initialize a PROMutableModel");
    return nil;
}

- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    PROModel *model = [[[self.class modelClass] alloc] initWithDictionary:dictionary error:error];
    if (model)
        return [self initWithModel:model];
    else
        return nil;
}

- (id)initWithModel:(PROModel *)model; {
    if (!model)
        return nil;

    self = [super init];
    if (!self)
        return nil;

    m_localDispatchQueue = [[SDQueue alloc] initWithPriority:DISPATCH_QUEUE_PRIORITY_DEFAULT concurrent:YES label:@"com.bitswift.Proton.PROMutableModel"];
    if (!PROAssert(m_localDispatchQueue, @"Could not initialize new custom GCD queue for %@", self))
        return nil;

    m_immutableBackingModel = [model copy];
    m_indexFromParentMutableModel = NSNotFound;

    m_transformationLog = [[PROMutableModelTransformationLog alloc] init];
    m_transformationLog.maximumNumberOfArchivedLogEntries = 50;

    Class mutableModelClass = [[self class] mutableModelClassForModelClass:[model class]];
    if (PROAssert(mutableModelClass, @"Mutable model class should've been created for %@", [model class])) {
        // dynamically become the subclass appropriate for this model, to
        // have the proper setter and mutation methods
        object_setClass(self, mutableModelClass);
    }

    m_childMutableModelsByKey = [NSMutableDictionary dictionary];

    // set up all of our child mutable models
    [self.localDispatchQueue runBarrierSynchronously:^{
        [self replaceAllChildMutableModels];
    }];

    return self;
}

- (id)initWithMutableModel:(PROMutableModel *)model; {
    NSParameterAssert(!model || [model isKindOfClass:[PROMutableModel class]]);

    if (!model)
        return nil;

    __block PROModel *immutableModel;
    __block PROMutableModelTransformationLog *transformationLog;

    [model.dispatchQueue runSynchronously:^{
        immutableModel = model.immutableBackingModel;

        // we need to copy the transformation log to make sure we can unwind as
        // far back as the given model
        transformationLog = [model.transformationLog copy];
    }];

    // this should properly recreate most of the bookkeeping data we need
    self = [self initWithModel:immutableModel];
    if (!self)
        return nil;

    m_transformationLog = transformationLog;
    return self;
}

- (void)dealloc {
    [self.localDispatchQueue runBarrierSynchronously:^{
        // detach all children
        [self.childMutableModelsByKey enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop){
            [self enumerateChildMutableModels:value usingBlock:^(PROMutableModel *mutableModel, BOOL *stop){
                mutableModel.indexFromParentMutableModel = NSNotFound;
                mutableModel.keyFromParentMutableModel = nil;
                mutableModel.parentMutableModel = nil;
            }];
        }];

        [self.childMutableModelsByKey removeAllObjects];
    }];
}

#pragma mark Performing Transformations

- (BOOL)applyTransformation:(PROTransformation *)transformation error:(NSError **)error; {
    NSParameterAssert(transformation != nil);

    __block NSError *strongError = nil;
    __block BOOL success = YES;

    [self.dispatchQueue runBarrierSynchronously:^{
        if (!PROAssert(!self.applyingTransformation, @"%s should not be invoked recursively", __func__)) {
            success = NO;
            return;
        }

        self.applyingTransformation = YES;
        @onExit {
            self.applyingTransformation = NO;
        };

        PROMutableModel *parentModel = self.parentMutableModel;

        // if we have a parent, apply this directly to the parent instead
        if (parentModel && PROAssert(self.keyFromParentMutableModel, @"Should have a key from parent model %@", parentModel)) {
            success = [parentModel applyTransformation:[self extendTransformationToParent:transformation] error:&strongError];
            return;
        }

        id oldModel = self.immutableBackingModel;
        if (!PROAssert(oldModel, @"Backing model of %@ should never be nil", self)) {
            oldModel = [EXTNil null];
        }

        PROModel *newModel = [transformation transform:oldModel error:&strongError];
        if (!newModel) {
            // fail immediately, before any side effects
            success = NO;
            return;
        }

        PROTransformationLogEntry *lastLogEntry = self.transformationLog.latestLogEntry;
        [self.transformationLog appendTransformation:transformation];

        PROTransformationLogEntry *newLogEntry = self.transformationLog.latestLogEntry;
        self.immutableBackingModel = newModel;

        PROAssert([transformation applyBlocks:self.transformationBlocks transformationResult:newModel keyPath:nil], @"Block application should never fail at top level");
        [self saveTransformationResultInfoForLatestLogEntry];
    }];

    if (strongError && error)
        *error = strongError;

    return success;
}

- (PROTransformation *)extendTransformationToParent:(PROTransformation *)transformation; {
    NSAssert(self.dispatchQueue.currentQueue, @"PROTransformationNewValueForKeyPathBlock should only be executed while running on the dispatch queue");

    if (!self.keyFromParentMutableModel)
        return nil;

    if (self.indexFromParentMutableModel != NSNotFound)
        transformation = [[PROIndexedTransformation alloc] initWithIndex:self.indexFromParentMutableModel transformation:transformation];

    return [[PROKeyedTransformation alloc] initWithTransformation:transformation forKey:self.keyFromParentMutableModel];
}

- (NSDictionary *)transformationBlocks; {
    PROTransformationNewValueForKeyPathBlock transformationNewValueForKeyPathBlock = ^(PROTransformation *transformation, id value, NSString *keyPath){
        NSAssert(self.dispatchQueue.currentQueue, @"PROTransformationNewValueForKeyPathBlock should only be executed while running on the dispatch queue");

        if (!keyPath) {
            if (!PROAssert([value isKindOfClass:[PROModel class]], @"%@ is not a PROModel, don't know how to update from it", value))
                return NO;

            // this was a change or replacement of the whole model -- send
            // a notification indicating that we got "replaced" in our parent
            [self willChangeInParentMutableModel];

            self.immutableBackingModel = value;
            [self replaceAllChildMutableModels];

            [self didChangeInParentMutableModel];
            return YES;
        }

        NSRange firstSeparatorRange = [keyPath rangeOfString:@"."];
        NSString *firstKey;

        // TODO: implement change notifications on whole key paths?
        if (firstSeparatorRange.location != NSNotFound)
            firstKey = [keyPath substringToIndex:firstSeparatorRange.location];
        else
            firstKey = keyPath;

        // TODO: the willChange notification needs to occur _before_ the
        // transformation
        [self willChangeValueForKey:firstKey];
        @onExit {
            [self didChangeValueForKey:firstKey];
        };

        id childModels = [self.childMutableModelsByKey objectForKey:keyPath];
        if (childModels) {
            // this was a replacement of a whole collection of child models
            [self replaceChildMutableModelsAtKey:firstKey usingValue:value];
            return YES;
        } else {
            // some property we don't care about
            return NO;
        }
    };

    PROTransformationMutableArrayForKeyPathBlock transformationMutableArrayForKeyPathBlock = ^ id (PROTransformation *transformation, NSString *keyPath){
        NSAssert(self.dispatchQueue.currentQueue, @"PROTransformationMutableArrayForKeyPathBlock should only be executed while running on the dispatch queue");

        if ([self.childMutableModelsByKey objectForKey:keyPath])
            return [self mutableArrayValueForKey:keyPath];
        else
            return nil;
    };

    PROTransformationWrappedValueForKeyPathBlock transformationWrappedValueForKeyPathBlock = ^ id (PROTransformation *transformation, id value, NSString *keyPath){
        NSAssert(self.dispatchQueue.currentQueue, @"PROTransformationWrappedValueForKeyPathBlock should only be executed while running on the dispatch queue");

        Class modelClass = [[self.immutableBackingModel.class modelClassesByKey] objectForKey:keyPath];
        if (modelClass)
            return [[PROMutableModel alloc] initWithModel:value];
        else
            return value;
    };

    PROTransformationBlocksForIndexAtKeyPathBlock transformationBlocksForIndexAtKeyPathBlock = ^(id transformation, NSUInteger modelIndex, NSString *keyPath, NSDictionary *blocks){
        NSAssert(self.dispatchQueue.currentQueue, @"PROTransformationBlocksForIndexAtKeyPathBlock should only be executed while running on the dispatch queue");

        id childModels = [self.childMutableModelsByKey objectForKey:keyPath];
        if (!PROAssert([childModels respondsToSelector:@selector(objectAtIndex:)], @"%@ is not an indexed collection, cannot perform an indexed transformation on it", childModels))
            return blocks;

        PROMutableModel *mutableModel = [childModels objectAtIndex:modelIndex];

        if (PROAssert([transformation isKindOfClass:[PROIndexedTransformation class]], @"Transformation diving down into an index should be a PROIndexedTransformation: %@", transformation)) {
            NSUInteger indexCount = [[transformation indexes] count];
            NSUInteger *indexes = malloc(sizeof(*indexes) * indexCount);
            if (PROAssert(indexes, @"Could not allocate space for %lu indexes", (unsigned long)indexCount)) {
                @onExit {
                    free(indexes);
                };

                [[transformation indexes] getIndexes:indexes maxCount:indexCount inIndexRange:nil];

                PROTransformation *modelTransformation = nil;

                // we need to find the index INTO the index set where the
                // modelIndex is located, so we can pull out the corresponding
                // transformation
                for (NSUInteger setIndex = 0; setIndex < indexCount; ++setIndex) {
                    if (indexes[setIndex] == modelIndex) {
                        modelTransformation = [[transformation transformations] objectAtIndex:setIndex];
                        break;
                    }
                }
                
                if (PROAssert(modelTransformation, @"Could not find the transformation being performed on %@ in %@", mutableModel, transformation)) {
                    // append this transformation to the sub-model's log
                    [mutableModel.transformationLog appendTransformation:modelTransformation];
                }
            }
        }

        return [mutableModel transformationBlocks];
    };

    return [NSDictionary dictionaryWithObjectsAndKeys:
        [transformationNewValueForKeyPathBlock copy], PROTransformationNewValueForKeyPathBlockKey,
        [transformationMutableArrayForKeyPathBlock copy], PROTransformationMutableArrayForKeyPathBlockKey,
        [transformationWrappedValueForKeyPathBlock copy], PROTransformationWrappedValueForKeyPathBlockKey,
        [transformationBlocksForIndexAtKeyPathBlock copy], PROTransformationBlocksForIndexAtKeyPathBlockKey,
        nil
    ];
}

#pragma mark Child Models

- (void)enumerateChildMutableModels:(id)childModels usingBlock:(void (^)(PROMutableModel *mutableModel, BOOL *stop))block; {
    NSParameterAssert(childModels != nil);
    NSParameterAssert(block != nil);

    if ([childModels isKindOfClass:[NSDictionary class]]) {
        // TODO
        PROAssert(NO, @"A dictionary of child models is not currently supported: %@", childModels);
    } else if ([childModels conformsToProtocol:@protocol(NSFastEnumeration)]) {
        BOOL stop = NO;

        for (PROMutableModel *mutableModel in childModels) {
            NSAssert([mutableModel isKindOfClass:[PROMutableModel class]], @"%@ should be a PROMutableModel in collection %@", mutableModel, childModels);

            block(mutableModel, &stop);
            if (stop)
                break;
        }
    } else {
        if (!PROAssert([childModels isKindOfClass:[PROMutableModel class]], @"Unknown child models object: %@", childModels))
            return;

        BOOL unused;
        block(childModels, &unused);
    }
}

- (void)replaceAllChildMutableModels {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    [[self.immutableBackingModel.class modelClassesByKey] enumerateKeysAndObjectsUsingBlock:^(NSString *key, Class modelClass, BOOL *stop){
        id value = [self.immutableBackingModel valueForKey:key];
        [self replaceChildMutableModelsAtKey:key usingValue:value];
    }];
}

- (void)replaceChildMutableModelsAtKey:(NSString *)key usingValue:(id)value; {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    // replace the key with a future, so we don't perform the work of the setup
    // unless we need it
    PROFuture *future = nil;

    // this should already be immutable, but let's make doubly-sure, since we're
    // going to be sticking it into a future
    value = [value copy];

    id previousValue = [self.childMutableModelsByKey objectForKey:key];
    if (previousValue && ![previousValue isKindOfClass:[PROFuture class]]) {
        // detach all previous values at this key
        [self enumerateChildMutableModels:previousValue usingBlock:^(PROMutableModel *mutableModel, BOOL *stop){
            // skip any unresolved futures
            if ([mutableModel isKindOfClass:[PROFuture class]])
                return;

            [mutableModel.localDispatchQueue runBarrierSynchronously:^{
                // TODO: this code seems to repeat a lot -- refactor that shit,
                // yo
                mutableModel.keyFromParentMutableModel = nil;
                mutableModel.indexFromParentMutableModel = NSNotFound;
                mutableModel.parentMutableModel = nil;
            }];
        }];
    }

    // this isn't __weak because it's only referenced in the resolution of the
    // futures below, and the futures themselves will be destroyed when we are
    // (also, weak variables are surprisingly expensive)
    __unsafe_unretained PROMutableModel *weakSelf = self;

    if ([value isKindOfClass:[NSArray class]]) {
        future = [PROFuture futureWithBlock:^{
            NSMutableArray *mutableValues = [NSMutableArray arrayWithCapacity:[value count]];

            [value enumerateObjectsUsingBlock:^(PROModel *model, NSUInteger index, BOOL *stop){
                // with an array, we can also future each object, since futures
                // are cheaper than instances of this class
                id mutableModelFuture = [PROFuture futureWithBlock:^{
                    PROMutableModel *mutableModel = [[PROMutableModel alloc] initWithModel:model];

                    mutableModel.parentMutableModel = weakSelf;
                    mutableModel.keyFromParentMutableModel = key;
                    mutableModel.indexFromParentMutableModel = index;

                    return mutableModel;
                }];

                [mutableValues addObject:mutableModelFuture];
            }];

            return mutableValues;
        }];
    } else if ([value isKindOfClass:[NSOrderedSet class]]) {
        future = [PROFuture futureWithBlock:^{
            NSMutableOrderedSet *mutableValues = [NSMutableOrderedSet orderedSetWithCapacity:[value count]];

            [value enumerateObjectsUsingBlock:^(PROModel *model, NSUInteger index, BOOL *stop){
                PROMutableModel *mutableModel = [[PROMutableModel alloc] initWithModel:model];

                mutableModel.parentMutableModel = weakSelf;
                mutableModel.keyFromParentMutableModel = key;
                mutableModel.indexFromParentMutableModel = index;

                [mutableValues addObject:mutableModel];
            }];

            return mutableValues;
        }];
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        // TODO 
        PROAssert(NO, @"Unordered collections are not currently supported by PROMutableModel, key \"%@\" will not be set", key);
    } else if ([value isKindOfClass:[NSSet class]]) {
        // TODO
        PROAssert(NO, @"Unordered collections are not currently supported by PROMutableModel, key \"%@\" will not be set", key);
    } else {
        if (!PROAssert([value isKindOfClass:[PROModel class]], @"Unrecognized value %@ to make mutable for key \"%@\"", value, key))
            return;

        future = [PROFuture futureWithBlock:^{
            PROMutableModel *mutableModel = [[PROMutableModel alloc] initWithModel:value];
            mutableModel.parentMutableModel = weakSelf;
            mutableModel.keyFromParentMutableModel = key;
            mutableModel.indexFromParentMutableModel = NSNotFound;

            return mutableModel;
        }];
    }

    [self willChangeValueForKey:key];
    @onExit {
        [self didChangeValueForKey:key];
    };

    if (future)
        [self.childMutableModelsByKey setObject:future forKey:key];
    else if (previousValue)
        [self.childMutableModelsByKey removeObjectForKey:future];
}

#pragma mark Transformation Log

- (id)modelWithTransformationLogEntry:(PROTransformationLogEntry *)transformationLogEntry; {
    NSParameterAssert(transformationLogEntry != nil);

    __block PROModel *currentModel = nil;
    __block PROTransformation *transformationFromOldModel = nil;

    [self.dispatchQueue runSynchronously:^{
        transformationFromOldModel = [self.transformationLog multipleTransformationFromLogEntry:transformationLogEntry toLogEntry:self.transformationLog.latestLogEntry];
        if (transformationFromOldModel)
            currentModel = self.immutableBackingModel;
    }];

    if (!transformationFromOldModel)
        return nil;

    PROTransformation *transformationToOldModel = transformationFromOldModel.reverseTransformation;
    PROModel *oldModel = [transformationToOldModel transform:currentModel error:NULL];
    NSAssert(oldModel != nil, @"Transformation from current model %@ to previous model should never fail: %@", currentModel, transformationToOldModel);

    return oldModel;
}

- (BOOL)restoreTransformationLogEntry:(PROTransformationLogEntry *)transformationLogEntry; {
    NSParameterAssert(transformationLogEntry != nil);

    __block BOOL success = NO;

    [self.dispatchQueue runBarrierSynchronously:^{
        PROTransformation *transformationFromLogEntryModel = [self.transformationLog multipleTransformationFromLogEntry:transformationLogEntry toLogEntry:self.transformationLog.latestLogEntry];
        if (!transformationFromLogEntryModel)
            return;

        PROTransformation *transformationToLogEntryModel = transformationFromLogEntryModel.reverseTransformation;

        PROMutableModel *parent = self.parentMutableModel;
        if (parent) {
            // restoration needs to be delegated to the parent, just like
            // transformation
            PROTransformationLogEntry *parentLogEntry = [parent.transformationLog logEntryWithMutableModel:self childLogEntry:transformationLogEntry];

            if (parentLogEntry) {
                success = [parent restoreTransformationLogEntry:parentLogEntry];
            } else {
                // don't really think this is an erroneous case, but we need to
                // make sure it gets handled properly (i.e., doesn't cause
                // problems with child models), so add some obnoxious logging for now
                DDLogError(@"Could not find parent log entry for log entry %@ from %@", transformationLogEntry, self);

                // if this parent doesn't have a corresponding log entry, its
                // log either got trimmed sooner than ours, or we switched
                // parents at some point -- fall back to just applying
                // a transformation up through the parent (if it would be valid
                // to do so)
                success = [self applyTransformation:transformationToLogEntryModel error:NULL];
            }

            return;
        }

        PROModel *currentModel = self.immutableBackingModel;
        PROModel *newModel = [transformationToLogEntryModel transform:currentModel error:NULL];
        if (!PROAssert(newModel, @"Transformation from current model %@ to previous model should never fail: %@", currentModel, transformationToLogEntryModel))
            return;

        if (![self.transformationLog moveToLogEntry:transformationLogEntry])
            return;

        self.immutableBackingModel = newModel;
        PROAssert([transformationToLogEntryModel applyBlocks:self.transformationBlocks transformationResult:newModel keyPath:nil], @"Block application should never fail at top level");

        [self restoreMutableModelsWithTransformationLogEntry:transformationLogEntry];

        success = YES;
    }];

    return success;
}

- (void)restoreMutableModelsWithTransformationLogEntry:(PROTransformationLogEntry *)logEntry {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be invoked while running on the dispatch queue", __func__);

    PROMutableModelTransformationResultInfo *resultInfo = [self.transformationLog.transformationResultInfoByLogEntry objectForKey:logEntry];
    if (!PROAssert(resultInfo.mutableModelsByKey.count == resultInfo.logEntriesByMutableModel.count, @"Models %@ do not match log entries %@", resultInfo.mutableModelsByKey, resultInfo.logEntriesByMutableModel))
        return;

    [resultInfo.mutableModelsByKey enumerateKeysAndObjectsUsingBlock:^(NSString *key, id restoredModels, BOOL *stop){
        // TODO: this won't work with other collection types
        NSMutableArray *existingMutableModels = [self mutableArrayValueForKey:key];
        [existingMutableModels removeAllObjects];

        [self enumerateChildMutableModels:restoredModels usingBlock:^(PROMutableModel *mutableModel, BOOL *stop){
            PROTransformationLogEntry *childLogEntry = [resultInfo.logEntriesByMutableModel objectForKey:mutableModel];
            if (!PROAssert(childLogEntry, @"Could not find log entry for model %@ in result info %@", mutableModel, resultInfo))
                return;

            if (!PROAssert([mutableModel.transformationLog moveToLogEntry:childLogEntry], @"Could not move model %@ to log entry %@", mutableModel, childLogEntry))
                return;

            [mutableModel restoreMutableModelsWithTransformationLogEntry:childLogEntry];
            [existingMutableModels addObject:mutableModel];
        }];
    }];
}

- (void)saveTransformationResultInfoForLatestLogEntry; {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    PROMutableModelTransformationResultInfo *resultInfo = [[PROMutableModelTransformationResultInfo alloc] init];
    resultInfo.mutableModelsByKey = self.childMutableModelsByKey;

    NSMutableArray *mutableModels = [NSMutableArray array];
    NSMutableArray *logEntries = [NSMutableArray array];

    [self.childMutableModelsByKey enumerateKeysAndObjectsUsingBlock:^(NSString *key, id childModels, BOOL *stop){
        [self enumerateChildMutableModels:childModels usingBlock:^(PROMutableModel *mutableModel, BOOL *stop){
            [mutableModel saveTransformationResultInfoForLatestLogEntry];
        
            id modelEntry = mutableModel.transformationLogEntry;
            if (!PROAssert(modelEntry, @"Could not retrieve log entry from model %@", mutableModel))
                modelEntry = [EXTNil null];

            [mutableModels addObject:mutableModel];
            [logEntries addObject:modelEntry];
        }];
    }];

    [resultInfo setLogEntries:logEntries forMutableModels:mutableModels];
    [self.transformationLog.transformationResultInfoByLogEntry setObject:resultInfo forKey:self.transformationLog.latestLogEntry];
}

#pragma mark Forwarding

- (BOOL)respondsToSelector:(SEL)selector {
    return [self.copy respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return self.copy;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.copy];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.copy methodSignatureForSelector:selector];
}

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    return [self.copy dictionaryValue];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROModel *model = [coder decodeObjectForKey:PROKeyForObject(self, immutableBackingModel)];
    if (!model)
        return nil;

    self = [super init];
    if (!self)
        return nil;

    m_localDispatchQueue = [[SDQueue alloc] initWithPriority:DISPATCH_QUEUE_PRIORITY_DEFAULT concurrent:YES label:@"com.bitswift.Proton.PROMutableModel"];
    if (!PROAssert(m_localDispatchQueue, @"Could not initialize new custom GCD queue for %@", self))
        return nil;

    m_immutableBackingModel = [model copy];
    m_transformationLog = [coder decodeObjectForKey:PROKeyForObject(self, transformationLog)];

    m_parentMutableModel = [coder decodeObjectForKey:PROKeyForObject(self, parentMutableModel)];
    if (m_parentMutableModel) {
        m_keyFromParentMutableModel = [coder decodeObjectForKey:PROKeyForObject(self, keyFromParentMutableModel)];
        m_indexFromParentMutableModel = [coder decodeIntegerForKey:PROKeyForObject(self, indexFromParentMutableModel)];
    }

    m_childMutableModelsByKey = [[coder decodeObjectForKey:PROKeyForObject(self, childMutableModelsByKey)] mutableCopy];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [self.dispatchQueue runSynchronously:^{
        [coder encodeObject:self.immutableBackingModel forKey:PROKeyForObject(self, immutableBackingModel)];

        if (self.transformationLog)
            [coder encodeObject:self.transformationLog forKey:PROKeyForObject(self, transformationLog)];

        PROMutableModel *parent = self.parentMutableModel;
        if (parent) {
            [coder encodeConditionalObject:parent forKey:PROKeyForObject(self, parentMutableModel)];
            [coder encodeInteger:self.indexFromParentMutableModel forKey:PROKeyForObject(self, indexFromParentMutableModel)];

            if (self.keyFromParentMutableModel)
                [coder encodeObject:self.keyFromParentMutableModel forKey:PROKeyForObject(self, keyFromParentMutableModel)];
        }

        if (self.childMutableModelsByKey)
            [coder encodeObject:self.childMutableModelsByKey forKey:PROKeyForObject(self, childMutableModelsByKey)];
    }];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone; {
    __block PROModel *immutableModel;
    
    [self.dispatchQueue runSynchronously:^{
        immutableModel = [self.immutableBackingModel copy];
    }];

    return immutableModel;
}

#pragma mark NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone; {
    return [[[self class] allocWithZone:zone] initWithMutableModel:self];
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

- (id)valueForKey:(NSString *)key {
    __block id value;

    [self.dispatchQueue runSynchronously:^{
        value = [self.childMutableModelsByKey objectForKey:key] ?: [self.immutableBackingModel valueForKey:key];
    }];

    return value;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [self.dispatchQueue runBarrierSynchronously:^{
        id currentValue = [self.immutableBackingModel valueForKey:key];

        PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:currentValue outputValue:value];
        PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:transformation forKey:key];

        NSError *error = nil;
        PROAssert([self applyTransformation:keyedTransformation error:&error], @"Setting value %@ for key \"%@\" on %@ failed: %@", value, key, self, error);
    }];
}

- (NSMutableOrderedSet *)mutableOrderedSetValueForKey:(NSString *)key {
    PROAssert(NO, @"%s is not implemented", __func__);
    return nil;
}

- (NSMutableSet *)mutableSetValueForKey:(NSString *)key {
    PROAssert(NO, @"%s is not implemented", __func__);
    return nil;
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    // implement all KVO manually (and also thus prevent KVO from creating
    // dynamic subclasses of our dynamic subclasses)
    return NO;
}

- (void)willChangeInParentMutableModel; {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    PROMutableModel *parent = self.parentMutableModel;
    if (!parent)
        return;

    NSString *key = self.keyFromParentMutableModel;
    if (!PROAssert(key, @"%@ does not have a key on to notify about on its parent %@", self, parent))
        return;

    if (self.indexFromParentMutableModel == NSNotFound) {
        [parent willChangeValueForKey:key];
    } else {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.indexFromParentMutableModel];
        [parent willChange:NSKeyValueChangeReplacement valuesAtIndexes:indexSet forKey:key];
    }
}

- (void)didChangeInParentMutableModel; {
    NSAssert(self.dispatchQueue.currentQueue, @"%s should only be executed while running on the dispatch queue", __func__);

    PROMutableModel *parent = self.parentMutableModel;
    if (!parent)
        return;

    NSString *key = self.keyFromParentMutableModel;
    if (!PROAssert(key, @"%@ does not have a key on to notify about on its parent %@", self, parent))
        return;

    if (self.indexFromParentMutableModel == NSNotFound) {
        [parent didChangeValueForKey:key];
    } else {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.indexFromParentMutableModel];
        [parent didChange:NSKeyValueChangeReplacement valuesAtIndexes:indexSet forKey:key];
    }
}

#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>( model = %@ )", [self class], (__bridge void *)self, [self copy]];
}

- (NSUInteger)hash {
    return [self.copy hash];
}

- (BOOL)isKindOfClass:(Class)class {
    if ([super isKindOfClass:class])
        return YES;

    return [self.copy isKindOfClass:class];
}

- (BOOL)isMemberOfClass:(Class)class {
    if ([super isMemberOfClass:class])
        return YES;

    return [self.copy isMemberOfClass:class];
}

- (BOOL)isEqual:(id)model {
    if (model == self)
        return YES;

    if ([model isKindOfClass:[PROModel class]]) {
        return [self.copy isEqual:model];
    }
    
    if (![model isKindOfClass:[PROMutableModel class]])
        return NO;

    return [[self copy] isEqual:[model copy]];
}

- (BOOL)isProxy {
    return YES;
}

@end
