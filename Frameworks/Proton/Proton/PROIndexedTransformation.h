//
//  PROIndexedTransformation.h
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes a transformation to be applied to a specific index of an object.
 */
@interface PROIndexedTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to pass through values without modification.
 *
 * Invokes <initWithTransformation:index:> with a `nil` transformation and an
 * index of zero.
 */
- (id)init;

/**
 * Initializes the receiver to transform a value at a given index using the
 * given transformation.
 *
 * This is the designated initializer.
 *
 * @param transformation A <PROTransformation> to apply.
 * @param index The index at which to apply `transformation`.
 */
- (id)initWithTransformation:(PROTransformation *)transformation index:(NSUInteger)index;

/**
 * @name Transformation
 */

/**
 * The transformation performed by the receiver upon the value at
 * <index>.
 *
 * If this value is `nil`, all objects are passed through without modification.
 */
@property (nonatomic, copy, readonly) PROTransformation *transformation;

/**
 * The index associated with the value which will be transformed by the
 * receiver's <transformation>.
 */
@property (nonatomic, readonly) NSUInteger index;

/**
 * Attempts to transform the given array. If the <index> is out of bounds for the given array, `nil` is returned.
 *
 * @param array The array in which to transform the value at <index>.
 */
- (id)transform:(id)array;

@end
