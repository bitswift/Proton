//
//  PROIndexedTransformation.h
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes a transformation to be applied to specific indices of an object.
 */
@interface PROIndexedTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to pass through values without modification.
 *
 * Invokes <initWithTransformations:indexes:> with `nil` objects.
 */
- (id)init;

/**
 * Initializes the receiver to transform the values at the given indices using
 * the given transformations.
 *
 * `transformations` and `indexes` must be of the same size. If both are `nil`
 * or empty, the receiver is initialized to pass through all values without
 * modification.
 *
 * This is the designated initializer.
 *
 * @param transformations A <PROTransformation> to apply for each index specified
 * in `indexes`.
 * @param indexes The indexes at which to apply the corresponding objects in
 * `transformations`.
 */
- (id)initWithTransformations:(NSArray *)transformations indexes:(NSIndexSet *)indexes;

/**
 * @name Transformation
 */

/**
 * The transformations performed by the receiver for each index specified in
 * <indexes>.
 *
 * If this array is empty, all objects are passed through without modification.
 */
@property (nonatomic, copy, readonly) NSArray *transformations;

/**
 * The indexes associated with the values which will be transformed by the
 * receiver's <transformations>.
 *
 * Each index in this set corresponds to one object from <transformations>,
 * which is the transformation to apply at that index.
 *
 * If this index set is `nil`, all objects are passed through without
 * modification.
 */
@property (nonatomic, copy, readonly) NSIndexSet *indexes;

/**
 * Attempts to transform the given array. If <indexes> is out of bounds for the
 * given array, `nil` is returned.
 *
 * @param array The array in which to transform objects.
 */
- (id)transform:(id)array;

@end
