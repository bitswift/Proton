//
//  PROTransformationProtected.h
//  Proton
//
//  Created by Justin Spahr-Summers on 18.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformation.h"

/**
 * Methods that can be overridden by <PROTransformation> subclasses, but that
 * should not be exposed to callers.
 */
@interface PROTransformation (Protected)

/**
 * @name Coalescing Transformations
 */

/**
 * Attempts to coalesce the receiver with the given transformation, returning
 * a single, more compact transformation that has the same effect as performing
 * both in sequence. Returns `nil` if coalescing is not possible.
 *
 * The returned transformation should be equivalent to applying the receiver,
 * then applying `transformation`.
 *
 * The default implementation returns `nil`.
 *
 * @param transformation A transformation that the receiver should coalesce
 * with.
 */
- (PROTransformation *)coalesceWithTransformation:(PROTransformation *)transformation;

@end
