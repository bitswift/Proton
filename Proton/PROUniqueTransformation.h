//
//  PROUniqueTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes the transformation of a specific object to another specific object.
 */
@interface PROUniqueTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to pass through values without modification.
 *
 * Invokes <initWithInputValue:outputValue:> with `nil` arguments.
 */
- (id)init;

/**
 * Initializes the receiver to transform the given input value into the given
 * output value.
 *
 * If the `inputValue` and `outputValue` are _both_ `nil`, the transformer will
 * be initialized to pass all values through without modification. If either
 * argument is `nil` but the other is not, the `nil` argument is silently
 * converted to `NSNull` to form a valid transformation.
 *
 * This is the designated initializer for this class.
 *
 * @param inputValue The only object considered valid by <transform:>. This
 * argument is copied.
 * @param outputValue The value to return from <transform:> when the
 * `inputValue` is given. This argument is copied.
 */
- (id)initWithInputValue:(id<NSCoding, NSCopying>)inputValue outputValue:(id<NSCoding, NSCopying>)outputValue;

/**
 * @name Input and Output Values
 */

/**
 * The only object considered valid by <transform:>.
 *
 * If this value is `nil`, all objects are considered valid, and are simply
 * passed through <transform:> without modification.
 */
@property (nonatomic, copy, readonly) id inputValue;

/**
 * The object returned from <transform:> when the <inputValue> is given.
 *
 * If this value is `nil`, all objects are considered valid, and are simply
 * passed through <transform:> without modification.
 */
@property (nonatomic, copy, readonly) id outputValue;

/**
 * @name Transformation
 */

/**
 * Attempts to transform the given object.
 *
 * If the given object compares equal to the <inputValue>, returns the
 * <outputValue>. Otherwise, returns `nil` and sets `error` to
 * `PROTransformationErrorMismatchedInput`.
 *
 * @param obj The object to attempt to transform. This value should not be
 * `nil`.
 * @param error If not `NULL`, this is set to any error that occurred if the
 * transformation failed. This is only set if `nil` is returned.
 */
- (id)transform:(id)obj error:(NSError **)error;

@end
