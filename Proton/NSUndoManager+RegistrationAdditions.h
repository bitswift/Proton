//
//  NSUndoManager+RegistrationAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSUndoManager` to make it easier to register undo actions.
 */
@interface NSUndoManager (RegistrationAdditions)

/**
 * Creates an undo grouping with the given action name, executing the given
 * block inside it. If the block returns `NO`, the undo group is popped and
 * discarded. Returns the return value of `block`.
 *
 * This method is useful to conditionally add an undo group.
 *
 * @param actionName The localized action name for this undo group. If `nil`,
 * the current action name is used.
 * @param block A block to execute while inside the undo grouping.
 */
- (BOOL)addGroupingWithActionName:(NSString *)actionName usingBlock:(BOOL (^)(void))block;

/**
 * Creates an undo grouping with the given action name, executing the given
 * block inside it, and registering `undoBlock` for undoing it. If the block
 * returns `NO`, the undo group is popped and discarded. Returns the return
 * value of `block`.
 *
 * This method is useful to conditionally add an undo group, which uses blocks
 * to provide its undo and redo actions.
 *
 * @param actionName The localized action name for this undo group. If `nil`,
 * the current action name is used.
 * @param block A block to execute while inside the undo grouping. This will
 * also be the redo action.
 * @param undoBlock The block representing the actions required to undo `block`.
 *
 * @warning **Important:** Blocks added through this method cannot be removed
 * with `removeAllActionsWithTarget:`.
 */
- (BOOL)addGroupingWithActionName:(NSString *)actionName performingBlock:(BOOL (^)(void))block undoBlock:(void (^)(void))undoBlock;

/**
 * Registers a single undo operation, such that performing an undo will invoke
 * `block`.
 *
 * If you will need to unregister the block later, use
 * <registerUndoWithTarget:block:> instead.
 *
 * @param block The block representing the actions required to undo the last
 * operation.
 *
 * @warning **Important:** Blocks added through this method cannot be removed
 * with `removeAllActionsWithTarget:`.
 */
- (void)registerUndoWithBlock:(void (^)(void))block;

/**
 * Registers a single undo operation for a given target, such that performing an
 * undo will invoke `block`.
 *
 * @param target A target with which to associate the block. This is only used
 * to support a later call to `removeAllActionsWithTarget:`.
 * @param block The block representing the actions required to undo the last
 * operation.
 */
- (void)registerUndoWithTarget:(id)target block:(void (^)(void))block;

@end
