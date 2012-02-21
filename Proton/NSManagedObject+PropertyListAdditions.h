//
//  NSManagedObject+PropertyListAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 21.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * Adds support for converting `NSManagedObject` instances to and from
 * a property list representation.
 */
@interface NSManagedObject (PropertyListAdditions)

/**
 * @name Initialization
 */

/**
 * Initializes a managed object from the given property list, and inserts it
 * into the given managed object context.
 *
 * @param propertyList A dictionary previously returned from the
 * <propertyListRepresentation> method.
 * @param context The managed object context into which the receiver should be
 * inserted. This should not be `nil`.
 */
- (id)initWithPropertyListRepresentation:(NSDictionary *)propertyList insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @name Property List Representation
 */

/**
 * Returns a property list representation of the receiver.
 *
 * The default implementation of this method will encode all of the attributes
 * on the receiver, and recursively encode any to-many relationships on the
 * receiver. To-one relationships will _not_ be encoded.
 *
 * The representation returned from this method can be archived or copied as
 * desired (even across processes or machines), and later passed to
 * <initWithPropertyList:insertIntoManagedObjectContext:>, as long as the
 * managed object model remains compatible.
 */
- (NSDictionary *)propertyListRepresentation;

@end
