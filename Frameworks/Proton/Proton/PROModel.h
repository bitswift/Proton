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
 * created.
 *
 * The sender of this notification will be the original object. The `userInfo`
 * dictionary will contain the following keys:
 *  - <PROModelTransformedObjectKey>
 *  - <PROModelTransformationKey>
 */
extern NSString * const PROModelDidTransformNotification;

/**
 * A notification posted when a <PROModel> should have been transformed, but the
 * transformation failed.
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
 *
 * To create a subclass:
 *
 *  1. Declare and synthesize any properties desired. Properties can be
 *  `readwrite`, in which case they will generate transformations (see below).
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
 * normal usage, but will allow them to be used with <[PROModel performTransformation:]>.
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
 * Generates transformations for any key-value coding or setters that are
 * invoked in the given block.
 *
 * Inside the `transformationBlock`, the use of key-value coding (such as
 * `setValue:forKey:` or `setValuesForKeysWithDictionary:`) or the use of
 * `@property` setters will automatically generate <PROTransformation> objects,
 * as if <transformValue:forKey:> or <transformValuesForKeysWithDictionary:>
 * had been invoked. The original objects will not be modified.
 *
 * For a given object, all invocations of its setters, `setValue:forKey:`,
 * `setValuesForKeysWithDictionary:`, `transformValue:forKey:`, and
 * `transformValuesForKeysWithDictionary:`, will be coalesced into a single
 * transformation. The single transformation will perform all of the
 * aforementioned changes atomically.
 *
 * <PROModelDidTransformNotification> and
 * <PROModelTransformationFailedNotifications> notifications will only be posted
 * from the outermost invocation of this method, after its `transformationBlock`
 * finishes executing, but before the method itself returns.
 *
 * If this method is invoked recursively (i.e., from the block passed in), all
 * recursive invocations will be coalesced into a single transformation per
 * object. Any notifications will be posted only once per object.
 *
 * @param transformationBlock A block containing any number of operations to
 * perform on <PROModel> objects.
 */
+ (void)performTransformation:(void (^)(void))transformationBlock;

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
 *  5. The transformed object (the new instance) is returned.
 *
 * If this method is invoked from within a block passed to <[PROModel
 * performTransformation:]>, the transformation will be coalesced according to
 * the semantics of that method. In such a case, the returned value will be the
 * combined result of all transformations queued up thus far.
 *
 * @param key The key to transform.
 * @param value The new value for `key`.
 */
- (id)transformValue:(id)value forKey:(NSString *)key;

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
 *  5. The transformed object (the new instance) is returned.
 *
 * If this method is invoked from within a block passed to <[PROModel
 * performTransformation:]>, the transformation will be coalesced according to
 * the semantics of that method. In such a case, the returned value will be the
 * combined result of all transformations queued up thus far.
 *
 * @param dictionary The keys to transform, and the new values to set for those
 * keys.
 */
- (id)transformValuesForKeysWithDictionary:(NSDictionary *)dictionary;

@end
