//
//  PROModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROModel.h>
#import <Proton/EXTRuntimeExtensions.h>
#import <Proton/EXTScope.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROMultipleTransformation.h>
#import <Proton/PROUniqueTransformation.h>
#import <objc/runtime.h>

NSString * const PROModelDidTransformNotification = @"PROModelDidTransformNotification";
NSString * const PROModelTransformationFailedNotification = @"PROModelTransformationFailedNotification";
NSString * const PROModelTransformedObjectKey = @"PROModelTransformedObjectKey";
NSString * const PROModelTransformationKey = @"PROModelTransformationKey";

/*
 * A key, associated with an `NSNumber`, used in thread dictionaries to indicate
 * whether the current thread is executing a block passed to
 * <[PROModel performTransformation:]>.
 *
 * In other words, the value associated with this key will be `YES` if any
 * invocations of <[PROModel performTransformation:]> are in the call stack and
 * have yet to return.
 */
static NSString * const PROModelIsInTransformationBlockKey = @"PROModelIsInTransformationBlock";

/*
 * A key, associated with an `NSMutableDictionary`, used in thread dictionaries
 * to store the transformations that will occur when all current invocations of
 * <[PROModel performTransformation:]> finish executing.
 *
 * The keys in the associated dictionary will be <PROModel> objects, and the
 * values will be the <PROTransformation> to be applied.
 *
 * The associated dictionary will be for _all_ the currently executing
 * invocations of <[PROModel performTransformation:]> (if any).
 */
static NSString * const PROModelOutstandingTransformationsKey = @"PROModelOutstandingTransformations";

@interface PROModel () {
    BOOL m_initialized;
}

/*
 * Whether the currently executing code is running inside of a transformation
 * block (a block passed to <[PROModel performTransformation:]>) on the current
 * thread.
 */
+ (BOOL)isInTransformationBlock;

/*
 * Creates and returns a method implementation that can override a setter to
 * perform a transformation instead of a mutation.
 *
 * @param property The property to which this setter belongs.
 * @param type The Objective-C type encoding for the property.
 * @param method The original setter method of the class.
 */
+ (IMP)overriddenSetterForProperty:(objc_property_t)property type:(const char *)type method:(Method)method;

/*
 * Enumerates all the properties of the receiver and any superclasses, up until
 * (and excluding) <PROModel>.
 */
+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property))block;

/*
 * Attempts to create a new transformation which combines the effects of two
 * distinct transformations. Returns `nil` on error.
 *
 * This differs from <PROMultipleTransformation> in that the transformations are
 * not _chained_, meaning each transformation does not have to have an output
 * valid for the next one's input. Instead, their effects are combined on the
 * _initial_ value of the input object. For example, one transformation
 * overwriting an earlier one is valid, and the result is the latest
 * transformation's output.
 *
 * @param laterTransformation The transformation whose effect should come
 * afterward. The effect of this transformation may overwrite effects of the
 * `earlierTransformation`.
 * @param earlierTransformation The transformation whose effect should come
 * first.
 */
- (PROKeyedTransformation *)coalesceTransformation:(PROKeyedTransformation *)laterTransformation intoTransformation:(PROKeyedTransformation *)earlierTransformation;

/*
 * Performs the given transformation upon the receiver when the outermost
 * transformation block finishes executing, returning the object as it would be
 * transformed.
 *
 * If multiple transformations are enqueued on the receiver within the same
 * transformation block, they may be coalesced according to the semantics of
 * <[PROModel performTransformation:]>. The returned object will be the result
 * of all the coalesced transformations being applied.
 *
 * If no transformation block is executing, the transformation is performed
 * immediately, and the transformed object is returned.
 *
 * @param transformation The transformation to perform or queue.
 */
- (id)performOrQueueTransformation:(PROKeyedTransformation *)transformation;
@end

@implementation PROModel

#pragma mark Lifecycle

- (id)init {
    return [self initWithDictionary:nil];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (!self)
        return nil;

    for (NSString *key in dictionary) {
        // mark this as being autoreleased, because validateValue may return
        // a new object to be stored in this variable (and we don't want ARC to
        // double-free or leak the old or new values)
        __autoreleasing id value = [dictionary objectForKey:key];
        
        // consider NSNull to be nil if it comes in the dictionary
        if ([value isEqual:[NSNull null]]) {
            value = nil;
        }
        
        if (![self validateValue:&value forKey:key error:NULL]) {
            // validation failed
            // TODO: logging?
            return nil;
        }

        [self setValue:value forKey:key];
    }
    
    m_initialized = YES;
    return self;
}

