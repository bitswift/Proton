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

@end
