//
//  NSUndoManager+EditingAdditions.h
//  Wireframes
//
//  Created by Josh Vera on 4/5/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSUndoManager` to coordinate edits within a window.
 *
 * An edit grouping can be opened to guarantee only one user interface element
 * is edited at one time.
 *
 * Since edit groupings are mutually exclusive, multiple edit groupings
 * cannot be nested.
 */
@interface NSUndoManager (EditingAdditions)

/**
 * @name Opening Editing Undo Groupings
 */

/**
 * Attempts to open an edit grouping, and immediately returns whether the
 * attempt was successful.
 */
- (BOOL)tryEditGrouping __attribute__((warn_unused_result));

/**
 * Invokes <tryEditGroupingWithActionName:usingBlock:> with a `nil`
 * `actionName`.
 */
- (BOOL)tryEditGroupingUsingBlock:(void (^)(void))block;

/**
 * Attempts to open an edit grouping named `actionName`, executes the
 * given block inside it, and closes the group. Returns whether the
 * operation was successful.
 *
 * @param actionName The name of the action associated with undoing the edit grouping.
 * If `actionName` is an empty string, the action name currently associated with the menu
 * command is removed. The receiver's action name remains unchanged if this is `nil`.
 *
 * @param block The block to execute within the edit grouping.
 */
- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName usingBlock:(void (^)(void))block;

/**
 * Closes a previously opened edit grouping.
 *
 * @warning It is invalid to call this method without an open edit grouping.
 */
- (void)endEditGrouping;

@end
