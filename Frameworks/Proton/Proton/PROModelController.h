//
//  PROModelController.h
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROModel;
@class PROTransformation;
@class SDQueue;

/**
 * A base class for controller objects that manage <PROModel> references over
 * time.
 */
@interface PROModelController : NSObject

/**
 * @name Initialization
 */

/**
 * Initializes the receiver with a `nil` <model>.
 *
 * This is the designated initializer for this class.
 */
- (id)init;

/**
 * Initializes the receiver to manage the given model object.
 *
 * @param model A model object that the receiver should own.
 */
- (id)initWithModel:(PROModel *)model;

/**
 * @name Model
 */

/**
 * The instance of a <PROModel> subclass managed by the receiver.
 *
 * This property is KVO-compliant.
 *
 * @warning For the purposes of understandability, subclasses may find it useful
 * to alias this property to one that has a more specific type and name. Make
 * sure to implement manual KVO support on any such properties.
 */
@property (copy) id model;

/**
 * @name Synchronization
 */

/**
 * An automatically-created custom dispatch queue, used by the instance to
 * synchronize itself.
 *
 * In particular, this is used by the <model> property and
 * <performTransformation:> method to guarantee thread-safety.
 *
 * This queue is exposed so that subclasses may also use it for any additional
 * synchronization they require.
 */
@property (nonatomic, strong, readonly) SDQueue *dispatchQueue;

/**
 * @name Managing Model Controllers
 */

/**
 * Implemented by subclasses to return the class of <PROModelController> that is
 * stored at a given key path.
 *
 * This method may be queried after <modelControllersKeyPathForModelKeyPath:> to
 * determine the class of controller that should exist in the array at that key
 * path.
 *
 * The returned class should be a subclass of <PROModelController>.
 *
 * @param modelControllersKeyPath A key path, relative to the receiver, returned
 * by <modelControllersKeyPathForModelKeyPath:> indicating where an array of
 * model controllers exists.
 *
 * @warning **Important:** This method **must** be implemented if
 * <modelControllersKeyPathForModelKeyPath:> returns a valid key path. This
 * method must never return `nil`.
 */
- (Class)modelControllerClassAtKeyPath:(NSString *)modelControllersKeyPath;

/**
 * Implemented by subclasses to return the key path, relative to the receiver,
 * where the model controllers for an array of models can be found.
 *
 * If the <model> of the receiving class has one or more arrays of other
 * <PROModel> instances, and the receiver is responsible for managing
 * the associated <PROModelController> instances, this method should return the
 * key path, relative to the receiver, at which an array of those
 * <PROModelController> instances can be found. This information is used to
 * correctly update model controllers when <performTransformation:> affects the
 * corresponding models.
 *
 * This method should return `nil` if no model controllers exist for the models
 * at the given key path.
 *
 * The default implementation returns `nil`.
 *
 * @param modelsKeyPath A key path, relative to the receiver's <model>, where
 * additional <PROModel> instances _may_ be located. Any key path may be
 * specified here -- it is the responsibility of the implementation to validate
 * the object at that path if necessary.
 *
 * @warning **Important:** The key path returned (if not `nil`) must implement
 * the minimum key-value coding methods required for a mutable indexed to-many
 * relationship. The value at the key path must never be `nil` -- use an empty
 * mutable array instead.
 *
 * You **must** implement <modelControllerClassAtKeyPath:> along with this
 * method.
 */
- (NSString *)modelControllersKeyPathForModelKeyPath:(NSString *)modelsKeyPath;

/**
 * @name Performing Transformations
 */

/**
 * Asks the controller to perform the given transformation upon its <model>.
 * Returns whether the transformation succeeded.
 *
 * @param transformation The transformation to attempt to perform.
 */
- (BOOL)performTransformation:(PROTransformation *)transformation;

/**
 * Whether the _current thread_ is performing a transformation (i.e., executing
 * the <performTransformation:> method).
 *
 * This information can be used, for example, to ignore synchronous KVO
 * notifications that are received during the course of a transformation.
 */
@property (assign, readonly, getter = isPerformingTransformation) BOOL performingTransformation;

@end
