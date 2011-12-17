//
//  PROMultipleTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes multiple transformations that are applied atomically.
 */
@interface PROMultipleTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver without any transformations.
 */
- (id)init;

/**
 * Initializes the receiver to perform the given transformations.
 *
 * This is the designated initializer for this class.
 *
 * @param transformations An ordered list of transformations to apply to any
 * object given to <transform:>.
 */
- (id)initWithTransformations:(NSArray *)transformations;

/**
 * @name Transformation
 */

/**
 * The transformations performed by the receiver, in order.
 */
@property (nonatomic, copy, readonly) NSArray *transformations;

/**
 * Attempts to transform the given object.
 *
 * For each object in the <transformations> array, applies its transformation to
 * the result of the previous transformation (or, if the first transformation,
 * it is applied to `obj`), returning the result of the last transformation. If
 * any transformation in the array returns `nil`, this method immediately
 * returns `nil`.
 *
 * If the <transformations> array is empty, `obj` is passed through without
 * modification.
 *
 * @param obj The object to attempt to transform. This value should not be
 * `nil`.
 */
- (id)transform:(id)obj;

@end
