//
//  PROViewModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 01.04.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROBinding;

/**
 * A base class for presentation model objects.
 *
 * To create a subclass:
 *
 *  1. Declare and synthesize any properties desired. Properties should be
 *  `readwrite` (even if exposed as `readonly`) so that their values can be set
 *  with key-value coding.
 *  2. Override `setModel:` to tear down and set up bindings from the <model>.
 *
 * Subclasses do not need to implement `<NSCoding>`, `<NSCopying>`, `-hash`, or
 * `isEqual:`. The implementations of all of these methods are based on the
 * <initWithDictionary:> and <dictionaryValue> behaviors of the class.
 *
 * Upon deallocation, instances of this class will automatically invoke
 * <[NSObject removeAllOwnedObservers]> and <[PROBinding
 * removeAllBindingsFromOwner:>, and automatically unregister from any
 * notifications from the default `NSNotificationCenter`.
 */
@interface PROViewModel : NSObject <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Invokes <initWithModel:> with a `nil` model.
 */
- (id)init;

/**
 * Initializes the properties of the receiver using the keys and values of
 * a dictionary.
 *
 * The keys in the given dictionary must all exist as properties on the
 * receiver.
 *
 * This is the designated initializer for this class. This method can be
 * overridden by subclasses to perform additional work after calling the
 * superclass implementation.
 *
 * @param dictionary The property keys and values to set on the receiver. This
 * argument can be `nil` to use the object's default values.
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

/**
 * Invokes <initWithDictionary:> with a `nil` dictionary, and then sets the
 * receiver's <model> to the given object.
 *
 * @param model An object to use as the receiver's <model>.
 */
- (id)initWithModel:(id)model;

/**
 * @name Model
 */

/**
 * The model object presented by the receiver.
 *
 * Setting this property to a new object will automatically invoke <[PROBinding
 * removeAllBindingsFromOwner:>, thereby removing all of the receiver's bindings
 * before changing model objects.
 *
 * @note This object is not archived with the receiver.
 */
@property (nonatomic, strong) id model;

/**
 * @name Declared Properties
 */

/**
 * Returns an array containing the names of all of the properties on the
 * receiver. The array will be empty if no properties have been declared.
 *
 * This will only include `@property` declarations (i.e., Objective-C 2.0
 * properties), not any methods that look like accessors.
 *
 * @note The <model> property is always excluded from the returned array.
 */
+ (NSArray *)propertyKeys;

/**
 * Returns default values for the receiver's properties. Any keys not present in
 * the dictionary will not be set to a default value.
 *
 * Default values should be set using this method, not <initWithDictionary:>, as
 * the latter is also called when copying or decoding objects.
 *
 * The default implementation of this method returns an empty dictionary.
 */
+ (NSDictionary *)defaultValuesForKeys;

/**
 * Returns a dictionary containing the properties of the receiver.
 *
 * Any properties set to `nil` will be returned in the dictionary as `NSNull`
 * values.
 *
 * If there are no properties, an empty dictionary is returned. This method will
 * never return `nil`.
 */
- (NSDictionary *)dictionaryValue;

/**
 * @name Validating Actions
 */

/**
 * Returns whether the given action selector can be validly invoked, given the
 * current state of the receiver.
 * 
 * The default implementation of this method looks for a method named
 * `-validate<Action>` on the receiver, invoking it and using its result if
 * present. Subclasses that override this method to perform custom logic should
 * invoke `super` at some point in their implementation.
 *
 * If the receiver does not respond to `action`, `NO` is returned.
 *
 * @param action The selector to validate.
 */
- (BOOL)validateAction:(SEL)action;

@end
