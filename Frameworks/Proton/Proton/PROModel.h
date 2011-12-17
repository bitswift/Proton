//
//  PROModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/PROKeyedObject.h>

/**
 * A notification posted when a transformed copy of a <PROModel> was
 * automatically created (such as by calling a setter).
 *
 * The sender of this notification will be the original object. The `userInfo`
 * dictionary will contain the following keys:
 *  - <PROModelTransformedObjectKey>
 *  - <PROModelTransformationKey>
 */
extern NSString * const PROModelDidTransformNotification;

/**
 * A notification posted when a <PROModel> should have been automatically
 * transformed, but the transformation failed.
 *
 * The sender of this notification will be the original object. The `userInfo`
 * dictionary will contain the following keys:
 *  - <PROModelTransformationKey>
 */
extern NSString * const PROModelTransformationFailedNotification;

/**
 * Associated with the object that was returned from the transformation.
 *
 * This will be a key in the `userInfo` dictionary of
 * a <PROModelDidTransformNotification>.
 */
extern NSString * const PROModelTransformedObjectKey;

/**
 * Associated with the transformation that occurred or failed.
 *
 * This will be a key in the `userInfo` dictionary of
 * a <PROModelDidTransformNotification> or
 * a <PROModelTransformationFailedNotification>.
 */
extern NSString * const PROModelTransformationKey;

/**
 * A base class for immutable model objects.
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
 * Triggers a transformation of the receiver that will change the value of the
 * given key.
 *
 * *This method does not mutate the receiver.* Instead:
 *
 *  1. A <PROTransformation> is created that will set `value` for `key` on the
 *  receiver.
 *  2. A modified copy of the receiver is created using the transformation and
 *  <initWithDictionary:>.
 *  3. A `PROModelDidTransformNotification` is posted with the transformation
 *  and the new instance. The original object (the receiver) is left unchanged.
 *  4. Observers of the notification can update any references they have to
 *  point to the latest version of the object, if desired.
 *
 * @param key The key to transform.
 * @param value The new value for `key`.
 */
- (void)setValue:(id)value forKey:(NSString *)key;

/**
 * Triggers a transformation of the receiver that will atomically change the
 * values of the given keys.
 *
 * *This method does not mutate the receiver.* Instead:
 *
 *  1. A <PROTransformation> is created that will set the values for the keys in
 *  `dictionary` on the receiver.
 *  2. A modified copy of the receiver is created using the transformation and
 *  <initWithDictionary:>.
 *  3. A `PROModelDidTransformNotification` is posted with the transformation
 *  and the new instance. The original object (the receiver) is left unchanged.
 *  4. Observers of the notification can update any references they have to
 *  point to the latest version of the object, if desired.
 *
 * @param dictionary The keys to transform, and the new values to set for those
 * keys.
 */
- (void)setValuesForKeysWithDictionary:(NSDictionary *)dictionary;

@end
