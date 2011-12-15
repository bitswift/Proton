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

@end
