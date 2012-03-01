//
//  NSManagedObject+ConvenienceAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * Conveniences for using `NSManagedObject`.
 */
@interface NSManagedObject (ConvenienceAdditions)

/**
 * @name Creating Managed Objects
 */

/**
 * Creates and returns an instance of the receiver that is automatically
 * inserted into the given managed object context.
 *
 * For this method to work, the name of the receiver's class must match that of
 * an entity in the context's managed object model.
 *
 * @param context The context into which the new object should be inserted. This
 * cannot be `nil`.
 */
+ (id)managedObjectWithContext:(NSManagedObjectContext *)context;

/**
 * @name Fetch Requests
 */

/**
 * Creates and returns a fetch request for retrieving instances of the receiver.
 *
 * For this method to work, the name of the receiver's class must match that of
 * an entity in the managed object context the fetch request will be used with.
 */
+ (NSFetchRequest *)fetchRequest;

/**
 * @name Validation
 */

/**

Executes all of the given validation blocks, returning whether they all succeeded,
and combining any errors into `error`.

Each block should return whether validation succeeds, and can modify `error` to set
its error, like so:

    - (BOOL)validateForInsert:(NSError **)error {
        return [self validateWithError:error usingBlocks:
            ^{
                return [super validateForInsert:error];
            },

            ^{
                return [self validateCustomProperties:error];
            },
            
            nil
        ];
    }

@param error If this is not `NULL`, and this method returns `NO`, this may be
filled in with a validation error composed of the errors set by each block.
@param firstBlock The first validation block. This should not be `nil`.
@param ... A `nil`-terminated list of additional validation blocks.

*/
- (BOOL)validateWithError:(NSError **)error usingBlocks:(BOOL (^)(void))firstBlock, ... NS_REQUIRES_NIL_TERMINATION;

@end
