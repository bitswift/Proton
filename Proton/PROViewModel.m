//
//  PROViewModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 01.04.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROViewModel.h"
#import "EXTRuntimeExtensions.h"
#import "EXTScope.h"
#import "NSObject+ComparisonAdditions.h"
#import "NSObject+PROKeyValueObserverAdditions.h"
#import "PROAssert.h"
#import "PROBinding.h"
#import "PROKeyValueCodingMacros.h"
#import <objc/runtime.h>

@interface PROViewModel ()
/**
 * Provides for more efficient key-value observing on the receiver, per the
 * `<NSKeyValueObserving>` documentation.
 */
@property (assign) void *observationInfo;

/**
 * Enumerates all the properties of the receiver and any superclasses, up until
 * (and excluding) <PROViewModel>.
 *
 * @param block A block to execute for each property of the receiver and its
 * superclasses. This will be passed the property information and the name of
 * the property itself.
 */
+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property, NSString *key))block;
@end

@implementation PROViewModel

#pragma mark - Properties

@synthesize model = m_model;
@synthesize observationInfo = m_observationInfo;
@synthesize initializingFromArchive = m_initializingFromArchive;
@synthesize parentViewModel = m_parentViewModel;

- (void)setModel:(id)model {
    if (model == m_model)
        return;

    [self removeAllOwnedObservers];
    [PROBinding removeAllBindingsFromOwner:self];

    m_model = model;
}

- (PROViewModel *)rootViewModel {
    PROViewModel *parent = self;

    do {
        parent = parent.parentViewModel;
    } while(parent.parentViewModel);

    return parent;
}

#pragma mark - Lifecycle

- (id)init; {
    self = [super init];
    if (!self)
        return nil;

    NSDictionary *defaultValues = [[self class] defaultValuesForKeys];
    if (defaultValues)
        [self setValuesForKeysWithDictionary:defaultValues];

    return self;
}

- (id)initWithModel:(id)model; {
    self = [self init];
    if (!self)
        return nil;

    self.model = model;
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self removeAllOwnedObservers];
    [PROBinding removeAllBindingsFromOwner:self];
}

#pragma mark - Reflection

+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property, NSString *key))block; {
    for (Class cls = self; cls != [PROViewModel class]; cls = [cls superclass]) {
        unsigned count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);

        if (!properties)
            continue;

        for (unsigned i = 0;i < count;++i) {
            objc_property_t property = properties[i];

            NSString *key = [NSString stringWithUTF8String:property_getName(property)];
            block(property, key);
        }

        free(properties);
    }
}

#pragma mark - Property Information

+ (NSDictionary *)defaultValuesForKeys; {
    return [NSDictionary dictionary];
}

+ (PROViewModelEncodingBehavior)encodingBehaviorForKey:(NSString *)key; {
    // never encode the model of a view model, since the latter becomes unwieldy
    // for UI restoration if we do that
    if ([key isEqualToString:PROKeyForClass(PROViewModel, model)])
        return PROViewModelEncodingBehaviorNone;

    objc_property_t property = class_getProperty(self, key.UTF8String);
    if (!PROAssert(property, @"Could not find property \"%@\" on %@", key, self.class))
        return PROViewModelEncodingBehaviorNone;

    ext_propertyAttributes *attributes = ext_copyPropertyAttributes(property);
    if (!PROAssert(attributes, @"Could not retrieve attributes for property \"%@\" on %@", key, self.class))
        return PROViewModelEncodingBehaviorNone;

    @onExit {
        free(attributes);
    };

    if (attributes->readonly)
        return PROViewModelEncodingBehaviorNone;

    if (attributes->objectClass || attributes->type[0] == @encode(id)[0]) {
        if (attributes->weak || attributes->memoryManagementPolicy == ext_propertyMemoryManagementPolicyAssign)
            return PROViewModelEncodingBehaviorConditional;
    }

    return PROViewModelEncodingBehaviorUnconditional;
}

#pragma mark - Validation

