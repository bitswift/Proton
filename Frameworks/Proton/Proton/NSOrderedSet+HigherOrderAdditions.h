//
//  NSOrderedSet+HigherOrderAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Higher-order functions for `NSOrderedSet`.
 */
@interface NSOrderedSet (HigherOrderAdditions)

/**
 * Filters the objects of the receiver with the given predicate, returning a new
 * ordered set built from those objects.
 *
 * @param block A predicate block that determines whether to include or exclude
 * a given object.
 */
- (id)filterUsingBlock:(BOOL (^)(id obj))block;

/**
 * Filters the objects of the receiver with the given predicate, according to
 * the semantics of `opts`, returning a new ordered set built from those
 * objects.
 *
 * @param opts A mask of `NSEnumerationOptions` to apply when filtering.
 * @param block A predicate block that determines whether to include or exclude
 * a given object.
 */
- (id)filterWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL (^)(id obj))block;

@end
