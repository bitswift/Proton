//
//  PROOrderTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes a transformation to the order of an array.
 */
@interface PROOrderTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to pass through all values without modification.
 *
 * Invokes <initWithStartIndexes:endIndexes:> with `nil` index sets.
 */
- (id)init;

/**
 * Initializes the receiver to move the objects at `startIndexes` to
 * `endIndexes`.
 *
 * The given index sets must match in size. If both index sets are `nil`, the
 * receiver is initialized to pass through all values without modification.
 *
 * This is the designated initializer.
 *
 * @param startIndexes The indexes from which to move objects.
 * @param endIndexes Contains an index corresponding to each start index,
 * indicating where the object from that index should end up.
 */
- (id)initWithStartIndexes:(NSIndexSet *)startIndexes endIndexes:(NSIndexSet *)endIndexes;

/**
 * @name Transformation
 */

/**
 * The indexes from which to move objects.
 */
@property (nonatomic, copy, readonly) NSIndexSet *startIndexes;

/**
 * The indexes to which to move objects.
 *
 * Contains an index corresponding to each index in <startIndexes>, indicating
 * where the object from that index should end up.
 */
@property (nonatomic, copy, readonly) NSIndexSet *endIndexes;

/**
 * Attempts to transform the given array. If the <startIndexes> or <endIndexes>
 * are out of bounds for the given array, `nil` is returned.
 *
 * @param array The array in which to move objects.
 */
- (id)transform:(id)array;

@end
