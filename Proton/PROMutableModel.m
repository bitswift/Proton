//
//  PROMutableModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModel.h"
#import "EXTRuntimeExtensions.h"
#import "EXTScope.h"
#import "NSArray+HigherOrderAdditions.h"
#import "PROAssert.h"
#import "PROIndexedTransformation.h"
#import "PROInsertionTransformation.h"
#import "PROKeyValueCodingMacros.h"
#import "PROKeyedTransformation.h"
#import "PROLogging.h"
#import "PROModel.h"
#import "PROModelController.h"
#import "PROModelControllerTransformationLogEntry.h"
#import "PROMultipleTransformation.h"
#import "PROMutableModelPrivate.h"
#import "PRORemovalTransformation.h"
#import "PROTransformationLog.h"
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

NSString * const PROMutableModelDidRebaseFromModelControllerNotification = @"PROMutableModelDidRebaseFromModelControllerNotification";
NSString * const PROMutableModelRebaseFromModelControllerFailedNotification = @"PROMutableModelRebaseFromModelControllerFailedNotification";
NSString * const PROMutableModelRebaseErrorKey = @"PROMutableModelRebaseError";

static SDQueue *PROMutableModelClassCreationQueue = nil;

/**
 * This class should avoid as many properties as possible, since it
 * functions like a proxy.
 */
@interface PROMutableModel () {
    /**
     * A private dispatch queue used to synchronize modifications to this
     * object.
     */
    SDQueue *m_dispatchQueue;

    /**
     * The model managed by this object, as transformed by everything in
     * <m_transformationLog> after <m_originalModelLogEntry>.
     */
    PROModel *m_latestModel;

    /**
     * The log entry corresponding to the version of the model that was
     * last retrieved from the <modelController>.
     */
    PROTransformationLogEntry *m_originalModelLogEntry;

    /**
     * Transformation log containing all of the changes made since
     * <m_originalModelLogEntry>.
     */
    PROTransformationLog *m_transformationLog;
}

/**
 * Atomic getter for the <m_latestModel> instance variable.
 */
@property (copy, readonly) PROModel *latestModel;

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
 * Attempts to transform the underlying <PROModel> object by transforming the
 * given key.
 *
 * @param transformation The transformation to attempt.
 * @param key The key upon which to apply the transformation.
 */
- (void)performTransformation:(PROTransformation *)transformation forKey:(NSString *)key;

/**
 * Invoked when the receiver's <modelController> just completed
 * a transformation.
 */
- (void)modelControllerDidPerformTransformation:(NSNotification *)notification;

/**
 * Attempts to rebase the receiver's changes on top of the given model. Returns
 * whether the rebase succeeded.
 *
 * This method does not post any notifications.
 *
 * @param newModel The model to rebase onto.
 * @param oldModel The original model, on which `transformation` was applied,
 * resulting in `newModel`.
 * @param transformation A transformation that describes what changed between
 * the previous version of the model and `newModel`.
 * @param error If this is not `NULL` and the method returns `NO`, this may be
 * set to the error that occurred.
 */
- (BOOL)rebaseOntoModel:(PROModel *)newModel oldModel:(PROModel *)oldModel transformation:(PROTransformation *)transformation error:(NSError **)error;

/**
 * A set of blocks to pass to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]> to implement rebasing behavior.
 */
- (NSDictionary *)rebasingTransformationBlocks;

@end

@implementation PROMutableModel

#pragma mark Properties

@synthesize modelController = m_modelController;

- (PROModel *)latestModel {
    __block PROModel *model;

    [m_dispatchQueue runSynchronously:^{
        model = [m_latestModel copy];
    }];

    return model;
}

#pragma mark Reflection

+ (void)initialize {
    // short-circuit calls that should initialize subclasses
    if (self != [PROMutableModel class])
        return;

    PROMutableModelClassCreationQueue = [[SDQueue alloc] init];
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
    } else if ([propertyClass isSubclassOfClass:[NSDictionary class]]) {
        // TODO: synthesize unordered accessors
    }
}

