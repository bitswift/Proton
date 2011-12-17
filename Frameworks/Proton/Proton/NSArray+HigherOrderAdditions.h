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

@end
