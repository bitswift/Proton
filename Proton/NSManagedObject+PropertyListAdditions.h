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
 * If there is a subclass of the receiver's class that matches the entity name
 * encoded in `propertyList`, an new object of that class, initialized with
 * <initWithPropertyListRepresentation:insertIntoManagedObjectContext:>, will
 * be returned.
 *
 * This uses <decodePropertyListValue:forProperty:insertIntoManagedObjectContext:>
 * to decode elements of the property list.
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
 * Calls <propertyListRepresentationIncludingProperties:> with all of the
 * properties from the receiver's entity, excluding to-one relationships.
 */
- (NSDictionary *)propertyListRepresentation;

/**
 * Returns a property list representation of the receiver.
 *
 * The representation returned from this method can be archived or copied as
 * desired (even across processes or machines), and later passed to
 * <initWithPropertyList:insertIntoManagedObjectContext:>, as long as the
 * managed object model remains compatible.
 *
 * This uses <propertyListRepresentationForProperty:> to encode elements of the
 * property list.
 */
- (NSDictionary *)propertyListRepresentationIncludingProperties:(NSArray *)properties;

/**
 * Returns a property list representation of the given property's current value.
 * Calls <propertyListRepresentation> to encode managed objects reached through
 * relationships.
 *
 * Returns `nil` if encoding fails or the property is not supported for encoding.
 * Specifically, fetched properties are not supported.
 *
 * @param property The description of the property to encode.
 */
- (id)propertyListRepresentationForProperty:(NSPropertyDescription *)property;

/**
 * Decodes a value encoded with <propertyListRepresentationForProperty:>. If
 * managed objects are returned, they exist within `context`.
 *
 * @param value The encoded value.
 * @param property The description of a property for which `value` is suitable.
 * @param context The managed object context into which decoded objects should
 * be inserted.
 */
+ (id)decodePropertyListValue:(id)value forProperty:(NSPropertyDescription *)property insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @name Managing Life Cycle and Change Events
 */

/**
 * Invoked automatically when the receiver is initialized with a serialized
 * representation.
 *
 * You typically use this method to initialize special default property values.
 *
 * This is invoked by <initWithPropertyListRepresentation:insertIntoManagedObjectContext:>
 * after any to-many relationships have been decoded.
 */
- (void)awakeFromSerializedRepresentation;

@end