#pragma mark Reflection

+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property))block; {
	for (Class cls = self; cls != [PROModel class]; cls = [cls superclass]) {
		unsigned count = 0;
		objc_property_t *properties = class_copyPropertyList(cls, &count);

		if (!properties)
			continue;

		for (unsigned i = 0;i < count;++i) {
			block(properties[i]);
		}

		free(properties);
	}
}

+ (void)initialize {
    /*
     * +initialize will be called for each class the first time it is used (and
     * only once); however, it's subject to normal method lookup, which means
     * that if a subclass doesn't implement it, the superclass' implementation
     * will be called.
     *
     * We do this check to make sure that we only perform the logic of this
     * method once (when +initialize is being called for PROModel itself)
     */
    if (self != [PROModel class])
        return;

    // find all subclasses and swizzle their setters to perform transformation
    // instead of mutation

    unsigned descendantCount = 0;
    Class *descendants = ext_copySubclassList(self, &descendantCount);
    if (!descendants) {
        // nothing subclasses this class
        return;
    }

    @onExit {
        free(descendants);
    };

    for (unsigned classIndex = 0; classIndex < descendantCount; ++classIndex) {
        Class class = descendants[classIndex];

        // get a list of all properties specific to THIS class (excluding
        // superclasses)
        unsigned propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);

        if (!properties) {
            // no properties here
            continue;
        }

        @onExit {
            free(properties);
        };

        for (unsigned propertyIndex = 0; propertyIndex < propertyCount; ++propertyIndex) {
            objc_property_t property = properties[propertyIndex];

            // retrieve actual meaningful information about the property
            ext_propertyAttributes *attributes = ext_copyPropertyAttributes(property);

            if (!attributes) {
                NSLog(@"*** Error occurred getting property attributes for \"%s\" on %@", property_getName(property), class);
                continue;
            }

            @onExit {
                free(attributes);
            };

            if (attributes->readonly) {
                // if this property is declared as readonly, it should not be
                // transformable, and there won't be a setter to swizzle
                continue;
            }

            Method setter = class_getInstanceMethod(class, attributes->setter);
            if (!setter) {
                NSLog(@"*** Could not find setter \"%s\" on %@", sel_getName(attributes->setter), class);
                continue;
            }

            IMP newIMP = [class overriddenSetterForProperty:property type:attributes->type method:setter];
            if (!newIMP) {
                // an error occurred
                continue;
            }

            method_setImplementation(setter, newIMP);
        }
    }
}