+ (void)synthesizeMutableIndexedAccessorsForKey:(NSString *)key forMutableModelClass:(Class)mutableModelClass; {
    NSMutableString *capitalizedKey = [[NSMutableString alloc] init];
    [capitalizedKey appendString:[[key substringToIndex:1] uppercaseString]];
    [capitalizedKey appendString:[key substringFromIndex:1]];

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

    // count of objects
    id countOfMethodBlock = ^(PROMutableModel *self){
        return [[self.latestModel valueForKey:key] count];
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
        return [[self.latestModel valueForKey:key] objectsAtIndexes:indexes];
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
        PROTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:indexes objects:objects];

        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:key];
        @onExit {
            [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:key];
        };

        [self->m_dispatchQueue runSynchronously:^{
            [self performTransformation:transformation forKey:key];
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
        [self->m_dispatchQueue runSynchronously:^{
            NSArray *expectedObjects = [self->m_latestModel valueForKey:key];

            [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:key];
            @onExit {
                [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:key];
            };

            PROTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexes expectedObjects:expectedObjects];
            [self performTransformation:transformation forKey:key];
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
        [self->m_dispatchQueue runSynchronously:^{
            NSArray *originalObjects = [[self->m_latestModel valueForKey:key] objectsAtIndexes:indexes];
            NSMutableArray *uniqueTransformations = [[NSMutableArray alloc] initWithCapacity:[indexes count]];

            [newObjects enumerateObjectsUsingBlock:^(id newObject, NSUInteger arrayIndex, BOOL *stop){
                id originalObject = [originalObjects objectAtIndex:arrayIndex];
                PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:originalObject outputValue:newObject];

                [uniqueTransformations addObject:uniqueTransformation];
            }];

            [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:indexes forKey:key];
            @onExit {
                [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:indexes forKey:key];
            };

            PROTransformation *transformation = [[PROIndexedTransformation alloc] initWithIndexes:indexes transformations:uniqueTransformations];
            [self performTransformation:transformation forKey:key];
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

#pragma mark Initialization

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_dispatchQueue = [[SDQueue alloc] initWithPriority:DISPATCH_QUEUE_PRIORITY_DEFAULT concurrent:NO label:@"com.bitswift.Proton.PROMutableModel"];
    return self;
}

- (id)initWithModel:(PROModel *)model; {
    if (!model)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    m_latestModel = [model copy];

    Class mutableModelClass = [[self class] mutableModelClassForModelClass:[model class]];
    if (PROAssert(mutableModelClass, @"Mutable model class should've been created for %@", [model class])) {
        // dynamically become the subclass appropriate for this model, to
        // have the proper setter and mutation methods
        object_setClass(self, mutableModelClass);
    }

    return self;
}

- (id)initWithModelController:(PROModelController *)modelController; {
    if (!modelController)
        return nil;

    PROModel *model = nil;
    m_originalModelLogEntry = [modelController transformationLogEntryWithModelPointer:&model];

    self = [self initWithModel:model];
    if (!self)
        return nil;

    m_modelController = modelController;
    m_transformationLog = [[PROTransformationLog alloc] initWithLogEntry:m_originalModelLogEntry];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(modelControllerDidPerformTransformation:)
        name:PROModelControllerDidPerformTransformationNotification
        object:modelController
    ];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Transformation

- (void)performTransformation:(PROTransformation *)transformation forKey:(NSString *)key; {
    NSParameterAssert(transformation != nil);
    NSParameterAssert(key != nil);

    NSAssert(m_dispatchQueue.currentQueue, @"%s should only be invoked while on the dispatch queue", __func__);

    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:transformation forKey:key];

    NSError *error = nil;
    PROModel *newModel = [keyedTransformation transform:m_latestModel error:&error];
    if (!PROAssert(newModel, @"Transformation %@ on key \"%@\" of %@ is invalid: %@", transformation, key, m_latestModel, error)) {
        return;
    }

    [m_transformationLog appendTransformation:keyedTransformation];
    m_latestModel = [newModel copy];
}

#pragma mark Rebasing

- (NSDictionary *)rebasingTransformationBlocks; {
    PROTransformationNewValueForKeyPathBlock transformationNewValueForKeyPathBlock = ^(id value, NSString *keyPath){
        if (!keyPath) {
            // we can set a new value for 'self' (by setting the latest model),
            // but we can't generate KVO for it
            m_latestModel = value;
            return NO;
        }

        [self setValue:value forKeyPath:keyPath];
        return YES;
    };

    PROTransformationMutableArrayForKeyPathBlock transformationMutableArrayForKeyPathBlock = ^(NSString *keyPath){
        return [self mutableArrayValueForKeyPath:keyPath];
    };

    PROTransformationWrappedValueForKeyPathBlock transformationWrappedValueForKeyPathBlock = ^(id value, NSString *keyPath){
        // we don't need to wrap values
        return value;
    };

    PROTransformationBlocksForIndexAtKeyPathBlock transformationBlocksForIndexAtKeyPathBlock = ^(NSUInteger index, NSString *keyPath, NSDictionary *blocks){
        id value = [[self valueForKeyPath:keyPath] objectAtIndex:index];
        if ([value isKindOfClass:[PROMutableModel class]])
            return [value rebasingTransformationBlocks];
        else
            return blocks;
    };

    return [NSDictionary dictionaryWithObjectsAndKeys:
        [transformationNewValueForKeyPathBlock copy], PROTransformationNewValueForKeyPathBlockKey,
        [transformationMutableArrayForKeyPathBlock copy], PROTransformationMutableArrayForKeyPathBlockKey,
        [transformationWrappedValueForKeyPathBlock copy], PROTransformationWrappedValueForKeyPathBlockKey,
        [transformationBlocksForIndexAtKeyPathBlock copy], PROTransformationBlocksForIndexAtKeyPathBlockKey,
        nil
    ];
}

- (BOOL)rebaseOntoModel:(PROModel *)newModel oldModel:(PROModel *)oldModel transformation:(PROTransformation *)transformation error:(NSError **)error; {
    NSParameterAssert(newModel != nil);
    NSParameterAssert(oldModel != nil);
    NSParameterAssert(transformation != nil);

    NSAssert(m_dispatchQueue.currentQueue, @"%s should only be invoked while on the dispatch queue", __func__);

    // if we have any transformations, we need to unwind before attempting to
    // rebase
    BOOL needsUnwind = ![m_originalModelLogEntry isEqual:m_transformationLog.latestLogEntry];
    PROModel *rebasedModel;

    if (!needsUnwind) {
        rebasedModel = newModel;
    } else {
        PROMultipleTransformation *logTransformation = [m_transformationLog multipleTransformationFromLogEntry:m_originalModelLogEntry toLogEntry:m_transformationLog.latestLogEntry];

        // unwind all the way back to our original model
        NSError *localError = nil; 
        oldModel = [logTransformation.reverseTransformation transform:m_latestModel error:&localError];
        if (!PROAssert(oldModel, @"Could not unwind latest model of %@: %@", self, localError)) {
            if (error)
                *error = localError;

            return NO;
        }

        NSArray *newTransformations = [NSArray arrayWithObjects:transformation, logTransformation, nil];
        transformation = [[PROMultipleTransformation alloc] initWithTransformations:newTransformations];

        // make sure we can actually apply everything together
        rebasedModel = [transformation transform:oldModel error:error];
        if (!rebasedModel) {
            return NO;
        }
    }

    m_latestModel = oldModel;

    NSDictionary *blocks = [self rebasingTransformationBlocks];

    // apply the new transformation from the model controller
    PROAssert([transformation applyBlocks:blocks transformationResult:rebasedModel], @"Could not apply transformation %@ to %@", transformation, self);
    
    m_latestModel = rebasedModel;
    return YES;
}

- (void)modelControllerDidPerformTransformation:(NSNotification *)notification; {
    [m_dispatchQueue runSynchronously:^{
        PROModel *newModel = [notification.userInfo objectForKey:PROModelControllerNewModelKey];
        if (!PROAssert(newModel, @"Notification did not contain a new model object: %@", notification))
            return;

        PROModel *oldModel = [notification.userInfo objectForKey:PROModelControllerOldModelKey];
        if (!PROAssert(oldModel, @"Notification did not contain an old model object: %@", notification))
            return;

        PROTransformation *transformation = [notification.userInfo objectForKey:PROModelControllerTransformationKey];
        if (!PROAssert(transformation, @"Notification did not contain a transformation: %@", notification))
            return;

        NSError *error = nil;
        if ([self rebaseOntoModel:newModel oldModel:oldModel transformation:transformation error:&error]) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:PROMutableModelDidRebaseFromModelControllerNotification
                object:self
            ];
        } else {
            NSDictionary *userInfo = nil;
            if (error)
                userInfo = [NSDictionary dictionaryWithObject:error forKey:PROMutableModelRebaseErrorKey];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:PROMutableModelRebaseFromModelControllerFailedNotification
                object:self
                userInfo:userInfo
            ];
        }
    }];
}

