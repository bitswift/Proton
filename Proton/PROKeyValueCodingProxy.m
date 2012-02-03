//
//  PROKeyValueCodingProxy.m
//  Proton
//
//  Created by Justin Spahr-Summers on 03.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROKeyValueCodingProxy.h"

@implementation PROKeyValueCodingProxy

#pragma mark Properties

@synthesize keyPath = m_keyPath;
@synthesize setValueForKeyPathBlock = m_setValueForKeyPathBlock;
@synthesize valueForKeyPathBlock = m_valueForKeyPathBlock;
@synthesize mutableArrayValueForKeyPathBlock = m_mutableArrayValueForKeyPathBlock;

#pragma mark Initialization

- (id)init; {
    return nil;
}

- (id)initWithKeyPath:(NSString *)keyPath; {
    return nil;
}

#pragma mark Nested Proxies

- (PROKeyValueCodingProxy *)proxyForKeyPath:(NSString *)keyPath; {
    return nil;
}

#pragma mark NSKeyValueCoding

#pragma mark NSObject overrides

@end
