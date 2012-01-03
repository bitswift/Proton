//
//  NSDictionary+HigherOrderAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Higher-order functions for `NSDictionary`.
 */
@interface NSDictionary (HigherOrderAdditions)

/**
 * Filters the keys and values of the receiver with the given predicate,
 * returning a new dictionary built from those entries.
 *
 * @param block A predicate block that determines whether to include or exclude
 * a given key-value pair.
 */
- (NSDictionary *)filterEntriesUsingBlock:(BOOL (^)(id key, id value))block;

/**
 * Filters the keys and values of the receiver with the given predicate,
 * according to the semantics of `opts`, returning a new dictionary built from
 * those entries.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when filtering.
 * @param block A predicate block that determines whether to include or exclude
 * a given key-value pair.
 */
- (NSDictionary *)filterEntriesWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL (^)(id key, id value))block;

/**
 * Reduces the receiver to a single value, using the given block.
 *
 * If the receiver is empty, `startingValue` is returned. Otherwise, the
 * algorithm proceeds as follows:
 *
 *  1. `startingValue` is passed into the block as the `left` value, and the
 *  first key and value of the receiver are passed into the block as `rightKey`
 *  and `rightValue`, respectively.
 *  2. The result of the previous invocation is passed into the block as the
 *  `left` value, and the next key and value of the receiver are passed into the
 *  block as `rightKey` and `rightValue`, respectively.
 *  3. Step 2 is repeated until all elements have been processed.
 *  4. The result of the last call to `block` is returned.
 *
 * @param startingValue The value to be combined with the first entry of the
 * receiver. If the receiver is empty, this is the value returned.
 * @param block A block that describes how to combine elements of the receiver.
 * If the receiver is empty, this block will never be invoked.
 *
 * @warning **Important:** Although this method is structured as a left fold,
 * the algorithm used for `block` must work irrespective of the order that the
 * dictionary's elements are processed, as dictionaries are unordered.
 */
- (id)foldEntriesWithValue:(id)startingValue usingBlock:(id (^)(id left, id rightKey, id rightValue))block;

/**
 * Transforms each value in the receiver with the given predicate, returning
 * a new dictionary built from the original keys and the transformed values.
 *
 * @param block A block with which to transform each value. The key and original
 * value from the receiver are passed in as the arguments.
 *
 * @warning **Important:** It is permissible to return `nil` from `block`, but
 * doing so will omit an entry from the resultant dictionary, such that the
 * number of objects in the result is less than the number of objects in the
 * receiver. If you need the dictionaries to match in size, ensure that the
 * given block returns `NSNull` or `EXTNil` instead of `nil`.
 */
- (NSDictionary *)mapValuesUsingBlock:(id (^)(id key, id value))block;

/**
 * Transforms each value in the receiver with the given predicate, according to
 * the semantics of `opts`, returning a new dictionary built from the original
 * keys and transformed values.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when mapping.
 * @param block A block with which to transform each value. The key and original
 * value from the receiver are passed in as the arguments.
 *
 * @warning **Important:** It is permissible to return `nil` from `block`, but
 * doing so will omit an entry from the resultant dictionary, such that the
 * number of objects in the result is less than the number of objects in the
 * receiver. If you need the dictionaries to match in size, ensure that the
 * given block returns `NSNull` or `EXTNil` instead of `nil`.
 */
- (NSDictionary *)mapValuesWithOptions:(NSEnumerationOptions)opts usingBlock:(id (^)(id key, id value))block;

/**
 * Returns the key of an entry in the receiver that passes the given test, or
 * `nil` if no such entry exists.
 *
 * @param predicate The test to apply to each entry in the receiver. This block
 * should return whether the entry passed the test.
 */
- (id)keyOfEntryPassingTest:(BOOL (^)(id key, id obj, BOOL *stop))predicate;

/**
 * Returns the key of an entry in the receiver that passes the given test, or
 * `nil` if no such entry exists.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when enumerating.
 * @param predicate The test to apply to each entry in the receiver. This block
 * should return whether the entry passed the test.
 */
- (id)keyOfEntryWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id key, id obj, BOOL *stop))predicate;

@end
