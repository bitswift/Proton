//
//  PROFuture.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROFuture.h>
#import <Proton/EXTNil.h>
#import <Proton/EXTScope.h>
#import <objc/runtime.h>

@interface PROFuture () {
    /**
     * A predicate used with `dispatch_once` to synchronize the actual
     * resolution of the future.
     */
    dispatch_once_t m_pred;

    /**
     * The block that will be used to resolve the future, as provided at
     * initialization.
     */
    id (^m_block)(void);
}

/**
 * The object proxied by the future, namespaced to avoid conflicts with message
 * forwarding.
 */
@property (strong) id PROFutureResolvedObject;

@end

@implementation PROFuture

#pragma mark Properties

@synthesize PROFutureResolvedObject = m_PROFutureResolvedObject;

#pragma mark Lifecycle

+ (id)futureWithBlock:(id (^)(void))block; {
    NSParameterAssert(block != nil);

    // NSProxy does not provide an 'init' method, and we don't want to conflict
    // with any message forwarding, so we fill in ivars from here
    PROFuture *future = [PROFuture alloc];
    future->m_block = [block copy];

    return future;
}

- (void)dealloc {
    self.PROFutureResolvedObject = nil;
}

#pragma mark Resolution

+ (id)resolveFuture:(PROFuture *)future; {
    dispatch_once(&future->m_pred, ^{
        id resolvedObject = future->m_block();
        if (!resolvedObject) {
            // convert nil values to EXTNil so that proxying works correctly
            resolvedObject = [EXTNil null];
        }

        future.PROFutureResolvedObject = resolvedObject;

        // we can destroy the block now that the future has been resolved
        future->m_block = nil;
    });

    return future.PROFutureResolvedObject;
}

#pragma mark Forwarding

- (id)forwardingTargetForSelector:(SEL)selector {
    return [PROFuture resolveFuture:self];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [[PROFuture resolveFuture:self] methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:[PROFuture resolveFuture:self]];
}

#pragma mark NSObject protocol

- (Class)class {
    return [[PROFuture resolveFuture:self] class];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol {
    return [[PROFuture resolveFuture:self] conformsToProtocol:protocol];
}

- (NSString *)description {
    id obj = self.PROFutureResolvedObject;

    if (obj)
        return [NSString stringWithFormat:@"<PROFuture: %p object: %@>", (__bridge void *)self, obj];
    else
        return [NSString stringWithFormat:@"<PROFuture: %p (unresolved)>", (__bridge void *)self, obj];
}

- (NSUInteger)hash {
    return [[PROFuture resolveFuture:self] hash];
}

- (BOOL)isEqual:(id)obj {
    // 'self' can be handled without having to resolve the future
    if (obj == self)
        return YES;

    return [[PROFuture resolveFuture:self] isEqual:obj];
}

- (BOOL)isKindOfClass:(Class)class {
    return [[PROFuture resolveFuture:self] isKindOfClass:class];
}

- (BOOL)isMemberOfClass:(Class)class {
    return [[PROFuture resolveFuture:self] isMemberOfClass:class];
}

- (BOOL)respondsToSelector:(SEL)selector {
    // some values can be handled without having to resolve the future
    if (class_respondsToSelector([PROFuture class], selector)) {
        return YES;
    }

    return [[PROFuture resolveFuture:self] respondsToSelector:selector];
}

- (id)self {
    id obj = self.PROFutureResolvedObject;

    // hey, if we're resolved, might as well optimize
    if (obj)
        return obj;
    else
        return self;
}

- (Class)superclass {
    return [[PROFuture resolveFuture:self] superclass];
}

@end
