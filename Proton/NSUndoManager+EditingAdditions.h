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
 * Attempts to open an edit grouping and immediately returns
 * whether the attempt was successful.
 */
- (BOOL)tryEditGrouping;

/**
 * Attempts to open an edit grouping, executing the given block
 * inside it. Returns whether the operation was successful.
 *
 * @param block The block to execute within the edit grouping.
 */
- (BOOL)tryEditGroupingUsingBlock:(void (^)(void))block;

/**
 * Closes a previously opened edit grouping.
 */
- (void)endEditGrouping;

@end
