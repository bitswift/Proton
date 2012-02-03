//
//  PROTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROModelController;
@class PROTransformation;

/**
 * An error code in <[PROTransformation errorDomain]> returned when
 * a transformation applies to one or more indexes that are out of bounds for
 * the input array.
 *
 * Errors of this type will always contain the following user info keys:
 *
 *  - <PROTransformationFailingTransformationsErrorKey>
 *  - <PROTransformationFailingTransformationPathErrorKey>
 */
extern const NSInteger PROTransformationErrorIndexOutOfBounds;

/**
 * An error code in <[PROTransformation errorDomain]> returned when the input to
 * a transformation does not match the input that is expected.
 *
 * Errors of this type will always contain the following user info keys:
 *
 *  - <PROTransformationFailingTransformationsErrorKey>
 *  - <PROTransformationFailingTransformationPathErrorKey>
 */
extern const NSInteger PROTransformationErrorMismatchedInput;

/**
 * An error code in <[PROTransformation errorDomain]> returned when
 * a transformation is passed an input value that is not of the expected type.
 *
 * Errors of this type will always contain the following user info keys:
 *
 *  - <PROTransformationFailingTransformationsErrorKey>
 *  - <PROTransformationFailingTransformationPathErrorKey>
 */
extern const NSInteger PROTransformationErrorUnsupportedInputType;

/**
 * `NSError` user info key that is associated with an `NSArray` containing the
 * "chain" of transformations that failed.
 *
 * The transformation that actually failed (i.e., the leaf) will be at the end
 * of the array, and the first transformation that was attempted (i.e., the one
 * upon which <[PROTransformation transform:error:]> was invoked) will be at the
 * beginning of the array.
 *
 * The associated array is guaranteed to always have at least one object.
 */
extern NSString * const PROTransformationFailingTransformationsErrorKey;

/**
 * `NSError` user info key that is associated with an `NSString` describing the
 * "location" of the specific transformation that failed.
 *
 * The form of this string will appear somewhat like a key path, similar to
 * `model.array[5].key`.
 *
 * This string should not be interpreted programmatically. It is meant for
 * debugging purposes only.
 */
extern NSString * const PROTransformationFailingTransformationPathErrorKey;

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
 * @name Error Handling
 */

/**
 * Returns the error domain for all Proton transformations.
 *
 * You should not use this error domain for custom transformation subclasses.
 */
+ (NSString *)errorDomain;

/**
 * Convenience method to assist subclasses in creating `NSError` objects.
 *
 * @param code The error code.
 * @param format The format for the description of the error.
 * @param ... Any arguments to the format string.
 */
- (NSError *)errorWithCode:(NSInteger)code format:(NSString *)format, ...;

/**
 * Convenience method to assist subclasses in filling in the
 * `PROTransformationFailingTransformationsErrorKey` and
 * `PROTransformationFailingTransformationPathErrorKey` keys of an `NSError`
 * user info dictionary.
 *
 * Given an `NSError` returned from a <PROTransformation>, this will prepend the
 * receiver to the array associated with
 * `PROTransformationFailingTransformationsErrorKey`, and prepend the given path
 * to the string associated with
 * `PROTransformationFailingTransformationPathErrorKey`. Returns `nil` if
 * `error` is `nil`.
 *
 * @param transformationPath The path component(s) to prepend to any existing
 * path.
 * @param error An error to update.
 */
- (NSError *)prependTransformationPath:(NSString *)transformationPath toError:(NSError *)error;

/**
 * @name Transformation
 */

/**
 * Attempts to transform the given object.
 *
 * If no transformation is possible, or the object is invalid, `nil` is
 * returned, and `error` is filled in with the error that occurred. To describe
 * a transformation that should return `nil`, return `EXTNil` or `NSNull`
 * instead.
 *
 * @param obj The object to attempt to transform. This value should not be
 * `nil`.
 * @param error If not `NULL`, and this method returns `nil`, this is set to the
 * error that occurred if the receiver (or one of its <transformations>) failed.
 * **This error should not be presented to the user**, as it is unlikely to
 * contain useful information for them.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
- (id)transform:(id)obj error:(NSError **)error;

/**
 * Attempts to transform the given object in-place. Returns whether the
 * transformation is successful.
 *
 * If an in-place transformation is not possible (for instance, in the case of
 * a <PROUniqueTransformation>), `objPtr` will be set to a new, transformed
 * version of the object.
 *
 * This transforms values in-place "deeply," meaning that keys and indexes in
 * the given object are also expected to be mutable and transformed in-place.
 *
 * @param objPtr A pointer to the object to attempt to transform. This may be
 * set to a new object if the transformation cannot be performed in-place. This
 * pointer should not be `NULL`, nor should the object it points to be `nil`.
 * **If the transformation fails, this object may be left in an invalid state.**
 * @param error If not `NULL`, and this method returns `NO`, this is set to the
 * error that occurred if the receiver (or one of its <transformations>) failed.
 * **This error should not be presented to the user**, as it is unlikely to
 * contain useful information for them.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error;

/**
 * Attempts to update the given key path, relative to the given model
 * controller, with the result of this transformation. Returns whether the
 * update was validly applied.
 *
 * This will update the other model controllers specified with
 * <[PROModelController modelControllersKeyPathForModelKeyPath:]>, if appropriate.
 * Such updates are performed as granularly as possible (e.g., by preferring to
 * update model controllers in place instead of replacing them).
 *
 * @param modelController The model controller to update. This should be the
 * controller responsible for `result`.
 * @param result A value previously returned from an invocation of
 * <transform:error:> on the receiver.
 * @param modelKeyPath The key path, relative to the <model> property of the
 * model controller, at which to set to `result`. If `nil`, the result is
 * assumed to be a new value for <model> itself.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath;

/**
 * @name Compound Transformations
 */

/**
 * If the receiver performs additional or nested transformations, this array
 * will contain all of them. Otherwise, if the receiver's class never performs
 * other transformations, this property should be `nil`.
 *
 * The order of the array is unspecified, unless a subclass imposes a specific
 * order.
 *
 * Classes that do perform other transformations should never return `nil` for
 * this property, even if a specific instance does not have any transformations
 * set up.
 *
 * @warning **Important:** This property must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
@property (nonatomic, copy, readonly) NSArray *transformations;

/**
 * @name Reversing the Transformation
 */

/**
 * The reverse transformation of the receiver.
 *
 * The reverse transformation is defined such that
 *
 *  1. Invoking <transform:error:> on the receiver with an object `obj`
 *  2. Passing the result to the <transform:error:> method of the reverse
 *  transformation
 * 
 * will return an object that compares equal to `obj`.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
@property (nonatomic, strong, readonly) PROTransformation *reverseTransformation;

@end
