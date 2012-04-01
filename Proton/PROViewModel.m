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
 * An array of <PROBinding> objects that bind the receiver's <model> to the
 * receiver.
 */
@property (nonatomic, strong, readonly) NSMutableArray *modelBindings;

/*
 * Enumerates all the properties of the receiver and any superclasses, up until
 * (and excluding) <PROViewModel>.
 */
+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property))block;
@end

@implementation PROViewModel

#pragma mark Properties

@synthesize model = m_model;
@synthesize observationInfo = m_observationInfo;
@synthesize modelBindings = m_modelBindings;

- (void)setModel:(id)model {
    if (model == m_model)
        return;

    [self removeModelBindings];
    m_model = model;
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithModel:nil];
}

- (id)initWithModel:(id)model; {
    self = [self initWithDictionary:nil];
    if (!self)
        return nil;

    self.model = model;
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary; {
    self = [super init];
    if (!self)
        return nil;

    m_modelBindings = [NSMutableArray array];

    [self setValuesForKeysWithDictionary:dictionary];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self removeAllOwnedObservers];
    [self removeModelBindings];
    [PROBinding removeAllBindingsFromOwner:self];
}

#pragma mark Bindings

- (void)bindKeyPath:(NSString *)ownerKeyPath toModelKeyPath:(NSString *)modelKeyPath withSetup:(void (^)(PROBinding *))setupBlock; {
    NSParameterAssert(ownerKeyPath);
    NSParameterAssert(modelKeyPath);

    if (!self.model)
        return;

    PROBinding *binding = [[PROBinding alloc] initWithOwner:self ownerKeyPath:ownerKeyPath boundObject:self.model boundKeyPath:modelKeyPath];
    if (!PROAssert(binding, @"Could not create binding between key path \"%@\" and model %@ key path \"%@\"", ownerKeyPath, self.model, modelKeyPath))
        return;

    if (setupBlock)
        setupBlock(binding);

    [self.modelBindings addObject:binding];
    [binding boundObjectChanged:self];
}

- (void)removeModelBindings; {
    [self.modelBindings makeObjectsPerformSelector:@selector(unbind)];
    [self.modelBindings removeAllObjects];
}

#pragma mark Reflection

+ (void)enumeratePropertiesUsingBlock:(void (^)(objc_property_t property))block; {
	for (Class cls = self; cls != [PROViewModel class]; cls = [cls superclass]) {
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

+ (NSArray *)propertyKeys {
	NSMutableArray *names = [NSMutableArray array];

	[self enumeratePropertiesUsingBlock:^(objc_property_t property){
		const char *cName = property_getName(property);
		NSString *str = [[NSString alloc] initWithUTF8String:cName];

		[names addObject:str];
	}];

    return names;
}

#pragma mark Dictionary Value

- (NSDictionary *)dictionaryValue {
    return [self dictionaryWithValuesForKeys:[[self class] propertyKeys]];
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSDictionary *dictionaryValue = [coder decodeObjectForKey:PROKeyForObject(self, dictionaryValue)];
    return [self initWithDictionary:dictionaryValue];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.dictionaryValue forKey:PROKeyForObject(self, dictionaryValue)];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PROViewModel *viewModel = [[[self class] allocWithZone:zone] initWithDictionary:self.dictionaryValue];
    viewModel.model = self.model;

    return viewModel;
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
    return [self.model hash];
}

- (BOOL)isEqual:(PROViewModel *)viewModel {
    if (self == viewModel)
        return YES;

    if (![viewModel isKindOfClass:[PROViewModel class]])
        return NO;

    if (!NSEqualObjects(self.model, viewModel.model))
        return NO;

    if (![self.dictionaryValue isEqualToDictionary:viewModel.dictionaryValue])
        return NO;

    return YES;
}

@end
