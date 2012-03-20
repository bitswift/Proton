//
//  NSArray+IndexPathAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 19.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions for using index paths with `NSArray`.
 */
@interface NSArray (IndexPathAdditions)

/**
 * @name Retrieving Objects at Index Paths
 */

/**
 * Invokes <objectAtIndexPath:nodeKeyPath:> with a `nil` key path.
 */
- (id)objectAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns the object at the given index path relative to the receiver,
 * traversing between indexes using the given key path.
 *
 * This method proceeds as follows:
 *
 *  1. If the index path is empty, the receiver is returned.
 *  2. The object at the first index from the index path is retrieved.
 *  3. If there are no more indexes in the path, that object is returned.
 *  4. Otherwise, if `nodeKeyPath` is not `nil`, `valueForKeyPath:` is invoked
 *  upon that object, and the result is used instead of the object.
 *  5. If the object (or the result from step 4) is not an array, `nil` is
 *  returned.
 *  6. Repeat from step 2 using the new array and the rest of the index path.
 *
 * @param indexPath The index path from which to return an object. If this path
 * is empty, or any index in this path does not correspond to an array, `nil` is
 * returned.
 * @param nodeKeyPath If not `nil`, each index prior to the last will receive
 * a `valueForKeyPath:` message with this key path, and the result will be used
 * for further indexing.
 */
- (id)objectAtIndexPath:(NSIndexPath *)indexPath nodeKeyPath:(NSString *)nodeKeyPath;

@end
