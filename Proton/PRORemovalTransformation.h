//
//  PRORemovalTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes the removal of objects from an array.
 */
@interface PRORemovalTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to pass through all values without modification.
 *
 * Invokes <initWithRemovalIndexes:expectedObjects:> with `nil` indexes and
 * objects.
 */
- (id)init;

/**
 * Initializes the receiver to remove the given objects from the given indices.
 *
 * `removalIndexes` and `expectedObjects` must be the same size. If `removalIndexes` and
 * `expectedObjects` are both `nil` or empty, the receiver will pass through all values
 * without modification.
 *
 * This is the designated initializer.
 *
 * @param removalIndexes The indices from which to remove the corresponding
 * objects from `expectedObjects`.
 * @param expectedObjects Contains the objects that should exist at each index in
 * `removalIndexes` in order for a removal to occur.
 */
- (id)initWithRemovalIndexes:(NSIndexSet *)removalIndexes expectedObjects:(NSArray *)expectedObjects;

/**
 * Initializes the receiver to remove the given object from the given
 * index.
 *
 * @param index The index from which to remove `object`.
 * @param object The object to remove. This object must exist at `index` for the
 * removal to be considered valid.
 */
- (id)initWithRemovalIndex:(NSUInteger)index expectedObject:(id)object;

/**
 * @name Transformation
 */

/**
 * The indexes from which to remove the corresponding <expectedObjects>.
 *
 * If this property is `nil`, the receiver will pass through all values without
 * modification.
 */
@property (nonatomic, copy, readonly) NSIndexSet *removalIndexes;

/**
 * The objects to remove from the corresponding <removalIndexes>.
 *
 * If this property is `nil`, the receiver will pass through all values without
 * modification.
 */
@property (nonatomic, copy, readonly) NSArray *expectedObjects;

/**
 * Attempts to transform the given array.
 *
 * If the <removalIndexes> are out of bounds for the given array, or any index
 * does not match the associated object in <expectedObjects>, `nil` is returned.
 *
 * Removal is done according to the semantics of `-[NSMutableArray
 * removeObjectsAtIndexes:]`.
 *
 * @param array The array from which to remove <expectedObjects>.
 */
- (id)transform:(id)array;

@end
