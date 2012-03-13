//
//  PROModelController.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * Coordinates the editing of an `NSManagedObject`, and allows views and view
 * controllers to bind to its properties.
 *
 * This class provides built-in support for undo grouping, using <groupsByEdit>,
 * and for managed object context operations, using <saveOnCommitEditing> and
 * <rollbackOnDiscardEditing>.
 *
 * This class conforms to the `<NSEditor>` and `<NSEditorRegistration>` informal
 * protocols on Mac OS X.
 *
 * Instances of this class will automatically remove themselves from the default
 * `NSNotificationCenter` upon deallocation.
 *
 * @warning **Important:** This class is not safe to use from multiple threads
 * simultaneously. It can be used on background threads if only accessed from
 * one thread at a time.
 */
@interface PROModelController : NSObject

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to manage the given model object.
 *
 * This is the designated initializer for this class.
 *
 * @param model The object that should become the receiver's <model>.
 */
- (id)initWithModel:(NSManagedObject *)model;

/**
 * @name Model
 */

/**
 * The model object managed by the receiver.
 *
 * This may be redeclared by subclasses to be of a more specific type.
 */
@property (nonatomic, strong, readonly) NSManagedObject *model;

/**
 * @name Undo Management
 */

/**
 * Any `undoManager` from the receiver's <managedObjectContext>.
 *
 * The receiver will automatically remove undo actions targeting itself upon
 * deallocation.
 */
@property (nonatomic, strong, readonly) NSUndoManager *undoManager;

/**
 * Whether the receiver should automatically create an undo group in the
 * <undoManager> when editing begins, and close it when editing ends.
 *
 * The default value for this property is `YES`.
 */
@property (nonatomic, assign) BOOL groupsByEdit;

/**
 * @name Managed Object Context
 */

/**
 * The `managedObjectContext` that the receiver's <model> exists in.
 */
@property (nonatomic, weak, readonly) NSManagedObjectContext *managedObjectContext;

/**
 * Whether the receiver should automatically save the <managedObjectContext>
 * when committing editing.
 *
 * If such a save fails, committing will fail as well.
 *
 * The default value for this property is `YES`.
 */
@property (nonatomic, assign) BOOL saveOnCommitEditing;

/**
 * Whether the receiver should automatically roll back unsaved changes in the
 * <managedObjectContext> when discarding editing.
 *
 * The default value for this property is `YES`.
 */
@property (nonatomic, assign) BOOL rollbackOnDiscardEditing;

/**
 * @name Parent Controller
 */

/**
 * A controller that coordinates the receiver's editing state with other
 * controllers.
 *
 * If this property is set, the parent controller will receive
 * <objectDidBeginEditing:> and <objectDidEndEditing:> messages when the
 * receiver's <editing> state changes.
 */
@property (nonatomic, weak) id parentController;

/**
 * @name Registering Editors
 */

/**
 * Editors that have registered themselves with the receiver and are currently
 * editing.
 *
 * In other words, this set will contain objects that have been passed to
 * <objectDidBeginEditing:>, but that have not yet ended editing.
 *
 * Objects in this set are retained. To avoid cycles, all editors must make sure
 * to unregister themselves.
 *
 * This property is KVO-compliant.
 */
@property (nonatomic, copy, readonly) NSSet *currentEditors;

/**
 * Invoked by objects that want to begin editing the receiver's <model>.
 *
 * @param editor The object that has begun editing. This object will be added to
 * <currentEditors>.
 */
- (void)objectDidBeginEditing:(id)editor;

/**
 * Invoked by objects that have finished editing the receiver's <model>.
 *
 * @param editor The object that has finished editing. This object will be
 * removed from <currentEditors>, if present.
 */
- (void)objectDidEndEditing:(id)editor;

/**
 * @name Editing Status
 */

/**
 * Whether the receiver is currently editing.
 *
 * The setter for this property should not be invoked by other classes; however,
 * subclasses may override the setter to perform additional behaviors.
 *
 * This property is KVO-compliant.
 */
@property (nonatomic, getter = isEditing) BOOL editing;

/**
 * Attempts to commit editing on all <currentEditors>, returning whether the
 * commit was successful.
 *
 * This method invokes <commitEditingAndPerform:> as part of its implementation.
 */
- (BOOL)commitEditing;

/**
 * Attempts to commit editing on all <currentEditors>, returning whether the
 * commit was successful.
 *
 * This method invokes <commitEditingAndPerform:> as part of its implementation.
 *
 * @param error If not `NULL`, and this method returns `NO`, this may be filled
 * in with information about the error that occurred.
 */
- (BOOL)commitEditingAndReturnError:(NSError **)error;

/**
 * Synchronously attempts to commit editing on all <currentEditors>, invoking
 * the given selector on success or failure.
 *
 * This method invokes <commitEditingAndPerform:> as part of its implementation.
 *
 * @param delegate The object upon which to invoke the `didCommitSelector`.
 * @param didCommitSelector A selector to invoke on the `delegate` upon success
 * or failure. This selector should match the following signature:
 * `- (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo`.
 * @param contextInfo An opaque pointer to pass to the `delegate` when invoking
 * the `didCommitSelector`.
 */
- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo;

/**
 * Synchronously attempts to commit editing on all <currentEditors>, invoking
 * the given block upon success or failure.
 *
 * If <saveOnCommitEditing> is `YES`, and all <currentEditors> successfully
 * committed, this method will attempt to save the <managedObjectContext>.
 *
 * Upon a successful commit, if <groupsByEdit> is `YES`, any undo group
 * previously opened by the receiver will be closed. If committing is
 * unsuccessful, some editors may remain in an editing state until a successful
 * commit is performed, or until <discardEditing> is invoked.
 *
 * Subclasses only need to override this method in order to customize the
 * behavior of committing an edit.
 *
 * @param block A block to invoke when the receiver has finished committing its
 * changes.
 */
- (void)commitEditingAndPerform:(void (^)(BOOL commitSuccessful, NSError *error))block;

/**
 * Invokes `discardEditing` on all <currentEditors>.
 *
 * The default implementation of this method does the following:
 *
 *  - If <groupsByEdit> is `YES`, any open undo group is closed and then
 *  discarded.
 *  - If <rollbackOnDiscardEditing> is `YES`, `rollback` is invoked on the
 *  <managedObjectContext>, thus discarding all unsaved changes.
 */
- (void)discardEditing;

@end
