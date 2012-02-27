//
//  NSManagedObject+CopyingAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 26.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * Extensions to support copying of `NSManagedObject` instances between contexts.
 */
@interface NSManagedObject (CopyingAdditions)

/**
 * Invokes <copyToManagedObjectContext:includingRelationships:> with all of the
 * relationships described on the receiver's `entity`.
 */
- (id)copyToManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * Invokes <copyToManagedObjectContext:includingRelationships:copiedObjects:>
 * with an empty dictionary.
 */
- (id)copyToManagedObjectContext:(NSManagedObjectContext *)context includingRelationships:(NSSet *)relationshipDescriptions;

/**
 * Creates and returns a copy of `self` in the given managed object context,
 * preserving only the given relationships. Returns `nil` if an error occurs.
 *
 * Attributes (i.e., properties that are not relationships) are always copied.
 *
 * @param context The context the receiver should be recreated in. This context
 * does not need to use the same persistent store coordinator or parent context
 * as the receiver's `managedObjectContext`.
 * @param relationshipDescriptions A set of `NSRelationshipDescription` objects
 * that describes the relationships that should be preserved in the copy. If
 * this is `nil`, no relationships are copied.
 * @param copiedObjects A dictionary used to avoid creating duplicate objects,
 * keyed by object IDs from the source context, associated with copied objects
 * in `context`. If this is `nil`, objects will not be deduplicated.
 *
 * @warning **Important:** The created copy will include any unsaved changes on
 * the receiver.
 */
- (id)copyToManagedObjectContext:(NSManagedObjectContext *)context includingRelationships:(NSSet *)relationshipDescriptions copiedObjects:(NSMutableDictionary *)copiedObjects;

@end
