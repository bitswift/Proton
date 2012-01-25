//
//  NSUndoManager+RegistrationAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSUndoManager` that make registration of undo actions easier.
 */
@interface NSUndoManager (RegistrationAdditions)

/**
 * Begins an undo grouping with the given action name, executing the given
 * `block` inside it.
 *
 * If the block returns `YES`, `undoBlock` is registered for undo. Otherwise,
 * `undoBlock` is run immediately, and the undo group is popped and discarded.
 *
 * This method is useful to conditionally add an undo group.
 *
 * @param actionName The localized action name for this undo group. If `nil`,
 * the current action name is used.
 * @param block A block to execute while inside the undo grouping. This block is
 * also used for redoing.
 * @param undoBlock A block to execute to undo the effect of `block`.
 *
 * @warning **Important:** `block` and `undoBlock` must not contain any
 * invocation-based (i.e., `prepareForInvocationTarget:` or
 * `registerUndoWithTarget:selector:object:`) undo registration.
 */
- (BOOL)registerGroupWithActionName:(NSString *)actionName block:(BOOL (^)(void))block undoBlock:(void (^)(void))undoBlock;

@end
