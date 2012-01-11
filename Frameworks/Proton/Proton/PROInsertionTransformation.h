//
//  PROInsertionTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes the insertion of objects into an array.
 */
@interface PROInsertionTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to pass through all values without modification.
 *
 * Invokes <initWithInsertionIndexes:objects:> with `nil` indexes and objects.
 */
- (id)init;

/**
 * Initializes the receiver to insert the given objects at the given indices.
 *
 * `insertionIndexes` and `objects` must be the same size. If `insertionIndexes`
 * and `objects` are both `nil` or empty, the receiver will pass through all
 * values without modification.
 *
 * This is the designated initializer.
 *
 * @param insertionIndexes The indices at which to insert the corresponding
 * objects from `objects`.
 * @param objects Contains an object to be inserted for each index in
 * `insertionIndexes`.
 */
- (id)initWithInsertionIndexes:(NSIndexSet *)insertionIndexes objects:(NSArray *)objects;

/**
 * Initializaes the receiver to insert the given object at the given index.
 *
 * If `object` is `nil`, the receiver will pass through all values without
 * modification.
 *
 * @param index The index at which to insert the corresponding `object`.
 * @param object An object to be inserted at the corresponding `index`.
 */
- (id)initWithInsertionIndex:(NSUInteger)index object:(id)object;

/**
 * @name Transformation
 */

/**
 * The indexes at which to insert the corresponding <objects>.
 *
 * If this property is `nil`, the receiver will pass through all values without
 * modification.
 */
@property (nonatomic, copy, readonly) NSIndexSet *insertionIndexes;

/**
 * The objects to insert at the corresponding <insertionIndexes>.
 *
 * If this property is `nil`, the receiver will pass through all values without
 * modification.
 */
@property (nonatomic, copy, readonly) NSArray *objects;

/**
 * Attempts to transform the given array. If the <insertionIndexes> are out of
 * bounds for the given array, `nil` is returned.
 *
 * Insertion is done according to the semantics of `-[NSMutableArray
 * insertObjects:atIndexes:]`.
 *
 * @param array The array in which to insert objects.
 */
- (id)transform:(id)array;

@end
