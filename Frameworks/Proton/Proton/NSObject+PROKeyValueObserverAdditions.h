//
//  NSObject+PROKeyValueObserverAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/PROKeyValueObserver.h>

/**
 * Extends `NSObject` with conveniences that make it easier to use
 * <PROKeyValueObserver>.
 *
 * These extensions are thread-safe.
 */
@interface NSObject (PROKeyValueObserverAdditions)
/**
 * Invokes <addObserverOwnedByObject:forKeyPath:options:usingBlock:> without any
 * options.
 *
 * @param owner The object which will "own" the observer.
 * @param keyPath The key path to observe, relative to the receiver.
 * @param block A block to invoke when a change occurs.
 *
 * @warning **Important:** The observer must still be destroyed before the
 * receiver (per the contract of `<NSKeyValueObserving>`). This means that one
 * of the following must happen:
 *
 *  - `owner` must be deallocated before the observed object (the receiver).
 *  - <removeOwnedObserver:> is invoked on `owner` with the returned observer.
 *  - <removeOwnedObservers> is invoked on `owner`.
 */
- (PROKeyValueObserver *)addObserverOwnedByObject:(NSObject *)owner forKeyPath:(NSString *)keyPath usingBlock:(PROKeyValueObserverBlock)block;

/**
 * Creates and returns a <PROKeyValueObserver> observing the receiver, with
 * a lifecycle tied to that of the given object.
 *
 * In other words, the returned object is not destroyed until `owner` is
 * destroyed, or until <removeOwnedObserver:> or <removeOwnedObservers> is
 * invoked on `owner`.
 *
 * @param owner The object which will "own" the observer.
 * @param keyPath The key path to observe, relative to the receiver.
 * @param options A bitmask of options controlling the information that will be
 * provided in the KVO change dictionary.
 * @param block A block to invoke when a change occurs.
 *
 * @warning **Important:** The observer must still be destroyed before the
 * receiver (per the contract of `<NSKeyValueObserving>`). This means that one
 * of the following must happen:
 *
 *  - `owner` must be deallocated before the observed object (the receiver).
 *  - <removeOwnedObserver:> is invoked on `owner` with the returned observer.
 *  - <removeOwnedObservers> is invoked on `owner`.
 */
- (PROKeyValueObserver *)addObserverOwnedByObject:(NSObject *)owner forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options usingBlock:(PROKeyValueObserverBlock)block;

/**
 * Removes all observers which were previously associated with the receiver
 * using <addObserverOwnedByObject:forKeyPath:options:usingBlock:>.
 *
 * This method would typically be invoked from `dealloc` or a similar teardown
 * method.
 *
 * @warning This method is for observers _owned by_ the receiver (see
 * <addObserverOwnedByObject:forKeyPath:options:usingBlock:>), not objects
 * _observing_ the receiver.
 */
- (void)removeAllOwnedObservers;

/**
 * Removes an observer which was previously associated with the receiver using
 * <addObserverOwnedByObject:forKeyPath:options:usingBlock:>.
 *
 * @param observer An observer owned by the receiver.
 *
 * @warning This method is for observers _owned by_ the receiver (see
 * <addObserverOwnedByObject:forKeyPath:options:usingBlock:>), not objects
 * _observing_ the receiver.
 */
- (void)removeOwnedObserver:(PROKeyValueObserver *)observer;
@end
