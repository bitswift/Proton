//
//  PROTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROTransformation;

/**
 * A block that can perform a transformation and return the result.
 *
 * @param obj The input value, to be transformed into something else.
 */
typedef id (^PROTransformationBlock)(id obj);

/**
 * A block that can rewrite the logic of a <PROTransformation> on the fly.
 *
 * See <[PROTransformation transformationBlockUsingRewriterBlock:]> for more
 * information.
 *
 * @param transformation The transformation currently being rewritten.
 * @param transformationBlock The original logic of the transformation. If given
 * `obj` as an input, this will return the value that the transformation would
 * have returned without rewriting.
 * @param obj The input value, to be transformed into something else.
 */
typedef id (^PROTransformationRewriterBlock)(PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj);

/**
 * An abstract class describing the transformation of an object.
 *
 * The transformations implemented with this class should be pure (i.e., they
 * should have no side effects), so that they can be serialized and reversed.
 *
 * @warning **Important:** Subclasses should not attempt to invoke this class'
 * implementation of `NSCoding`. Implement the methods directly instead.
 */
@interface PROTransformation : NSObject <NSCoding, NSCopying>

/**
 * @name Transformation
 */

/**
 * Attempts to transform the given object.
 *
 * If no transformation is possible, or the object is invalid, `nil` is
 * returned. To describe a transformation that should return `nil`, return
 * `EXTNil` or `NSNull` instead.
 *
 * @param obj The object to attempt to transform. This value should not be
 * `nil`.
 */
- (id)transform:(id)obj;

/**
 * Returns a block that combines the logic of the receiver with that of the
 * given block.
 *
 * This can be used to "rewrite" the logic of a transformation by adding side
 * effects, or by intercepting input and/or output values.
 *
 * For the receiver, and any sub-transformations that the receiver has, `block`
 * will be invoked with the following arguments:
 *
 *  - The transformation currently being rewritten (starting with the receiver).
 *  - A block containing the original logic of the receiver. This block is meant
 *  to be invoked to perform the actual work of the transformation, but does not
 *  necessarily have to be called.
 *  - The input value for the current transformation.
 *
 * `block` should return the desired output value for the transformation at each
 * level. If it returns `nil`, the returned transformation block immediately
 * returns `nil` at that point.
 *
 * @param block The block with which to rewrite the logic of the receiver. See
 * the documentation for `PROTransformationRewriterBlock`.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
- (PROTransformationBlock)transformationBlockUsingRewriterBlock:(PROTransformationRewriterBlock)block;

/**
 * @name Reversing the Transformation
 */

/**
 * The reverse transformation of the receiver.
 *
 * The reverse transformation is defined such that
 *
 *  1. Invoking <transform:> on the receiver with an object `obj`
 *  2. Passing the result to the <transform:> method of the reverse transformation
 * 
 * will return an object that compares equal to `obj`.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
@property (nonatomic, strong, readonly) PROTransformation *reverseTransformation;

@end
