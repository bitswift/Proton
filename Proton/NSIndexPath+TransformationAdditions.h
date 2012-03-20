//
//  NSIndexPath+TransformationAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 19.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSIndexPath` that add additional ways to transform and modify paths.
 */
@interface NSIndexPath (TransformationAdditions)

/**
 * @name Modifying the Beginning of an Index Path
 */

/**
 * Returns a new index path beginning with `index`, followed by the indexes in
 * the receiver.
 *
 * @param index The first index for the new path.
 */
- (NSIndexPath *)indexPathByPrependingIndex:(NSUInteger)index;

/**
 * Returns a new index path with the indexes of the receiver, excluding the
 * first one.
 *
 * If the receiver has one index or less, this method returns an empty index
 * path.
 */
- (NSIndexPath *)indexPathByRemovingFirstIndex;

@end
