//
//  NSObject+KVOAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 22.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSObject` to support key-value observing using blocks.
 */
@interface NSObject (KVOAdditions)
/**
 * Invokes <addObserverForKeyPath:options:usingBlock:> without any options.
 *
 * @param keyPath The key path, relative to the receiver, to observe for
 * changes.
 * @param block A block to invoke when a change occurs. The block will be passed
 * a standard KVO change dictionary.
 */
- (id)addObserverForKeyPath:(NSString *)keyPath usingBlock:(void (^)(NSDictionary *changes))block;

/**
 * Begins observing the given key path relative to the receiver, invoking the
 * given block when a change occurs. Returns an opaque object that can later be
 * passed to `removeObserver:forKeyPath:`.
 *
 * The returned object will be automatically released when the receiver is
 * destroyed.
 *
 * @param keyPath The key path, relative to the receiver, to observe for
 * changes.
 * @param options A bitmask of options specifying what should be included in the
 * change dictionary.
 * @param block A block to invoke when a change occurs. The block will be passed
 * a standard KVO change dictionary.
 */
- (id)addObserverForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options usingBlock:(void (^)(NSDictionary *changes))block;
@end