+ (IMP)overriddenSetterForProperty:(objc_property_t)property type:(const char *)type method:(Method)method {
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

    SEL selector = method_getName(method);
    IMP originalIMP = method_getImplementation(method);
    NSString *propertyKey = [NSString stringWithUTF8String:property_getName(property)];

    id methodBlock = nil;

    /*
     * Code dealing with individual Objective-C type encodings becomes very
     * redundant. These macros are only defined within the scope of this method
     * and are used to take care of the repetitive part.
     *
     * The goal of all the code below is to define a method which does the
     * following:
     *
     *  - If the PROModel instance is being initialized, call through to the
     *  original setter.
     *  - If the PROModel instance has been fully initialized, call through to
     *  `setValue:forKey:` with an autoboxed value, which will trigger all the
     *  transformation code in that method and prevent the actual mutation of
     *  the object.
     */

    #define NSNUMBER_METHOD_BLOCK(TYPE, NSNUMBERTYPE) \
        do { \
            methodBlock = [^(PROModel *self, TYPE value){ \
                if (self->m_initialized) \
                    [self setValue:[NSNumber numberWith ## NSNUMBERTYPE :value] forKey:propertyKey]; \
                else \
                    ((void (*)(id, SEL, TYPE))originalIMP)(self, selector, value); \
            } copy]; \
        } while (0)

    #define NSVALUE_METHOD_BLOCK(TYPE) \
        do { \
            methodBlock = [^(PROModel *self, TYPE value){ \
                if (self->m_initialized) \
                    [self setValue:[NSValue valueWithBytes:&value objCType:type] forKey:propertyKey]; \
                else \
                    ((void (*)(id, SEL, TYPE))originalIMP)(self, selector, value); \
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
                    if (self->m_initialized)
                        [self setValue:value forKey:propertyKey];
                    else
                        ((void (*)(id, SEL, id))originalIMP)(self, selector, value);
                } copy];
            }

            break;
        
        case ':':
            NSVALUE_METHOD_BLOCK(SEL);
            break;
        
        case '[':
            NSLog(@"*** Cannot override setter for array with type code \"%s\"", type);
            break;
        
        case 'b':
            NSLog(@"*** Cannot override setter for bitfield with type code \"%s\"", type);
            break;
        
        case '{':
            // TODO: add support for CGRect, CGSize, etc.?
            NSLog(@"*** Cannot override setter for struct with type code \"%s\"", type);
            break;
            
        case '(':
            NSLog(@"*** Cannot override setter for union with type code \"%s\"", type);
            break;
        
        case '?':
            // this is PROBABLY a function pointer, but the documentation
            // leaves room open for uncertainty, so fall through to the error
            // case
            
        default:
            NSLog(@"*** Cannot override setter for type code \"%s\"", type);
    }

    #undef NSNUMBER_METHOD_BLOCK
    #undef NSVALUE_METHOD_BLOCK

    if (!methodBlock)
        return NULL;

    // leak the block, since it'll be used for a method implementation, which
    // by its nature won't ever be deallocated anyways
    return imp_implementationWithBlock((__bridge_retained void *)methodBlock);
}

+ (NSArray *)propertyKeys {
	NSMutableArray *names = [[NSMutableArray alloc] init];

	[self enumeratePropertiesUsingBlock:^(objc_property_t property){
		const char *cName = property_getName(property);
		NSString *str = [[NSString alloc] initWithUTF8String:cName];

		[names addObject:str];
	}];

    if ([names count])
        return names;
    else
        return nil;
}

#pragma mark Transformation

+ (BOOL)isInTransformationBlock; {
    // check whether the current thread is running a transformation block (using
    // the thread dictionary as thread-local storage)
    NSDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumber *inBlockNumber = [threadDictionary objectForKey:PROModelIsInTransformationBlockKey];

    return [inBlockNumber boolValue];
}

+ (void)performTransformation:(void (^)(void))transformationBlock; {
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];

    // store the old value
    NSNumber *inBlockNumber = [threadDictionary objectForKey:PROModelIsInTransformationBlockKey];

    // make sure a transformations dictionary exists
    if (![threadDictionary objectForKey:PROModelOutstandingTransformationsKey]) {
        [threadDictionary setObject:[[NSMutableDictionary alloc] init] forKey:PROModelOutstandingTransformationsKey];
    }

    @onExit {
        // if there was no existing transformation block before this method,
        // that means we're the outermost invocation, and should execute any
        // coalesced transformations at this point
        if (![inBlockNumber boolValue]) {
            // save and remove the transformations (so
            // -performOrQueueTransformation: does not coalesce with what we're
            // executing right now)
            NSDictionary *transformations = [threadDictionary objectForKey:PROModelOutstandingTransformationsKey];
            [threadDictionary removeObjectForKey:PROModelOutstandingTransformationsKey];

            for (PROModel *obj in transformations) {
                id transformation = [transformations objectForKey:obj];
                [obj performOrQueueTransformation:transformation];
            }
        }
    };

    // indicate that the current thread is running a transformation block (using
    // the thread dictionary as thread-local storage)
    [threadDictionary setObject:[NSNumber numberWithBool:YES] forKey:PROModelIsInTransformationBlockKey];

    @onExit {
        // when this scope exits, restore the old value (or, if it's nil, just
        // delete the key entirely)
        if (inBlockNumber)
            [threadDictionary setObject:inBlockNumber forKey:PROModelIsInTransformationBlockKey];
        else
            [threadDictionary removeObjectForKey:PROModelIsInTransformationBlockKey];
    };

    transformationBlock();
}

- (PROKeyedTransformation *)coalesceTransformation:(PROKeyedTransformation *)laterTransformation intoTransformation:(PROKeyedTransformation *)earlierTransformation; {
    NSMutableDictionary *valueTransformations = [earlierTransformation.valueTransformations mutableCopy];
    [valueTransformations addEntriesFromDictionary:laterTransformation.valueTransformations];

    return [[PROKeyedTransformation alloc] initWithValueTransformations:valueTransformations];
}

