//
//  NSObject+PROKeyValueObserverAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSObject+PROKeyValueObserverAdditions.h>
#import <Proton/EXTSafeCategory.h>
#import <Proton/EXTScope.h>
#import <libkern/OSAtomic.h>

/*
 * A global spin lock used to synchronize the `ownedKeyValueObserversLock`
 * associated with each object.
 *
 * In other words, this lock is shared by all objects in order to set up
 * individual locks for each one.
 */
static OSSpinLock PROAssociatedKeyValueObserversLockLock;

@interface NSObject (PROKeyValueObserverAdditionsPrivate)
/*
 * A lock which synchronizes access to and mutation of the
 * <ownedKeyValueObservers> array.
 *
 * Accessing this property will atomically create a lock if one does not already
 * exist. This property should only ever be set to `nil` (never to a custom
 * lock).
 */
@property (strong) NSLock *ownedKeyValueObserversLock;

/*
 * An array containing the <PROKeyValueObserver> instances that are owned by the
 * receiver.
 * 
 * The creation of, accesses to, and mutations of this array should be
 * synchronized with the <ownedKeyValueObserversLock>.
 */
@property (nonatomic, strong) NSMutableArray *ownedKeyValueObservers;
@end

@safecategory (NSObject, PROKeyValueObserverAdditions)
- (NSLock *)ownedKeyValueObserversLock {
    // use the selector as a key (since it's unique)
    void * const associatedObjectKey = @selector(ownedKeyValueObserversLock);

    // since the association is atomic, we can try retrieving any existing lock
    // without first obtaining the spin lock (only locking if we need to
    // exclusively create one)
    NSLock *lock = objc_getAssociatedObject(self, associatedObjectKey);

    if (!lock) {
        OSSpinLockLock(&PROAssociatedKeyValueObserversLockLock);

        @onExit {
            OSSpinLockUnlock(&PROAssociatedKeyValueObserversLockLock);
        };

        // try retrieving it again -- another thread might've set one up while
        // we were blocked on the spin lock
        lock = objc_getAssociatedObject(self, associatedObjectKey);

        if (!lock) {
            lock = [[NSLock alloc] init];
            
            // associate the lock atomically, so threads don't have to wait on
            // the spin lock just to retrieve this object
            objc_setAssociatedObject(self, associatedObjectKey, lock, OBJC_ASSOCIATION_RETAIN);
        }
    }

    return lock;
}

- (void)setOwnedKeyValueObserversLock:(NSLock *)lock {
    NSParameterAssert(!lock);

    // since the association is atomic, we can just set 'nil' without
    // obtaining the spin lock
    objc_setAssociatedObject(self, @selector(ownedKeyValueObserversLock), nil, OBJC_ASSOCIATION_RETAIN);
}

- (NSMutableArray *)ownedKeyValueObservers {
    // we can assert on -tryLock because the lock is non-recursive (i.e., this
    // thread cannot obtain it more than once)
    NSAssert(![self.ownedKeyValueObserversLock tryLock], @"ownedKeyValueObserversLock should be held before attempting to use %s", __func__);

    // use the selector for this getter as a unique key
    return objc_getAssociatedObject(self, @selector(ownedKeyValueObservers));
}

- (void)setOwnedKeyValueObservers:(NSMutableArray *)array {
    // we can assert on -tryLock because the lock is non-recursive (i.e., this
    // thread cannot obtain it more than once)
    NSAssert(![self.ownedKeyValueObserversLock tryLock], @"ownedKeyValueObserversLock should be held before attempting to use %s", __func__);

    // this association is nonatomic because all operations on the array should
    // already be synchronized with our lock
    objc_setAssociatedObject(self, @selector(ownedKeyValueObservers), array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (PROKeyValueObserver *)addObserverOwnedByObject:(NSObject *)owner forKeyPath:(NSString *)keyPath usingBlock:(PROKeyValueObserverBlock)block; {
    return [self addObserverOwnedByObject:owner forKeyPath:keyPath options:0 usingBlock:block];
}

- (PROKeyValueObserver *)addObserverOwnedByObject:(NSObject *)owner forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options usingBlock:(PROKeyValueObserverBlock)block; {
    PROKeyValueObserver *observer = [[PROKeyValueObserver alloc] initWithTarget:self keyPath:keyPath options:options block:block];
    if (!observer)
        return nil;

    {
        NSLock *observersLock = owner.ownedKeyValueObserversLock;

        [observersLock lock];
        @onExit {
            [observersLock unlock];
        };

        // store the observer in an array associated with the owner, so we can later
        // remove it
        NSMutableArray *ownedObservers = owner.ownedKeyValueObservers;
        if (!ownedObservers)
            owner.ownedKeyValueObservers = ownedObservers = [[NSMutableArray alloc] init];

        [ownedObservers addObject:observer];
    }

    return observer;
}

- (void)removeAllOwnedObservers; {
    NSLock *observersLock = self.ownedKeyValueObserversLock;

    [observersLock lock];
    @onExit {
        // we can also destroy the lock now that we've removed all observers
        self.ownedKeyValueObserversLock = nil;
        [observersLock unlock];
    };

    // destroy the whole array
    self.ownedKeyValueObservers = nil;
}

- (void)removeOwnedObserver:(PROKeyValueObserver *)observer; {
    NSLock *observersLock = self.ownedKeyValueObserversLock;

    [observersLock lock];
    @onExit {
        [observersLock unlock];
    };

    NSMutableArray *ownedObservers = self.ownedKeyValueObservers;
    [ownedObservers removeObjectIdenticalTo:observer];
}

@end
