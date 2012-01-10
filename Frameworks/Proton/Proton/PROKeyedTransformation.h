//
//  PROKeyedTransformation.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

/**
 * Describes transformations to be applied atomically to the values associated
 * with different keys of an object.
 */
@interface PROKeyedTransformation : PROTransformation <NSCoding, NSCopying>

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
 * @param valueTransformations A dictionary containing the transformations to
 * apply to any object given to <transform:>, associated with the key of the
 * given object whose value will be transformed. The keys in this dictionary
 * must be strings.
 */
- (id)initWithValueTransformations:(NSDictionary *)valueTransformations;

/**
 * Initializes the receiver to perform the given transformation upon the value
 * associated with the given key.
 *
 * If both `transformation` and `key` are `nil`, the receiver is initialized to
 * pass through all values without modification.
 *
 * @param transformation A <PROTransformation> to apply to the value associated
 * with `key`.
 * @param key The key on the input object containing the value to transform.
 */
- (id)initWithTransformation:(PROTransformation *)transformation forKey:(NSString *)key;

/**
 * Initializes the receiver to perform the given transformation upon the value
 * associated with the given key path.
 *
 * This method will create as many nested keyed transformations as necessary in
 * order to correctly access the given key path.
 *
 * @param transformation A <PROTransformation> to apply to the value associated
 * with `keyPath`.
 * @param keyPath The key path on the input object containing the value to
 * transform.
 *
 * @warning **Important:** Because this will deconstruct the key path and may
 * create additional transformations to match, <valueTransformations> may not
 * contain the given transformation object after initialization.
 */
- (id)initWithTransformation:(PROTransformation *)transformation forKeyPath:(NSString *)keyPath;

/**
 * @name Transformation
 */

/**
 * The transformations performed by the receiver, associated with the keys whose
 * values will be transformed.
 *
 * The keys in this dictionary must be strings.
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
 * 3. For each key in the <valueTransformations> dictionary which does not exist
 * on `obj`, applies the associated transformation to `[NSNull null]`.
 * 4. For each transformation, replaces the value in the dictionary of step
 * 1 with the value returned by step 2 or 3. If `nil` is returned from any
 * transformation, this method immediately returns `nil`.
 * 5. Returns a new instance of `[obj class]` initialized with the final
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
