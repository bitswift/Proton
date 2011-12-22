//
//  NSObject+KVOAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 22.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSObject+KVOAdditions.h>
#import <Proton/EXTSafeCategory.h>
#import <Proton/EXTScope.h>
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

/*
 * The type for a block that can be invoked when KVO changes occur.
 */
typedef void (^PROKeyValueObserverCallbackBlock)(NSDictionary *);

/*
 * Unique context pointer for KVO, so we can differentiate observers we add from
 * those of others.
 */
static void * const PROKeyValueBlockObserverContext = "PROKeyValueBlockObserverContext";

/*
 * This private class is used as the observer when registering for KVO with
 * a block, since a KVO callback method has to be implemented.
 */
@interface PROKeyValueBlockObserver : NSObject <NSCopying>

/*
 * @name Initialization
 */

/*
 * Registers the receiver to observe the given object and key path, and invoke
 * the given block when a change occurs.
 *
 * @param target The object to observe.
 * @param keyPath The key path, relative to the `target`, to observe for
 * changes.
 * @param options A bitmask of options specifying what should be included in the
 * change dictionary.
 * @param block A block to invoke when a change occurs.
 */
- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(PROKeyValueObserverCallbackBlock)block;

/*
 * @name Observation Properties
 */

/*
 * The block to invoke when a change occurs.
 */
@property (nonatomic, copy, readonly) PROKeyValueObserverCallbackBlock block;

/*
 * The object being observed.
 */
@property (nonatomic, unsafe_unretained, readonly) id target;

/*
 * The key path being observed, relative to the `target`.
 */
@property (nonatomic, copy, readonly) NSString *keyPath;

@end

/*
 * Used to synchronize access to the private `observerLifecycleTracker` property
 * when it is being initially set up.
 */
static OSSpinLock PROObserverLifecycleTrackerLock;

@interface NSObject (KVOAdditionsPrivate)
/*
 * Because all `strong` properties are released on dealloc, we associate all
 * key-value observers with this property, to make sure they get removed and
 * released while the object is still technically live.
 */
@property (nonatomic, strong) id observerLifecycleTracker;
@end

@safecategory (NSObject, KVOAdditions)

- (id)observerLifecycleTracker {
    return objc_getAssociatedObject(self, @selector(observerLifecycleTracker));
}

- (void)setObserverLifecycleTracker:(id)obj {
    objc_setAssociatedObject(self, @selector(observerLifecycleTracker), obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)addObserverForKeyPath:(NSString *)keyPath usingBlock:(PROKeyValueObserverCallbackBlock)block; {
    return [self addObserverForKeyPath:keyPath options:0 usingBlock:block];
}

- (id)addObserverForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options usingBlock:(PROKeyValueObserverCallbackBlock)block; {
    NSParameterAssert(keyPath != nil);
    NSParameterAssert(block != nil);

    id observer = [[PROKeyValueBlockObserver alloc] initWithTarget:self keyPath:keyPath options:options block:block];
    if (!observer)
        return nil;

    // make sure the target has a "lifecycle tracker" set up (see above)
    //
    // this spin lock isn't actually specific to this one object, but
    // contention should be low enough to where it's not an issue
    OSSpinLockLock(&PROObserverLifecycleTrackerLock);

    id lifecycleTracker = self.observerLifecycleTracker;
    if (!lifecycleTracker)
        self.observerLifecycleTracker = lifecycleTracker = [[NSObject alloc] init];

    OSSpinLockUnlock(&PROObserverLifecycleTrackerLock);

    // retain the observer for the lifetime of the lifecycle tracker (using the
    // pointer to the observer as a unique key for associated objects)
    //
    // if the observer is later removed from the target using any of the
    // -removeObserver:… methods, it will still be retained -- the object is
    // lightweight enough that this shouldn't be an issue in practice, but it's
    // something to keep an eye on
    objc_setAssociatedObject(lifecycleTracker, (__bridge void *)observer, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return observer;
}

@end

@implementation PROKeyValueBlockObserver

#pragma mark Properties

@synthesize block = m_block;
@synthesize target = m_target;
@synthesize keyPath = m_keyPath;

#pragma mark Lifecycle

- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(PROKeyValueObserverCallbackBlock)block; {
    NSParameterAssert(target != nil);
    NSParameterAssert(keyPath != nil);
    NSParameterAssert(block != nil);

    self = [super init];
    if (!self)
        return nil;

    m_target = target;
    m_keyPath = [keyPath copy];
    m_block = [block copy];

    // IMPORTANT: we never explicitly de-register for notifications, since (by
    // our implementation above) this object will exist just past the lifetime
    // of 'target', and because the caller may remove us explicitly first
    [self.target addObserver:self forKeyPath:self.keyPath options:options context:PROKeyValueBlockObserverContext];

    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != PROKeyValueBlockObserverContext) {
        // must've come from a superclass
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    NSAssert([keyPath isEqualToString:self.keyPath], @"%@ should not be receiving changes for a key path other than its own", self);
    NSAssert(object == self.target, @"%@ should not be receiving changes for an object other than its own", self);

    self.block(change);
}

@end
