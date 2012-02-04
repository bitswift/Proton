//
//  PROKeyValueCodingProxy.m
//  Proton
//
//  Created by Justin Spahr-Summers on 03.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROKeyValueCodingProxy.h"
#import "EXTNil.h"

@interface PROKeyValueCodingProxy ()
@property (nonatomic, copy, readwrite) NSString *proxiedKeyPath;
@property (nonatomic, strong, readwrite) id proxiedObject;
@end

@implementation PROKeyValueCodingProxy

#pragma mark Properties

@synthesize proxiedKeyPath = m_proxiedKeyPath;
@synthesize proxiedObject = m_proxiedObject;
@synthesize setValueForKeyPathBlock = m_setValueForKeyPathBlock;
@synthesize valueForKeyPathBlock = m_valueForKeyPathBlock;
@synthesize mutableArrayValueForKeyPathBlock = m_mutableArrayValueForKeyPathBlock;

#pragma mark Initialization

- (id)init {
    return [self initWithProxiedObject:[EXTNil null]];
}

- (id)initWithProxiedObject:(id)object; {
    return [self initWithProxiedObject:object keyPath:nil];
}

- (id)initWithProxiedObject:(id)object keyPath:(NSString *)keyPath; {
    NSParameterAssert(object != nil);

    self = [super init];
    if (!self)
        return nil;

    self.proxiedObject = object;
    self.proxiedKeyPath = keyPath;
    return self;
}

#pragma mark Nested Proxies

- (PROKeyValueCodingProxy *)proxyWithObject:(id)object keyPath:(NSString *)keyPath; {
    PROKeyValueCodingProxy *proxy = [[[self class] alloc] initWithProxiedObject:object keyPath:keyPath];

    proxy.setValueForKeyPathBlock = self.setValueForKeyPathBlock;
    proxy.valueForKeyPathBlock = self.valueForKeyPathBlock;
    proxy.mutableArrayValueForKeyPathBlock = self.mutableArrayValueForKeyPathBlock;

    return proxy;
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

- (NSMutableArray *)mutableArrayValueForKey:(NSString *)key {
    return [self mutableArrayValueForKeyPath:key];
}

- (NSMutableArray *)mutableArrayValueForKeyPath:(NSString *)keyPath {
    if (self.mutableArrayValueForKeyPathBlock)
        return self.mutableArrayValueForKeyPathBlock(self, keyPath);
    else
        return [super mutableArrayValueForKeyPath:keyPath];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [self setValue:value forKeyPath:key];
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
    if (self.setValueForKeyPathBlock)
        self.setValueForKeyPathBlock(self, value, keyPath);
    else
        [super setValue:value forKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    return [self valueForKeyPath:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if (self.valueForKeyPathBlock)
        return self.valueForKeyPathBlock(self, keyPath);
    else
        return [super valueForKeyPath:keyPath];
}

#pragma mark Forwarding

- (id)forwardingTargetForSelector:(SEL)selector {
    return self.proxiedObject;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.proxiedObject];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [[self class] instanceMethodSignatureForSelector:selector];
    if (signature)
        return signature;

    return [self.proxiedObject methodSignatureForSelector:selector];
}

- (BOOL)respondsToSelector:(SEL)selector {
    if ([[self class] instancesRespondToSelector:selector])
        return YES;

    return [self.proxiedObject respondsToSelector:selector];
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p object: %@>", [self class], (__bridge void *)self, self.proxiedObject];
}

- (NSUInteger)hash {
    return [self.proxiedObject hash];
}

- (BOOL)isEqual:(id)obj {
    if (self == obj)
        return YES;

    return [self.proxiedObject isEqual:obj];
}

- (BOOL)isProxy {
    return YES;
}

@end