#pragma mark Saving

- (BOOL)save:(NSError **)error; {
    __block BOOL success = YES;
    __block NSError *strongError = nil;

    [m_dispatchQueue runSynchronously:^{
        if (!m_modelController)
            return;

        id latestLogEntry = m_transformationLog.latestLogEntry;

        // try restoring the model on the model controller first (if the log entry
        // is compatible)
        if (![latestLogEntry isKindOfClass:[PROModelControllerTransformationLogEntry class]] || ![m_modelController restoreModelFromTransformationLogEntry:latestLogEntry]) {
            PROMultipleTransformation *transformation = [m_transformationLog multipleTransformationFromLogEntry:m_originalModelLogEntry toLogEntry:latestLogEntry];
            if (![m_modelController performTransformation:transformation error:&strongError]) {
                success = NO;
                return;
            }
        }

        // "flush" our model object, to get the latest version, and empty our
        // transformation log
        PROModel *newModel = nil;
        PROTransformationLogEntry *newLogEntry = [m_modelController transformationLogEntryWithModelPointer:&newModel];
        if (!PROAssert(newLogEntry, @"Could not get transformation log entry from controller %@", m_modelController)) {
            success = NO;
            return;
        }

        m_latestModel = newModel;
        m_originalModelLogEntry = newLogEntry;

        [m_transformationLog addOrReplaceLogEntry:m_originalModelLogEntry];
        [m_transformationLog removeAllLogEntries];
    }];

    if (strongError && error)
        *error = strongError;

    return success;
}

