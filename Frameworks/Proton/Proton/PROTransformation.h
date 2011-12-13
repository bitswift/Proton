//
//  PROTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * An abstract class describing the transformation of an object.
 *
 * The transformations implemented with this class should be pure (i.e., they
 * should have no side effects), so that they can be serialized and reversed.
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
 * @name Reversing the Transformation
 */

/**
 * Returns the reverse transformation of the receiver.
 *
 * The reverse transformation is defined such that
 *
 *  1. Invoking <transform:> on the receiver with an object `obj`
 *  2. Passing the result to the <transform:> method of the reverse transformation
 * 
 * will return an object that compares equal to `obj`.
 */
- (PROTransformation *)reverseTransformation;

@end