- (BOOL)validateAction:(SEL)action; {
    NSParameterAssert(action);

    if (![self respondsToSelector:action])
        return NO;

    NSString *name = NSStringFromSelector(action);
    if ([name hasSuffix:@":"]) {
        name = [name substringToIndex:name.length - 1];

        if (!PROAssert([name rangeOfString:@":"].location == NSNotFound, @"Cannot validate -%@, as it takes more than one argument", NSStringFromSelector(action))) {
            return NO;
        }
    }

    NSAssert(name.length, @"Selector %@ is invalid", NSStringFromSelector(action));

    NSMutableString *validationMethodName = [@"validate" mutableCopy];
    [validationMethodName appendString:[[name substringToIndex:1] uppercaseString]];
    [validationMethodName appendString:[name substringFromIndex:1]];

    SEL validationSelector = NSSelectorFromString(validationMethodName);
    NSMethodSignature *methodSignature = [self methodSignatureForSelector:validationSelector];
    if (!methodSignature)
        return NO;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    invocation.selector = validationSelector;
    [invocation invokeWithTarget:self];

    BOOL result = NO;
    [invocation getReturnValue:&result];

    return result;
}

#pragma mark - NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    m_initializingFromArchive = YES;
    @onExit {
        m_initializingFromArchive = NO;
    };

    self = [self init];
    if (!self)
        return nil;

    [self.class enumeratePropertiesUsingBlock:^(objc_property_t property, NSString *key){
        id value = [coder decodeObjectForKey:key];

        if (!value) {
            PROAssert([self.class encodingBehaviorForKey:key] != PROViewModelEncodingBehaviorUnconditional, @"Key \"%@\" of %@ should have been unconditionally encoded, but is not present in the archive", key, self.class);
            return;
        }

        if ([value isEqual:[NSNull null]])
            value = nil;

        [self setValue:value forKey:key];
    }];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [self.class enumeratePropertiesUsingBlock:^(objc_property_t property, NSString *key){
        PROViewModelEncodingBehavior behavior = [self.class encodingBehaviorForKey:key];
        if (behavior == PROViewModelEncodingBehaviorNone)
            return;

        id value = [self valueForKey:key];
        if (behavior == PROViewModelEncodingBehaviorUnconditional) {
            if (!value)
                value = [NSNull null];

            [coder encodeObject:value forKey:key];
        } else if (value) {
            // don't "conditionally" encode nil values
            [coder encodeConditionalObject:value forKey:key];
        }
    }];
}

#pragma mark - NSObject overrides

- (NSString *)description {
    NSMutableString *str = [[NSMutableString alloc] initWithFormat:@"<%@: %p>{", [self class], (__bridge void *)self];

    NSMutableOrderedSet *propertyKeys = [NSMutableOrderedSet orderedSet];
    [self.class enumeratePropertiesUsingBlock:^(objc_property_t property, NSString *key){
        [propertyKeys addObject:key];
    }];

    [propertyKeys sortWithOptions:NSSortConcurrent usingComparator:^(NSString *left, NSString *right){
        return [left caseInsensitiveCompare:right];
    }];

    [propertyKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop){
        if (index != 0)
            [str appendString:@","];

        id value = [self valueForKey:key];
        if ([value isKindOfClass:[PROViewModel class]]) {
            // don't recurse into other PROViewModels
            value = [NSString stringWithFormat:@"<%@: %p>", [value class], value];
        }

        [str appendFormat:@"\n\t\"%@\" = %@", key, value];
    }];

    [str appendString:@"\n}"];
    return str;
}

- (NSUInteger)hash {
    return [self.model hash];
}

- (BOOL)isEqual:(PROViewModel *)viewModel {
    if (self == viewModel)
        return YES;

    if (![viewModel isMemberOfClass:self.class])
        return NO;

    if (!NSEqualObjects(self.model, viewModel.model))
        return NO;

    NSMutableArray *readwriteKeys = [NSMutableArray array];
    [self.class enumeratePropertiesUsingBlock:^(objc_property_t property, NSString *key){
        ext_propertyAttributes *attributes = ext_copyPropertyAttributes(property);
        if (!PROAssert(attributes, @"Could not retrieve attributes for property \"%@\" on %@", key, self.class))
            return;

        @onExit {
            free(attributes);
        };

        if (attributes->readonly)
            return;

        [readwriteKeys addObject:key];
    }];

    NSDictionary *selfValues = [self dictionaryWithValuesForKeys:readwriteKeys];
    NSDictionary *otherValues = [viewModel dictionaryWithValuesForKeys:readwriteKeys];
    return NSEqualObjects(selfValues, otherValues);
}

@end
