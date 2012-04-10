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
 * Defines how a <PROViewModel> property is encoded into an archive.
 */
typedef enum {
    /**
     * The property should not be encoded.
     */
    PROViewModelEncodingBehaviorNone = 0,

    /**
     * The property should be encoded unconditionally.
     */
    PROViewModelEncodingBehaviorUnconditional,

    /**
     * The property should be encoded only if unconditionally encoded elsewhere.
     */
    PROViewModelEncodingBehaviorConditional
} PROViewModelEncodingBehavior;

/**
 * A base class for presentation model objects.
 *
 * To create a subclass:
 *
 *  1. Declare and synthesize any properties desired.
 *  2. Override `setModel:` to tear down and set up bindings from the <model>.
 *
 * This class automatically implements `<NSCoding>` for itself and its
 * subclasses, using the behavior of <encodingBehaviorForKey:> to determine
 * which properties to archive.
 *
 * The implementations of `-hash` and `-isEqual:` are based on the `readwrite`
 * properties of the class, including the <model> property.
 *
 * Upon deallocation, instances of this class will automatically invoke
 * <[NSObject removeAllOwnedObservers]> and <[PROBinding
 * removeAllBindingsFromOwner:>, and automatically unregister from any
 * notifications from the default `NSNotificationCenter`.
 *
 * This class is not thread-safe.
 */
@interface PROViewModel : NSObject <NSCoding>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver with the <defaultValuesForKeys> of the receiver's
 * class.
 *
 * This is the designated initializer for this class.
 */
- (id)init;

/**
 * Initializes the receiver, setting its <model> to the given object.
 *
 * @param model An object to use as the receiver's <model>.
 */
- (id)initWithModel:(id)model;

/**
 * Whether the receiver is currently being initialized from an archive.
 *
 * This can be used to conditionalize the behavior of properties based on
 * whether they're being set as part of decoding, or explicitly afterward.
 */
@property (nonatomic, getter = isInitializingFromArchive, readonly) BOOL initializingFromArchive;

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
 * Parent View Models
 */

/**
 * The immediate parent view model of the receiver. Returns `nil` if the
 * receiver is the <rootViewModel> for its hierarchy.
 *
 * This property is `nil` by default.
 */
@property (nonatomic, weak) PROViewModel *parentViewModel;

/**
 * The root view model of the receiver.
 *
 * Returns the <[PROViewModel rootViewModel]> of the receiver's <parentViewModel>
 * or the receiver if it has no parent.
 */
@property (nonatomic, weak, readonly) PROViewModel *rootViewModel;

/**
 * @name Declared Properties
 */

/**
 * Returns default values for the receiver's properties. Any keys not present in
 * the dictionary will not be set to a default value.
 *
 * Default values should be provided using this method so that <init> can set
 * them appropriately as part of initialization.
 *
 * The default implementation of this method returns an empty dictionary.
 */
+ (NSDictionary *)defaultValuesForKeys;

/**
 * Returns whether or how the given property key should be encoded into an archive.
 *
 * This is invoked from this class' implementation of `encodeWithCoder:`.
 *
 * The default implementation of this method returns:
 *
 *  - `PROViewModelEncodingBehaviorUnconditional` for any writable properties
 *  (even if only privately writable) that are primitive values or strongly retained.
 *  - `PROViewModelEncodingBehaviorConditional` for any writable properties that
 *  are unretained (i.e., `unsafe_unretained` or `weak`).
 *  - `PROViewModelEncodingBehaviorNone` for all other properties.
 *
 * @param key The key to determine encoding behavior for.
 */
+ (PROViewModelEncodingBehavior)encodingBehaviorForKey:(NSString *)key;

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
