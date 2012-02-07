//
//  PROModelController.h
//  Proton
//
//  Created by Justin Spahr-Summers on 04.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROModel;
@class PROTransformation;
@class PROModelControllerTransformationLogEntry;
@class PROUniqueIdentifier;
@class SDQueue;

/**
 * A base class for controller objects that manage <PROModel> references over
 * time.
 */
@interface PROModelController : NSObject <NSCoding>

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
 * @name Identification
 */

/**
 * A UUID for this model controller, to uniquely identify it across archival and
 * between application launches.
 *
 * This value is automatically created at initialization.
 */
@property (nonatomic, copy, readonly) PROUniqueIdentifier *uniqueIdentifier;

/**
 * @name Synchronization
 */

/**
 * An automatically-created custom dispatch queue, used by the instance to
 * synchronize itself.
 *
 * In particular, this is used by the <model> property and
 * <performTransformation:error:> method to guarantee thread-safety.
 *
 * This queue is exposed so that subclasses may also use it for any additional
 * synchronization they require.
 */
@property (nonatomic, strong, readonly) SDQueue *dispatchQueue;

/**
 * @name Managing Model Controllers
 */

/**
 * The model controller managing this model controller, or `nil` if this model
 * controller is the root of the hierarchy.
 */
@property (nonatomic, weak, readonly) id parentModelController;

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
 * <performTransformation:error:> affects the corresponding models.
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
 * Returns the model controller managed by the receiver which has the given
 * <uniqueIdentifier>, or `nil` if no such model controller exists.
 *
 * @param identifier An identifier which matches the <uniqueIdentifier> of the
 * model controller to return.
 */
- (id)modelControllerWithIdentifier:(PROUniqueIdentifier *)identifier;

/**
 * @name Performing Transformations
 */

/**
 * Asks the controller to perform the given transformation upon its <model>,
 * returning `YES` upon success. If the transformation fails, `NO` is returned
 * and `error` is set to the error that occurred.
 *
 * If the transformation succeeds, it is added to an internal "transformation
 * log" (limited in size to the <transformationLogLimit>), which can be used
 * to replay transformations in reverse and retrieve an older copy of the
 * <model>. See
 * <transformationLogEntryWithModelPointer:willRemoveLogEntryBlock:> for more
 * information.
 *
 * @param transformation The transformation to attempt to perform.
 * @param error If not `NULL`, this is set to any error that occurs. This
 * argument will only be set if the method returns `NO`.
 */
- (BOOL)performTransformation:(PROTransformation *)transformation error:(NSError **)error;

/**
 * Whether the _current thread_ is performing a transformation (i.e., executing
 * the <performTransformation:error:> method).
 *
 * This information can be used, for example, to ignore synchronous KVO
 * notifications that are received during the course of a transformation.
 */
@property (assign, readonly, getter = isPerformingTransformation) BOOL performingTransformation;

/**
 * @name Transformation Log
 */

/**
 * The maximum number of <PROTransformation> instances to include in the
 * transformation log when the receiver is archived, or zero to disable limiting
 * of the archived log.
 *
 * There is intentionally no way to limit a transformation log's in-memory size
 * limit, as doing so would introduce more problems than it would solve.
 *
 * The default value for this property is 50.
 */
@property (assign) NSUInteger archivedTransformationLogLimit;

/**
 * Atomically retrieves the latest transformation log entry and the current
 * version of the <model>.
 *
 * The transformation log entry can later be passed to
 * <modelWithTransformationLogEntry:> or
 * <restoreModelFromTransformationLogEntry:> to retrieve the model as it existed
 * when this method was invoked.
 *
 * @param modelPointer If not `NULL`, this will be set to the current <model>.
 * It is not safe to retrieve the log entry and model in separate steps, as
 * another thread may make a change during that time.
 */
- (PROModelControllerTransformationLogEntry *)transformationLogEntryWithModelPointer:(PROModel **)modelPointer;

/**
 * Returns the version of the <model> that corresponds to the given
 * transformation log entry, or `nil` if the entry no longer exists in the log.
 *
 * The given log entry may no longer exist if the transformation was archived
 * and trimmed to stay within the <archivedTransformationLogLimit>.
 *
 * @param transformationLogEntry An object previously returned from
 * <transformationLogEntryWithModelPointer:>.
 */
- (id)modelWithTransformationLogEntry:(PROModelControllerTransformationLogEntry *)transformationLogEntry;

/**
 * Atomically replaces the receiver's <model> with the version that corresponds
 * to the given log entry. Returns `YES` on success, or `NO` if the entry no
 * longer exists in the log.
 *
 * This method is better suited to undo and redo than
 * <modelWithTransformationLogEntry:>, since this method can rewind or
 * fast-forward the transformation log to the given point without actually
 * modifying the _contents_ of the log (as would happen from setting the
 * receiver's <model>, which adds a new log entry).
 *
 * @param transformationLogEntry An object previously returned from
 * <transformationLogEntryWithModelPointer:>.
 */
- (BOOL)restoreModelFromTransformationLogEntry:(PROModelControllerTransformationLogEntry *)transformationLogEntry;

@end
