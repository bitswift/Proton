//
//  PROBinding.h
//  Proton
//
//  Created by Justin Spahr-Summers on 31.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A generic data binding, based on key-value coding and key-value observing.
 *
 * `PROBinding` is conceptually similar to the functionality provided by Cocoa
 * Bindings on Mac OS X, but with the following enhancements:
 *
 *  - `PROBinding` is cross-platform.
 *  - `PROBinding` is easily extended by subclassing.
 *  - Bindings work fully and automatically for any KVO-compliant property.
 *  - With some minor work (such as attaching control actions), bindings can
 *  work for any KVC-compliant property as well.
 *  - Views need no direct knowledge of bindings.
 *
 * Bindings should always be created on the main thread, and will always trigger
 * on the main thread (even if the change occurred on another).
 */
@interface PROBinding : NSObject

/**
 * @name Initialization
 */

/**
 * Creates a binding between two objects, automatically retaining it for the
 * lifetime of the `owner`.
 *
 * As part of initialization, this will invoke <boundObjectChanged:>, to
 * immediately set the value at <ownerKeyPath> to the value at <boundKeyPath>.
 *
 * Because the binding is automatically retained, the object returned from this
 * method does not have to be saved, unless it will need to be explicitly
 * unbound later.
 *
 * @param ownerKeyPath The key path to bind to on the `owner`. This key path
 * must be KVC-compliant.
 * @param owner The object which uses the value of the `boundObject`. The object
 * returned by this method will be automatically retained by the owner.
 * @param boundKeyPath The key path to bind to on the `boundObject`. This key
 * path must be KVC-compliant.
 * @param boundObject The object providing the value for use by the `owner`.
 * This object will be retained for the lifetime of the binding.
 *
 * @note The memory management semantics for `PROBinding` differ significantly
 * from Cocoa Bindings. In particular, when using this method, the `boundObject`
 * is retained by the binding, and the `owner` retains the binding.
 */
+ (id)bindKeyPath:(NSString *)ownerKeyPath ofObject:(id)owner toKeyPath:(NSString *)boundKeyPath ofObject:(id)boundObject;

/**
 * Initializes a binding between two objects.
 *
 * As part of initialization, this will invoke <boundObjectChanged:>, to
 * immediately set the value at <ownerKeyPath> to the value at <boundKeyPath>.
 *
 * Unlike <bindKeyPath:ofObject:toKeyPath:ofObject:>, this method does not
 * automatically retain the binding. Once the returned object has been released,
 * the specified key paths are automatically unbound.
 *
 * This is the designated initializer for this class.
 *
 * @param owner The object which uses the value of the `boundObject`.
 * @param ownerKeyPath The key path to bind to on the `owner`. This key path
 * must be KVC-compliant.
 * @param boundObject The object providing the value for use by the `owner`.
 * This object will be retained for the lifetime of the binding.
 * @param boundKeyPath The key path to bind to on the `boundObject`. This key
 * path must be KVC-compliant.
 *
 * @note The memory management semantics for `PROBinding` differ significantly
 * from Cocoa Bindings. In particular, when using this method, the `boundObject`
 * is retained by the binding.
 */
- (id)initWithOwner:(id)owner ownerKeyPath:(NSString *)ownerKeyPath boundObject:(id)boundObject boundKeyPath:(NSString *)boundKeyPath;

/**
 * @name Binding Status
 */

/**
 * Whether this binding is currently active.
 *
 * This is `YES` immediately after initialization. It will become `NO` if the
 * <owner> is deallocated or <unbind> is invoked.
 */
@property (nonatomic, getter = isBound, readonly) BOOL bound;

/**
 * Unbinds the receiver, halting all automatic value changes.
 *
 * This will clear out the <owner> and the <boundObject>. If the <owner> is
 * retaining the receiver, this also releases the receiver.
 */
- (void)unbind;

/**
 * @name Bound Objects
 */

/**
 * The object using the value of the <boundObject>.
 *
 * If the binding was created with <bindKeyPath:ofObject:toKeyPath:ofObject:>,
 * this object will retain the binding until deallocated, or until <unbind> is
 * explicitly invoked.
 */
@property (nonatomic, weak, readonly) id owner;

/**
 * The key path that is bound on the <owner>.
 *
 * Whenever the <boundKeyPath> on the <boundObject> changes, this key path is
 * automatically set to the new value.
 *
 * If this key path is KVO-compliant, changes to it will automatically be
 * reflected at the <boundKeyPath>.
 */
@property (nonatomic, copy, readonly) NSString *ownerKeyPath;

/**
 * The object providing the value for use by the <owner>.
 */
@property (nonatomic, strong, readonly) id boundObject;

/**
 * The key path that is bound on the <boundObject>.
 *
 * Whenever the <ownerKeyPath> on the <owner> changes, this key path is
 * automatically set to the new value.
 *
 * If this key path is KVO-compliant, changes to it will automatically be
 * reflected at the <ownerKeyPath>.
 */
@property (nonatomic, copy, readonly) NSString *boundKeyPath;

/**
 * @name Reacting to Changes
 */

/**
 * Updates the <boundKeyPath> of the <boundObject> with the current value of the
 * <ownerKeyPath>.
 *
 * If the <owner> is KVO-compliant for <ownerKeyPath>, this method is
 * automatically invoked whenever a KVO notification is received. This method
 * may also be invoked manually or as a control action.
 *
 * This method may be overridden by subclasses to customize the update logic.
 * Any override of this method should invoke `super` at some point in its
 * implementation.
 *
 * @param sender The object triggering this action. This will be the receiver if
 * invoked in response to a KVO notification.
 */
- (IBAction)ownerChanged:(id)sender;

/**
 * Updates the <ownerKeyPath> of the <owner> with the current value of the
 * <boundObjectKeyPath>.
 *
 * If the <boundObject> is KVO-compliant for <boundObjectKeyPath>, this method is
 * automatically invoked whenever a KVO notification is received. This method
 * may also be invoked manually or as a control action.
 *
 * This method may be overridden by subclasses to customize the update logic.
 * Any override of this method should invoke `super` at some point in its
 * implementation.
 *
 * @param sender The object triggering this action. This will be the receiver if
 * invoked in response to a KVO notification.
 */
- (IBAction)boundObjectChanged:(id)sender;
@end
