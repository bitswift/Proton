//
//  NSObject+KeyValueCodingAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 02.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSObject` that provide new key-value coding behaviors.
 */
@interface NSObject (KeyValueCodingAdditions)

/**
 * Applies a set of KVO changes to a to-many property, optionally transforming any
 * new values that have been added.
 *
 * This method will inspect the given dictionary of key-value observing changes
 * and attempt to apply the same changes to the collection at the given key
 * path. If the changes involve setting a new collection, or inserting or
 * replacing objects in the collection, the given block will be invoked to
 * transform the values before they're added to the collection at `keyPath`.
 *
 * The `changes` dictionary must contain the following keys:
 *
 *  - `NSKeyValueChangeNewKey` if the change is not a removal.
 *  - `NSKeyValueChangeOldKey` if the change is to an unordered collection, and
 *  is not `NSKeyValueChangeSetting`.
 *  - `NSKeyValueChangeIndexesKey` if the change is to an ordered collection,
 *  and is not `NSKeyValueChangeSetting`.
 *
 * @param changes A change dictionary that was passed to
 * `observeValueForKeyPath:ofObject:change:context:` or a <[PROKeyValueObserver
 * block]>.
 * @param keyPath A key path, relative to the receiver, at which to apply the
 * changes. The property at this key path must hold a KVC-compliant collection
 * (either ordered or unordered).
 * @param block If not `nil`, this block will be invoked before inserting any
 * new objects into the collection at `keyPath`. The block will be passed the
 * object that was added in the original changes, and should return an object to
 * add to the collection at `keyPath`. This block must not return `nil`.
 *
 * @warning **Important:** The collection at `keyPath` must be the same length
 * as the original collection (i.e., the collection before it was mutated and
 * generated a KVO notification), and must be the same length as the new
 * collection when this method completes.
 */
- (void)applyKeyValueChangeDictionary:(NSDictionary *)changes toKeyPath:(NSString *)keyPath mappingNewObjectsUsingBlock:(id (^)(id))block;

@end
