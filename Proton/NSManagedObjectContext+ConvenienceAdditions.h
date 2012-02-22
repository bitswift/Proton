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

@end
