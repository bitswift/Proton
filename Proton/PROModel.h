//
//  PROModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/PROKeyedObject.h>

@class PROKeyedTransformation;

/**
 * An error code in <[PROModel errorDomain]> indicating that an attempt was made
 * to get or set an undefined key.
 *
 * Errors of this type will always contain <PROModelPropertyKeyErrorKey> in the
 * user info dictionary.
 */
extern const NSInteger PROModelErrorUndefinedKey;

/**
 * An error code in <[PROModel errorDomain]> indicating that key-value
 * validation failed.
 *
 * The localized strings for this type of error will be those from the `NSError`
 * returned by the key-value validation method, if any. Any such `NSError`
 * object will be associated with `NSUnderlyingErrorKey` in the user info
 * dictionary.
 *
 * Errors of this type will always contain <PROModelPropertyKeyErrorKey> in the
 * user info dictionary.
 */
extern const NSInteger PROModelErrorValidationFailed;

/**
 * `NSError` user info key that is associated with an `NSString` that represents
 * the property key which caused the error.
 */
extern NSString * const PROModelPropertyKeyErrorKey;

/**
 * A base class for immutable model objects.
 *
 * To create a subclass:
 *
 *  1. Declare and synthesize any properties desired. Properties should be
 *  `readwrite` (even if exposed as `readonly`) so that their values can be set
 *  with key-value coding.
 *  2. If the subclass will hold relationships to other model objects, override
 *  <modelClassesByKeyPath> to indicate where they exist.
 *  3. Implement key-value coding validation methods (per the semantics of
 *  `validateValue:forKey:error:`) as desired. These validation methods will be
 *  automatically invoked by <initWithDictionary:error:>.
 *  4. Override <initWithDictionary:error:> if you need to verify object
 *  consistency after it has been initialized.
 *
 * Subclasses do not need to implement `<NSCoding>`, `<NSCopying>`, `-hash`, or
 * `isEqual:`. The implementations of all of these methods are based on the
 * <initWithDictionary:error:> and <dictionaryValue> behaviors of the class.
 */
@interface PROModel : NSObject <NSCoding, NSCopying, PROKeyedObject>

/**
 * @name Initialization
 */

/**
 * Invokes <initWithDictionary:error:> with a `nil` dictionary and `NULL` error
 * argument.
 */
- (id)init;

/**
 * Initializes the properties of the receiver using the keys and values of
 * a dictionary. Sets `error` and returns `nil` if any error occurs.
 *
 * The keys in the given dictionary must all exist as properties on the
 * receiver. All entries are automatically validated with key-value coding
 * validation methods. If a validation method fails, this method will return
 * `nil`, and `error` will be set to the error returned by the validation
 * method.
 *
 * This method can be overridden by subclasses to perform additional validation
 * on the completed object after calling the superclass implementation.
 *
 * This is the designated initializer for this class.
 *
 * @param dictionary The property keys and values to set on the receiver. This
 * argument can be `nil` to use the object's default values.
 * @param error If this argument is not `NULL`, it will be set to any error that
 * occurs during initialization. This argument will only be set if the method
 * returns `nil`.
 */
- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;

/**
 * @name Reflection
 */

/**
 * Returns an array containing the names of all of the properties on the
 * receiver. The array will be empty if no properties have been declared.
 *
 * This will only include `@property` declarations (i.e., Objective-C 2.0
 * properties), not any methods that look like accessors.
 */
+ (NSArray *)propertyKeys;

/**
 * Returns a dictionary containing the classes of all of the properties on the
 * receiver, keyed by property name.
 *
 * This will only include `@property` declarations that are of object type and
 * explicitly specify a class. Properties of type `id` will not be included in
 * the result.
 *
 * If the receiver has no properties that match these criteria, then an empty
 * dictionary will be returned.
 */
+ (NSDictionary *)propertyClassesByKey;

/**
 * @name Property Values
 */

/**
 * Returns a dictionary containing the default values for any number of
 * properties on the receiver. Any property not included in the dictionary will
 * not be explicitly set on initialization.
 *
 * The default implementation of this method looks for any to-many properties on
 * the receiver (by searching through <propertyClassesByKey> for `NSArray`,
 * `NSDictionary`, `NSOrderedSet`, and `NSSet`) and creates an empty collection
 * value for each one. This enables <PROInsertionTransformation>,
 * <PRORemovalTransformation>, etc. to work even if a model object was not
 * created with an explicit value for a to-many property.
 *
 * If the receiver has no properties that match these criteria, then an empty
 * dictionary will be returned.
 *
 * @warning **Important:** Default values do not go through key-value coding
 * validation.
 */
+ (NSDictionary *)defaultValuesForKeys;

/**
 * Overridden by subclasses to return a dictionary listing any <PROModel>
 * classes that exist at key paths relative to the receiver.
 *
 * The dictionary returned from this method should list every "top level" key
 * path from the receiver that contains a <PROModel> object, or a collection of
 * such objects. The dictionary should _not_ include key paths that refer to
 * properties on any of those top level objects.
 *
 * The default implementation of this method returns an empty dictionary.
 */
+ (NSDictionary *)modelClassesByKeyPath;

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
 * @name Creating Transformations
 */

/**
 * Returns a keyed transformation to transform the value for `key` from its
 * current value on the receiver to `value`.
 *
 * @param key The key to transform.
 * @param value The value for `key` that will be set by the transformation.
 *
 * @warning **Important:** This method does not check to see if the returned
 * transformation would be valid.
 */
- (PROKeyedTransformation *)transformationForKey:(NSString *)key value:(id)value;

/**
 * @name Error Handling
 */

/**
 * Returns the error domain for the receiving class.
 *
 * <PROModel> subclasses may override this if they create custom errors within
 * their own domain.
 */
+ (NSString *)errorDomain;

@end
