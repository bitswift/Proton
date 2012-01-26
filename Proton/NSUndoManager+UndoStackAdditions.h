//
//  NSUndoManager+UndoStackAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSUndoManager` that extend the functionality of the undo and
 * redo stacks.
 */
@interface NSUndoManager (UndoStackAdditions)

/**
 * Undoes the last thing on the stack without adding it to the redo stack.
 */
- (void)undoNestedGroupingWithoutRegisteringRedo;

@end
