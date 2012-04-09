//
//  NSUndoManager+EditingAdditions.h
//  Wireframes
//
//  Created by Josh Vera on 4/5/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSUndoManager` to coordinate edit groupings.
 *
 * Edit groupings are mutually exclusive and fail to open on that basis.
 */
@interface NSUndoManager (EditingAdditions)

/**
 * @name Opening Editing Undo Groupings
 */

/**
 * Invokes <tryEditGroupingWithActionName:> with a `nil` `actionName`.
 */
- (BOOL)tryEditGrouping;

/**
 * Attempts to open an edit grouping named `actionName` and immediately
 * returns whether the attempt was successful.
 *
 * @param actionName If not `nil`, the name of the edit grouping to open.
 */
- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName;

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
 * @param actionName If not `nil`, the name of the edit grouping to open.
 * @param block The block to execute within the edit grouping.
 */
- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName usingBlock:(void (^)(void))block;

/**
 * Closes a previously opened edit grouping.
 */
- (void)endEditGrouping;

@end
