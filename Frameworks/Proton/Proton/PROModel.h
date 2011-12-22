//
//  PROModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/PROKeyedObject.h>

@class PROKeyedTransformation;

/**
 * A base class for immutable model objects.
 *
 * To create a subclass:
 *
 *  1. Declare and synthesize any properties desired. Properties should be
 *  `readwrite` (even if exposed as `readonly`) so that their values can be set
 *  with key-value coding.
 *  2. Implement key-value coding validation methods
 *  (per the semantics of `validateValue:forKey:error:`) as desired. These
 *  validation methods will be automatically invoked by <initWithDictionary:>.
 *  3. Override <initWithDictionary:> if you need to verify object consistency
 *  after it has been initialized.
 *
 * Subclasses do not need to implement `<NSCoding>`, `<NSCopying>`, `-hash`, or
 * `isEqual:`. The implementations of all of these methods are based on the
 * <initWithDictionary:> and <dictionaryValue> behaviors of the class.
 *
 * @warning **Important:** Subclasses of this class are expected to be
 * immutable. To preserve the contract of immutability, but still allow
 * convenient usage, `PROModel` will disable any `@property` setters outside of
 * <initWithDictionary:>.
 */
@interface PROModel : NSObject <NSCoding, NSCopying, PROKeyedObject>

/**
 * @name Initialization
 */

/**
 * Invokes <initWithDictionary:> with a `nil` dictionary.
 */
- (id)init;

/**
 * Initializes the properties of the receiver using the keys and values of
 * a dictionary.
 *
 * The keys in the given dictionary must all exist as properties on the
 * receiver. All entries are automatically validated with key-value coding
 * validation methods.
 *
 * This method can be overridden by subclasses to perform additional validation
 * on the completed object after calling the superclass implementation.
 *
 * This is the designated initializer for this class.
 *
 * @param dictionary The property keys and values to set on the receiver. This
 * argument can be `nil`.
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

/**
 * @name Reflection
 */

/**
 * Returns an array containing the names of all of the properties on the
 * receiver's class, or `nil` if no properties have been declared.
 *
 * This will only include `@property` declarations (i.e., Objective-C 2.0
 * properties), not any methods that look like accessors.
 */
+ (NSArray *)propertyKeys;

/**
 * @name Reading Properties
 */

/**
 * Returns an immutable dictionary containing the properties of the receiver.
 *
 * Any properties set to `nil` will be returned in the dictionary as `NSNull`
 * values.
 *
 * If there are no properties, an empty dictionary is returned. This method will
 * never return `nil`.
 */
- (NSDictionary *)dictionaryValue;

/**
 * @name Transforming Properties
 */

/**
 * Returns a copy of the receiver which has the given key set to the given
 * value.
 *
 * *This method does not mutate the receiver.*
 *
 * @param key The key to transform.
 * @param value The new value for `key`.
 */
- (id)transformValueForKey:(NSString *)key toValue:(id)value;

/**
 * Returns a copy of the receiver which has the given keys set to the given
 * values.
 *
 * *This method does not mutate the receiver.*
 *
 * @param dictionary The keys to transform, and the new values to set for those
 * keys.
 */
- (id)transformValuesForKeysWithDictionary:(NSDictionary *)dictionary;

/**
 * Returns a keyed transformation which will transform the value for `key` from
 * its current value on the receiver to `value`. Returns `nil` if the transformation
 * would not be valid.
 *
 * @param key The key to transform. The returned transformation will only be
 * valid for the current value of this key.
 * @param value The value for `key` that will be set by the transformation.
 */
- (PROKeyedTransformation *)transformationForKey:(NSString *)key value:(id)value;

/**
 * Returns a keyed transformation which will transform the values for the given
 * keys from their current values on the receiver. Returns `nil` if the
 * transformation would not be valid.
 *
 * This will retrieve the current value on the receiver of every key in
 * `dictionary` and create a transformation for each one to convert it to the
 * value in the dictionary.
 *
 * @param dictionary The keys to transform, along with the new values to set.
 */
- (PROKeyedTransformation *)transformationForKeysWithDictionary:(NSDictionary *)dictionary;

@end
