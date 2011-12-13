//
//  PROKeyedTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * A model object transformable with a <PROKeyedTransformation>.
 */
@protocol PROKeyedObject <NSCoding, NSCopying, NSObject>
@required
/**
 * Initializes the receiver with the keys and values contained in the given
 * dictionary.
 *
 * Invoking <dictionaryValue> later should, if no changes have happened in the
 * meantime, return a dictionary that compares equal to `dict`.
 *
 * @param dict The keys which should be initialized on the receiver, along with
 * their corresponding values.
 */
- (id)initWithDictionary:(NSDictionary *)dict;

/**
 * Returns a dictionary containing the keys and values of the receiver.
 *
 * If the returned dictionary is then passed to <initWithDictionary:> on another
 * instance of the same class, the instantiated object should compare equal to
 * the receiver.
 */
- (NSDictionary *)dictionaryValue;
@end

/**
 * Describes transformations to be applied atomically to the values associated
 * with different keys of an object.
 */
@interface PROKeyedTransformation : PROTransformation <NSCoding, NSCopying>

/**
 * Initialization
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
 * @param valueTransformations A dictionary containing the transformations to
 * apply to any object given to <transform:>, associated with the key of the
 * given object whose value will be transformed.
 */
- (id)initWithValueTransformations:(NSDictionary *)valueTransformations;

/**
 * @name Transformation
 */

/**
 * The transformations performed by the receiver, associated with the keys whose
 * values will be transformed.
 */
@property (nonatomic, copy, readonly) NSDictionary *valueTransformations;

/**
 * Attempts to transform the given object. If the object is not
 * a <PROKeyedObject>, `nil` is returned.
 *
 * This method does the following:
 *
 * 1. Copies the <[PROKeyedObject dictionaryValue]> for `obj`.
 * 2. For each key in the <valueTransformations> dictionary which exists on
 * `obj`, applies the associated transformation to the value associated with
 * that key on `obj`.
 * 3. For each transformation, replaces the value in the dictionary of step
 * 1 with the value returned. If `nil` was returned, the key is removed from
 * the dictionary.
 * 4. Returns a new instance of `[obj class]` initialized with the final
 * dictionary value.
 *
 * If <valueTransformations> is empty, `obj` is passed through without
 * modification.
 *
 * @param obj The object to attempt to transform. This value should not be
 * `nil`, and should be an object conforming to <PROKeyedObject>.
 */
- (id)transform:(id)obj;

@end
