//
//  PROKeyValueCodingProxy.m
//  Proton
//
//  Created by Justin Spahr-Summers on 03.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROKeyValueCodingProxy.h"

@interface PROKeyValueCodingProxy ()
@property (nonatomic, copy, readwrite) NSString *keyPath;
@end

@implementation PROKeyValueCodingProxy

#pragma mark Properties

@synthesize keyPath = m_keyPath;
@synthesize setValueForKeyPathBlock = m_setValueForKeyPathBlock;
@synthesize valueForKeyPathBlock = m_valueForKeyPathBlock;
@synthesize mutableArrayValueForKeyPathBlock = m_mutableArrayValueForKeyPathBlock;

#pragma mark Initialization

- (id)init; {
    return [self initWithKeyPath:nil];
}

- (id)initWithKeyPath:(NSString *)keyPath; {
    self = [super init];
    if (!self)
        return nil;

    self.keyPath = keyPath;
    return self;
}

#pragma mark Nested Proxies

- (PROKeyValueCodingProxy *)proxyForKeyPath:(NSString *)keyPath; {
    PROKeyValueCodingProxy *proxy = [[[self class] alloc] initWithKeyPath:keyPath];

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
        return self.mutableArrayValueForKeyPathBlock(keyPath);
    else
        return [super mutableArrayValueForKeyPath:keyPath];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [self setValue:value forKeyPath:key];
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
    if (self.setValueForKeyPathBlock)
        self.setValueForKeyPathBlock(value, keyPath);
    else
        [super setValue:value forKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    return [self valueForKeyPath:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if (self.valueForKeyPathBlock)
        return self.valueForKeyPathBlock(keyPath);
    else
        return [super valueForKeyPath:keyPath];
}

@end
