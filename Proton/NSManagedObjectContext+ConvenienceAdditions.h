//
//  NSManagedObjectContext+ConvenienceAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * Conveniences for using `NSManagedObjectContext`.
 */
@interface NSManagedObjectContext (ConvenienceAdditions)

/**
 * @name Refreshing Objects
 */

/**
 * Updates all of the objects of the receiver to use the latest values from the
 * persistent store.
 *
 * This invokes `refreshObject:mergeChanges:` on all of the receiver's
 * `registeredObjects`.
 *
 * @param mergeChanges Whether each object's changes should be reapplied on top
 * of the latest values from the persistent store. If `NO`, every object is
 * turned back into a fault.
 */
- (void)refreshAllObjectsMergingChanges:(BOOL)mergeChanges;

/**
 * @name Saving
 */

/**
 * Saves changes in the receiver using the given merge policy. Returns whether
 * the save succeeded.
 *
 * This will set the receiver's `mergePolicy` to the given policy before saving,
 * and then restore it to its original value afterward.
 *
 * @param mergePolicy A merge policy that describes how to resolve any conflicts
 * that may occur while saving.
 * @param error If not `NULL`, and this method returns `NO`, this may be set to
 * the error that occurred while saving.
 */
- (BOOL)saveWithMergePolicy:(NSMergePolicy *)mergePolicy error:(NSError **)error;

/**
 * @name Undo Management
 */

/**
 * Synchronously performs a block on the receiver with undo registration disabled.
 *
 * This dispatches a block using `performBlockAndWait:`, in which pending
 * changes are processed and undo registration on any `undoManager` is disabled.
 * When `block` finishes executing, undo registration is re-enabled.
 *
 * @param block A block to perform while undo registration is disabled.
 */
- (void)performBlockWithDisabledUndoAndWait:(void (^)(void))block;

@end
