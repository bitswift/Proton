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
 * Setting this property to a new object will automatically invoke
 * <removeModelBindings>, thereby removing all of the receiver's bindings before
 * changing model objects.
 *
 * @note This object is not archived with the receiver.
 */
@property (nonatomic, strong) id model;

/**
 * @name Property Values
 */

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
 * @name Bindings
 */

/**
 * Creates a new binding between the receiver and the current <model>.
 *
 * Bindings created in this manner are automatically removed when the receiver
 * deallocates, when a new <model> is set, or when <removeModelBindings> is
 * invoked.
 *
 * If the receiver's <model> is `nil`, this method does nothing.
 *
 * @param ownerKeyPath The key path on the receiver to bind.
 * @param modelKeyPath The key path on the <model> that should be bound.
 * @param setupBlock An optional block that can be used to set up the binding
 * before activating it; for example, this can be used to set <[PROBinding
 * boundValueTransformationBlock]> before the bound value is initially set.
 */
- (void)bindKeyPath:(NSString *)ownerKeyPath toModelKeyPath:(NSString *)modelKeyPath withSetup:(void (^)(PROBinding *))setupBlock;

/**
 * Removes all bindings that were previously set up with
 * <bindKeyPath:toModelKeyPath:withSetup:>.
 */
- (void)removeModelBindings;

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