- (id)performOrQueueTransformation:(PROKeyedTransformation *)originalTransformation; {
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSMutableDictionary *transformationsByObject = [threadDictionary objectForKey:PROModelOutstandingTransformationsKey];

    if (transformationsByObject) {
        PROKeyedTransformation *existingTransformation = [transformationsByObject objectForKey:self];
    
        // this will be the sum transformation to apply to the object
        PROKeyedTransformation *transformation;

        if (existingTransformation) {
            transformation = [self coalesceTransformation:originalTransformation intoTransformation:existingTransformation];
        } else {
            // if no existing transformation, this is the first one
            transformation = originalTransformation;
        }

        [transformationsByObject setObject:transformation forKey:self];

        // transform with what we have so far and return it, without posting any
        // notifications
        return [transformation transform:self];
    }

    // otherwise, not inside a transformation block, so we should transform and
    // post a notification
    id transformedObject = [originalTransformation transform:self];

    if (transformedObject) {
        // transformation succeeded
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            originalTransformation, PROModelTransformationKey,
            transformedObject, PROModelTransformedObjectKey,
            nil
        ];
        
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PROModelDidTransformNotification
            object:self
            userInfo:userInfo
        ];
    } else {
        // transformation failed
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            originalTransformation, PROModelTransformationKey,
            nil
        ];
        
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PROModelTransformationFailedNotification
            object:self
            userInfo:userInfo
        ];
    }

    return transformedObject;
}

- (id)transformValue:(id)value forKey:(NSString *)key {
    if (!value) {
        value = [NSNull null];
    }

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:value forKey:key];
    return [self transformValuesForKeysWithDictionary:dictionary];
}

- (id)transformValuesForKeysWithDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *transformations = [[NSMutableDictionary alloc] initWithCapacity:[dictionary count]];

    for (NSString *key in dictionary) {
        NSAssert2([key isKindOfClass:[NSString class]], @"Key passed to %s is not a string: %@", __func__, key);

        id value = [dictionary objectForKey:key];
        id originalValue = [self valueForKey:key];

        if (NSEqualObjects(value, originalValue)) {
            // nothing to do
            continue;
        }

        if (!originalValue) {
            // 'nil' needs to be represented as NSNull for PROUniqueTransformation
            originalValue = [NSNull null];
        }

        // create the transformation for the specific property
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:originalValue outputValue:value];
        [transformations setObject:transformation forKey:key];
    }

    if (![transformations count]) {
        // nothing to do
        return self;
    }
    
    // set up a key-based transformation for self
    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithValueTransformations:transformations];
    return [self performOrQueueTransformation:keyedTransformation];   
}

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    return [self dictionaryWithValuesForKeys:[[self class] propertyKeys]];
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

- (void)setValue:(id)value forKey:(NSString *)key; {
    if (!m_initialized) {
        // use superclass implementation (no magic) while initializing ourself
        [super setValue:value forKey:key];
        return;
    }

    NSAssert3([[self class] isInTransformationBlock], @"Attempting to set \"%@\" for key \"%@\" outside of a transformation block: %@", value, key, self);

    [self transformValue:value forKey:key];
}

- (void)setValuesForKeysWithDictionary:(NSDictionary *)dictionary; {
    if (!m_initialized) {
        // use superclass implementation (no magic) while initializing ourself
        [super setValuesForKeysWithDictionary:dictionary];
        return;
    }

    NSAssert2([[self class] isInTransformationBlock], @"Attempting to mutate \"%@\" outside of a transformation block with the following changes: %@", self, dictionary);

    [self transformValuesForKeysWithDictionary:dictionary];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSDictionary *dictionaryValue = [coder decodeObjectForKey:@"dictionaryValue"];
    return [self initWithDictionary:dictionaryValue];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.dictionaryValue forKey:@"dictionaryValue"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    NSMutableString *str = [[NSMutableString alloc] initWithFormat:@"<%@: %p>{", [self class], (__bridge void *)self];

    NSDictionary *dictionaryValue = self.dictionaryValue;
    NSArray *sortedKeys = [[dictionaryValue allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    [sortedKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop){
        id value = [dictionaryValue objectForKey:key];

        if (index != 0)
            [str appendString:@","];

        [str appendFormat:@"\n\t\"%@\" = %@", key, value];
    }];

    [str appendString:@"\n}"];
    return str;
}

- (NSUInteger)hash {
    return [self.dictionaryValue hash];
}

- (BOOL)isEqual:(PROModel *)model {
    if (![model isKindOfClass:[PROModel class]])
        return NO;

    return [self.dictionaryValue isEqualToDictionary:model.dictionaryValue];
}

@end