#pragma mark Forwarding

- (BOOL)respondsToSelector:(SEL)selector {
    return [self.latestModel respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return self.latestModel;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.latestModel];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.latestModel methodSignatureForSelector:selector];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROModel *model = [coder decodeObjectForKey:@"model"];
    if (!model)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    m_latestModel = model;
    m_modelController = [coder decodeObjectForKey:PROKeyForObject(self, modelController)];
    m_transformationLog = [coder decodeObjectForKey:@"transformationLog"];
    m_originalModelLogEntry = [coder decodeObjectForKey:@"originalModelLogEntry"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (m_latestModel)
        [coder encodeObject:m_latestModel forKey:@"model"];

    if (m_modelController)
        [coder encodeObject:m_modelController forKey:PROKeyForObject(self, modelController)];

    if (m_transformationLog)
        [coder encodeObject:m_transformationLog forKey:@"transformationLog"];

    if (m_originalModelLogEntry)
        [coder encodeObject:m_originalModelLogEntry forKey:@"originalModelLogEntry"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone; {
    return self.latestModel;
}

#pragma mark NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone; {
    PROMutableModel *model = [[[self class] alloc] init];

    [m_dispatchQueue runSynchronously:^{
        model->m_latestModel = [m_latestModel copy];
        model->m_modelController = self.modelController;
        model->m_transformationLog = [m_transformationLog copy];
        model->m_originalModelLogEntry = [m_originalModelLogEntry copy];
    }];

    return model;
}

#pragma mark NSKeyValueCoding

- (id)valueForKey:(NSString *)key {
    NSDictionary *modelControllerKeys = [[self.modelController class] modelControllerKeysByModelKeyPath];
    NSString *modelControllersKey = [modelControllerKeys objectForKey:key];

    if (!modelControllersKey)
        return [self.latestModel valueForKey:key];

    NSArray *modelControllers = [self.modelController valueForKey:modelControllersKey];

    return [modelControllers mapUsingBlock:^(id modelController) {
        return [[PROMutableModel alloc] initWithModelController:modelController];
    }];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [m_dispatchQueue runSynchronously:^{
        id currentValue = [m_latestModel valueForKey:key];
        PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:currentValue outputValue:value];

        [self willChangeValueForKey:key];
        @onExit {
            [self didChangeValueForKey:key];
        };

        [self performTransformation:transformation forKey:key];
    }];
}

- (NSMutableOrderedSet *)mutableOrderedSetValueForKey:(NSString *)key {
    return nil;
}

- (NSMutableSet *)mutableSetValueForKey:(NSString *)key {
    return nil;
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    // implement all KVO manually (and also thus prevent KVO from creating
    // dynamic subclasses of our dynamic subclasses)
    return NO;
}

#pragma mark NSObject protocol

- (NSUInteger)hash {
    return [self.latestModel hash];
}

- (BOOL)isEqual:(id)model {
    if ([model isKindOfClass:[PROModel class]]) {
        return [self.latestModel isEqual:model];
    } else if ([model isKindOfClass:[PROMutableModel class]]) {
        PROMutableModel *mutableModel = model;
        return [self.latestModel isEqual:mutableModel.latestModel];
    } else {
        return NO;
    }
}

- (BOOL)isProxy {
    return YES;
}

@end
