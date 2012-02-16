//
//  PROTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROTransformation;

/**
 * Type for a block that is invoked to indicate that a new value has been set at
 * a given key path. This block may return `NO` to indicate an invalid
 * application.
 *
 * This type of block should be associated with
 * <PROTransformationNewValueForKeyPathBlockKey>.
 *
 * @param transformation The transformation currently being performed.
 * @param value The value that was set.
 * @param keyPath The key path of the value, relative to the last array. This
 * will be `nil` if the value is at the top level or directly contained in an
 * array.
 */
typedef BOOL (^PROTransformationNewValueForKeyPathBlock)(PROTransformation *transformation, id value, NSString *keyPath);

/**
 * Associated with a <PROTransformationNewValueForKeyPathBlock> in the
 * dictionary passed to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]>.
 */
extern NSString * const PROTransformationNewValueForKeyPathBlockKey;

/**
 * Type for a block that is invoked to get a mutable array value corresponding
 * to the given key path.
 *
 * The array returned from this block will be mutated to match the changes that
 * occurred at `keyPath`.
 *
 * This type of block should be associated with
 * <PROTransformationMutableArrayForKeyPathBlockKey>.
 *
 * @param transformation The transformation currently being performed.
 * @param keyPath A key path containing an array, which had a transformation
 * applied to it. This key path is relative to the last array.
 */
typedef NSMutableArray *(^PROTransformationMutableArrayForKeyPathBlock)(PROTransformation *transformation, NSString *keyPath);

/**
 * Associated with a <PROTransformationMutableArrayForKeyPathBlock> in the
 * dictionary passed to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]>.
 */
extern NSString * const PROTransformationMutableArrayForKeyPathBlockKey;

/**
 * Type for a block that is invoked to "wrap" the value from a given key path in
 * a new object.
 *
 * This method is invoked to create new objects to insert into the mutable array
 * previously returned by a <PROTransformationMutableArrayForKeyPathBlock>.
 *
 * This type of block should be associated with
 * <PROTransformationWrappedValueForKeyPathBlockKey>.
 *
 * @param transformation The transformation currently being performed.
 * @param value The value object to wrap.
 * @param keyPath The key path of the mutable array being inserted into,
 * relative to the array previous from it. This will be `nil` if the mutable
 * array is at the top level or itself directly contained in an array.
 */
typedef id (^PROTransformationWrappedValueForKeyPathBlock)(PROTransformation *transformation, id value, NSString *keyPath);

/**
 * Associated with a <PROTransformationWrappedValueForKeyPathBlock> in the
 * dictionary passed to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]>.
 */
extern NSString * const PROTransformationWrappedValueForKeyPathBlockKey;

/**
 * Type for a block that is invoked to return new blocks for a recursive call to
 * <[PROTransformation updateObject:withTransformationResult:usingBlocks:]>.
 *
 * This block type is basically used to circumvent the limitation of key-value
 * paths not supporting array indexing. The dictionary of blocks returned by
 * _this_ block should be properly adjusted to index into the specified array.
 *
 * This type of block should be associated with
 * <PROTransformationBlocksForIndexAtKeyPathBlockKey>.
 *
 * @param transformation The transformation currently being performed.
 * @param index The index that the blocks returned should be defined relative
 * to.
 * @param keyPath The key path of the array containing `index`, relative to the
 * last array.
 * @param originalBlocks The original dictionary of blocks, including this
 * block.
 */
typedef NSDictionary *(^PROTransformationBlocksForIndexAtKeyPathBlock)(PROTransformation *transformation, NSUInteger index, NSString *keyPath, NSDictionary *originalBlocks);

/**
 * Associated with a <PROTransformationBlocksForIndexAtKeyPathBlock> in the
 * dictionary passed to <[PROTransformation
 * applyBlocks:transformationResult:keyPath:]>.
 */
extern NSString * const PROTransformationBlocksForIndexAtKeyPathBlockKey;

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
 * Invokes <applyBlocks:transformationResult:keyPath:> with a `nil` key path.
 *
 * @param blocks A dictionary of blocks that will be invoked at each step of the
 * transformation.
 * @param result A value previously returned from an invocation of
 * <transform:error:> on the receiver.
 */
- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result;

/**
 * Enumerates through this transformation and all of its <transformations>,
 * applying the given blocks using the result of each transformation. Returns
 * whether the transformation was validly applied.
 *
 * `blocks` should contain at least the following keys:
 *  
 *  - `PROTransformationNewValueForKeyPathBlockKey`
 *  - `PROTransformationMutableArrayForKeyPathBlockKey`
 *  - `PROTransformationWrappedValueForKeyPathBlockKey`
 *  - `PROTransformationBlocksForIndexAtKeyPathBlockKey`
 *
 * This method can be used to recreate the effect of a transformation on
 * another object (such as a controller).
 *
 * @param blocks A dictionary of blocks that will be invoked at each step of the
 * transformation.
 * @param result A value previously returned from an invocation of
 * <transform:error:> on the receiver.
 * @param keyPath The key path, relative to the last array, at which the
 * `result` exists. This is the key path that will be passed into each block.
 * Typically this is provided only during a recursive call -- the first
 * invocation should provide `nil`.
 *
 * @warning **Important:** This method must be implemented by subclasses. You
 * should not call the superclass implementation.
 */
- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath;

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
