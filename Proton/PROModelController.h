//
//  PROModelController.h
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/PROTransformer.h>

@class PROModel;
@class PROTransformation;
@class SDQueue;

/**
 * A base class for controller objects that manage <PROModel> references over
 * time.
 */
@interface PROModelController : NSObject <PROTransformer>

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
 * Implemented by subclasses to return a dictionary indicating the classes of
 * model controllers managed on the receiver.
 *
 * The dictionary should have a single `Class` object (which must be a subclass
 * of <PROModelController>) for each key at which a model controller exists on
 * the receiver. The keys in the returned dictionary should contain all of the
 * values returned from <modelControllerKeysByModelKeyPath>.
 *
 * This method may be queried after <modelControllerKeysByModelKeyPath> to
 * determine the class of controller that should exist in an array at a given
 * key.
 *
 * @warning **Important:** This method **must** be implemented if
 * <modelControllerKeysByModelKeyPath> returns valid keys.
 */
+ (NSDictionary *)modelControllerClassesByKey;

/**
 * Implemented by subclasses to return a dictionary indicating where model
 * controllers associated with certain models can be found.
 *
 * If the <model> type of the receiving class has one or more arrays of other
 * <PROModel> instances, and the receiver is responsible for managing the
 * associated <PROModelController> instances, this method should return
 * a dictionary containing:
 *
 *  - Keys, which are the key paths to the arrays of other <PROModel> instances,
 *  relative to the <model> object.
 *  - Values, which are the _keys_ (key paths are not allowed) to the associated
 *  <PROModelController> arrays, relative to the receiver, for each <PROModel>
 *  array.
 *
 * This information is used to correctly update model controllers when
 * <performTransformation:> affects the corresponding models.
 *
 * This method should return `nil` if no model controllers are managed by the
 * receiver.
 *
 * The default implementation returns `nil`.
 *
 * If no instance method is implemented on the receiver with selector `<key>`,
 * `PROModelController` will automatically provide an appropriate
 * implementation, based on the class returned in <modelControllerClassesByKey>.
 * Instances of the receiver will be set up to observe the <model> properties of
 * the created model controllers for changes, and update themselves accordingly.
 *
 * @warning **Important:** You **must** implement <modelControllerClassesByKey>
 * along with this method.
 */
+ (NSDictionary *)modelControllerKeysByModelKeyPath;

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

/**
 * An undo manager with which to register undo and redo operations for
 * transformations, or `nil` to disable undo support for changes on this model
 * controller.
 *
 * If an undo manager is provided, or can be obtained from the <[PROTransformer
 * nextTransformer]>, every successful invocation of <performTransformation:>
 * will automatically register the reverse transformation on the undo stack,
 * such that invoking the `-undo` method will reverse the transformation (if
 * possible).
 *
 * The default value for this property is `nil`.
 *
 * @warning **Important:** This undo manager is used _only_ for
 * <performTransformation:>. Direct changes to the <model> or any model
 * controller properties will not automatically be registered for undo.
 */
@property (nonatomic, strong) NSUndoManager *transformationUndoManager;

@end
