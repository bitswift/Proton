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
 * Registers a single undo operation, such that performing an undo will invoke
 * `block`.
 *
 * Blocks added through this method cannot be removed with
 * `removeAllActionsWithTarget:`. If you will need to unregister the block
 * later, use <registerUndoWithTarget:block:> instead.
 *
 * @param block A block representing the actions required to undo the last
 * operation.
 *
 * @warning **Important:** Because of how undo managers work, you cannot embed
 * `NSInvocation`-based undo registration within `block`. Instead, to register
 * blocks alongside or with invocations, register them separately, but put them
 * into the same undo group.
 */
- (void)registerUndoWithBlock:(void (^)(void))block;

/**
 * Registers a single undo operation for a given target, such that performing an
 * undo will invoke `block`.
 *
 * @param target A target with which to associate the block. This is only used
 * to support a later call to `removeAllActionsWithTarget:`.
 * @param block A block representing the actions required to undo the last
 * operation.
 *
 * @warning **Important:** Because of how undo managers work, you cannot embed
 * `NSInvocation`-based undo registration within `block`. Instead, to register
 * blocks alongside or with invocations, register them separately, but put them
 * into the same undo group.
 */
- (void)registerUndoWithTarget:(id)target block:(void (^)(void))block;

/**
 * Registers a single undo operation, such that performing an undo will invoke
 * `undoBlock`, and then register `redoBlock` for redo.
 *
 * Blocks added through this method cannot be removed with
 * `removeAllActionsWithTarget:`. If you will need to unregister the block
 * later, use <registerUndoWithTarget:block:redoBlock:> instead.
 *
 * @param undoBlock A block representing the actions required to undo the last
 * operation.
 * @param redoBlock A block representing the actions required to redo the last
 * operation (i.e., after already having undone it).
 *
 * @warning **Important:** Because of how undo managers work, you cannot embed
 * `NSInvocation`-based undo registration within `block`. Instead, to register
 * blocks alongside or with invocations, register them separately, but put them
 * into the same undo group.
 */
- (void)registerUndoWithBlock:(void (^)(void))undoBlock redoBlock:(void (^)(void))redoBlock;

/**
 * Registers a single undo operation, such that performing an undo will invoke
 * `undoBlock`, and then register `redoBlock` for redo.
 *
 * @param target A target with which to associate the blocks. This is only used
 * to support a later call to `removeAllActionsWithTarget:`.
 * @param undoBlock A block representing the actions required to undo the last
 * operation.
 * @param redoBlock A block representing the actions required to redo the last
 * operation (i.e., after already having undone it).
 *
 * @warning **Important:** Because of how undo managers work, you cannot embed
 * `NSInvocation`-based undo registration within `block`. Instead, to register
 * blocks alongside or with invocations, register them separately, but put them
 * into the same undo group.
 */
- (void)registerUndoWithTarget:(id)target block:(void (^)(void))undoBlock redoBlock:(void (^)(void))redoBlock;

@end
