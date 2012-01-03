//
//  NSArray+HigherOrderAdditions.h
//  Proton
//
//  Created by Josh Vera on 12/7/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Higher-order functions for `NSArray`.
 */
@interface NSArray (HigherOrderAdditions)

/**
 * Returns an array of filtered objects for which `block` returns true.
 *
 * @param block A predicate block that determines whether to include or exclude
 * a given object.
 */
- (id)filterUsingBlock:(BOOL(^)(id obj))block;

/**
 * Returns an array of filtered objects for which `block` returns true, applying `opts` while filtering.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when filtering.
 * @param block A predicate block that determines whether to include or exclude
 * a given object.
 */
- (id)filterWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL(^)(id obj))block;

/**
 * Reduces the receiver to a single value from left to right, using the given
 * block.
 *
 * If the receiver is empty, `startingValue` is returned. Otherwise, the
 * algorithm proceeds as follows:
 *
 *  1. `startingValue` is passed into the block as the `left` value, and the
 *  first element of the receiver is passed into the block as the `right` value.
 *  2. The result of the previous invocation (`left`) and the next element of
 *  the receiver (`right`) is passed into `block`.
 *  3. Step 2 is repeated until all elements have been processed.
 *  4. The result of the last call to `block` is returned.
 *
 * @param startingValue The value to be combined with the first element of the
 * receiver. If the receiver is empty, this is the value returned.
 * @param block A block that describes how to combine elements of the receiver.
 * If the receiver is empty, this block will never be invoked.
 */
- (id)foldLeftWithValue:(id)startingValue usingBlock:(id (^)(id left, id right))block;

/**
 * Reduces the receiver to a single value from right to left, using the given
 * block.
 *
 * If the receiver is empty, `startingValue` is returned. Otherwise, the
 * algorithm proceeds as follows:
 *
 *  1. The last element of the receiver is passed into the block as the `left`
 *  value, and `startingValue` is passed into the block as the `right` value.
 *  2. The previous element of the receiver (`left`) and the result of the
 *  previous invocation (`right`) is passed into `block`.
 *  3. Step 2 is repeated until all elements have been processed.
 *  4. The result of the last call to `block` is returned.
 *
 * @param startingValue The value to be combined with the last element of the
 * receiver. If the receiver is empty, this is the value returned.
 * @param block A block that describes how to combine elements of the receiver.
 * If the receiver is empty, this block will never be invoked.
 */
- (id)foldRightWithValue:(id)startingValue usingBlock:(id (^)(id left, id right))block;

/**
 * Transforms each object in the receiver with the given predicate, returning
 * a new array built from the resulting objects.
 *
 * @param block A block with which to transform each element. The element from
 * the receiver is passed in as the `obj` argument.
 *
 * @warning **Important:** It is permissible to return `nil` from `block`, but
 * doing so will omit an entry from the resultant array, such that the number of
 * objects in the result is less than the number of objects in the receiver. If
 * you need the arrays to match in size, ensure that the given block returns
 * `NSNull` or `EXTNil` instead of `nil`.
 */
- (id)mapUsingBlock:(id (^)(id obj))block;

/**
 * Transforms each object in the receiver with the given predicate, according to
 * the semantics of `opts`, returning a new array built from the resulting
 * objects.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when mapping.
 * @param block A block with which to transform each element. The element from
 * the receiver is passed in as the `obj` argument.
 *
 * @warning **Important:** It is permissible to return `nil` from `block`, but
 * doing so will omit an entry from the resultant array, such that the number of
 * objects in the result is less than the number of objects in the receiver. If
 * you need the arrays to match in size, ensure that the given block returns
 * `NSNull` or `EXTNil` instead of `nil`.
 */
- (id)mapWithOptions:(NSEnumerationOptions)opts usingBlock:(id (^)(id obj))block;

/**
 * Returns the first object in the receiver that passes the given test, or `nil`
 * if no such object exists.
 *
 * @param predicate The test to apply to each element in the receiver. This block
 * should return whether the object passed the test.
 */
- (id)objectPassingTest:(BOOL (^)(id obj, NSUInteger index, BOOL *stop))predicate;

/**
 * Returns the first object in the receiver that passes the given test, or `nil`
 * if no such object exists.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when enumerating.
 * @param predicate The test to apply to each element in the receiver. This block
 * should return whether the object passed the test.
 */
- (id)objectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id obj, NSUInteger index, BOOL *stop))predicate;

@end
