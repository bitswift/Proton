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
#import "PROAssert.h"
#import "PROKeyedTransformation.h"
#import "PROKeyValueCodingMacros.h"
#import "PROLogging.h"
#import "PROModel.h"
#import "PROModelController.h"
#import "PROMultipleTransformation.h"
#import "PROMutableModelPrivate.h"
#import "SDQueue.h"
#import <objc/runtime.h>

static SDQueue *PROMutableModelClassCreationQueue = nil;

/**
 * This class should avoid as many properties as possible, since it
 * functions like a proxy.
 */
@interface PROMutableModel () {
    /**
     * The model managed by this object, as transformed by everything in
     * <m_transformations>.
     */
    PROModel *m_latestModel;

    /**
     * Transformations representing all of the changes made so far, with the
     * latest transformation at the end of the array.
     */
    NSMutableArray *m_transformations;
}

/**
 * Given a subclass of <PROModel>, this will create or return
 * a <PROMutableModel> subclass appropriate for proxying it.
 *
 * @param modelClass A subclass of <PROModel> to proxy.
 */
+ (Class)mutableModelClassForModelClass:(Class)modelClass;

/**
 * Creates the methods necessary for the `mutableModelClass` to be a mutable
 * proxy for the given property of the `modelClass`.
 * 
 * @param property The property for which to synthesize setter and mutator
 * methods.
 * @param mutableModelClass The <PROMutableModel> subclass for which to
 * synthesize methods.
 * @param modelClass The <PROModel> class being proxied.
 */
+ (void)synthesizeProperty:(objc_property_t)property forMutableModelClass:(Class)mutableModelClass modelClass:(Class)modelClass;

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

@end

@implementation PROMutableModel

#pragma mark Properties

@synthesize modelController = m_modelController;

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
                [self synthesizeProperty:properties[i] forMutableModelClass:mutableModelClass modelClass:modelClass];
            }
        }];

        if (!PROAssert(mutableModelClass, @"Error creating mutable model class %@", mutableModelClassName)) {
            return;
        }
    }];

    return mutableModelClass;
}

+ (void)synthesizeProperty:(objc_property_t)property forMutableModelClass:(Class)mutableModelClass modelClass:(Class)modelClass; {
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
            // void (id self, SEL _cmd, TYPE value)
            @"%s%s%s%s",
            @encode(void),
            @encode(id),
            @encode(SEL),
            attributes->type
        ];

        // TODO: this could be changed to use +resolveInstanceMethod: instead,
        // which might be cheaper if not all setters are used
        BOOL success = class_addMethod(mutableModelClass, attributes->setter, setterIMP, [setterType UTF8String]);
        PROAssert(success, @"Could not add method %@ to %@", NSStringFromSelector(attributes->setter), mutableModelClass);
    }
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
            DDLogError(@"*** Cannot generate setter for array with type code \"%s\"", type);
            break;
        
        case 'b':
            DDLogError(@"*** Cannot generate setter for bitfield with type code \"%s\"", type);
            break;
        
        case '{':
            if (strcmp(type, @encode(CGRect)) == 0
            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                || strcmp(type, @encode(NSRect)) == 0
            #endif
            ) {
                NSVALUE_METHOD_BLOCK(CGRect);
                break;
            }
            
            if (strcmp(type, @encode(CGSize)) == 0
            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                || strcmp(type, @encode(NSSize)) == 0
            #endif
            ) {
                NSVALUE_METHOD_BLOCK(CGSize);
                break;
            }
            
            if (strcmp(type, @encode(CGPoint)) == 0
            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                || strcmp(type, @encode(NSPoint)) == 0
            #endif
            ) {
                NSVALUE_METHOD_BLOCK(CGPoint);
                break;
            }
            
            if (strcmp(type, @encode(NSRange)) == 0) {
                NSVALUE_METHOD_BLOCK(NSRange);
                break;
            }

            DDLogError(@"*** Cannot generate setter for struct with type code \"%s\"", type);
            break;
            
        case '(':
            DDLogError(@"*** Cannot generate setter for union with type code \"%s\"", type);
            break;
        
        case '?':
            // this is PROBABLY a function pointer, but the documentation
            // leaves room open for uncertainty, so fall through to the error
            // case
            
        default:
            DDLogError(@"*** Cannot generate setter for type code \"%s\"", type);
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

    m_transformations = [[NSMutableArray alloc] init];
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

    self = [self initWithModel:modelController.model];
    if (!self)
        return nil;

    m_modelController = modelController;
    return self;
}

#pragma mark Saving

- (BOOL)save:(NSError **)error; {
    if (!m_modelController || ![m_transformations count])
        return YES;

    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:m_transformations];
    if (![m_modelController performTransformation:transformation error:error]) {
        return NO;
    }

    // "flush" our model object, to get the latest version
    m_latestModel = [m_modelController.model copy];
    
    // get rid of our record of transformations, now that they're saved
    [m_transformations removeAllObjects];

    return YES;
}

#pragma mark Forwarding

- (BOOL)respondsToSelector:(SEL)selector {
    return [m_latestModel respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return m_latestModel;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:m_latestModel];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [m_latestModel methodSignatureForSelector:selector];
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
    m_transformations = [[coder decodeObjectForKey:@"transformations"] mutableCopy];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:m_latestModel forKey:@"model"];
    [coder encodeObject:m_transformations forKey:@"transformations"];

    if (m_modelController)
        [coder encodeObject:m_modelController forKey:PROKeyForObject(self, modelController)];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone; {
    return [m_latestModel copy];
}

#pragma mark NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone; {
    PROMutableModel *model = [[[self class] alloc] init];

    model->m_latestModel = [m_latestModel copy];
    model->m_transformations = [m_transformations mutableCopy];
    model->m_modelController = self.modelController;

    return model;
}

#pragma mark NSKeyValueCoding

- (id)valueForKey:(NSString *)key {
    return [m_latestModel valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    PROKeyedTransformation *transformation = [m_latestModel transformationForKey:key value:value];
    if (!transformation) {
        // nothing to do
        return;
    }

    NSError *error = nil;
    PROModel *newModel = [transformation transform:m_latestModel error:&error];
    if (!PROAssert(newModel, @"Changing \"%@\" on %@ to %@ is invalid: %@", key, m_latestModel, value, error)) {
        return;
    }

    [self willChangeValueForKey:key];
    @onExit {
        [self didChangeValueForKey:key];
    };

    [m_transformations addObject:transformation];
    m_latestModel = [newModel copy];
}

- (NSMutableArray *)mutableArrayValueForKey:(NSString *)key {
    return nil;
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
    return [m_latestModel hash];
}

- (BOOL)isEqual:(id)model {
    if ([model isKindOfClass:[PROModel class]]) {
        return [m_latestModel isEqual:model];
    } else if ([model isKindOfClass:[PROMutableModel class]]) {
        PROMutableModel *mutableModel = model;
        return [m_latestModel isEqual:mutableModel->m_latestModel];
    } else {
        return NO;
    }
}

- (BOOL)isProxy {
    return YES;
}

@end
