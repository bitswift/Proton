//
//  NSManagedObject+PropertyListAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSManagedObject+PropertyListAdditions.h"
#import "NSArray+HigherOrderAdditions.h"
#import "EXTSafeCategory.h"
#import "PROAssert.h"

static NSString * const PRONSManagedObjectEntityNameKey = @"entityName";

@safecategory (NSManagedObject, PropertyListAdditions)

- (id)initWithPropertyListRepresentation:(NSDictionary *)propertyList insertIntoManagedObjectContext:(NSManagedObjectContext *)context; {
    NSString *entityName = [propertyList objectForKey:PRONSManagedObjectEntityNameKey];
    if (!PROAssert(entityName, @"No entity name encoded for %@", [self class]))
        return nil;

    // See if there is a subclass corresponding to the entity name
    // and init there, so we can override this method
    Class subclass = NSClassFromString(entityName);
    if (subclass && [subclass isSubclassOfClass:self.class] && ![self isMemberOfClass:subclass]) {
        return [[subclass alloc] initWithPropertyListRepresentation:propertyList insertIntoManagedObjectContext:context];
    }

    NSEntityDescription *entity = [context.persistentStoreCoordinator.managedObjectModel.entitiesByName objectForKey:entityName];
    if (!PROAssert(entity, @"Could not find entity %@", entityName))
        return nil;

    self = [self initWithEntity:entity insertIntoManagedObjectContext:context];
    if (!self)
        return nil;

    [propertyList enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop){
        if ([key isEqualToString:PRONSManagedObjectEntityNameKey])
            return;

        id property = [self.entity.propertiesByName objectForKey:key];
        if (!PROAssert(property, @"Property %@ does not exist on %@", key, self))
            return;

        id decoded = [[self class] decodePropertyListValue:value forProperty:property insertIntoManagedObjectContext:context];
        if (decoded)
            [self setValue:decoded forKey:key];
    }];

    [self awakeFromSerializedRepresentation];

    return self;
}

- (NSDictionary *)propertyListRepresentation {
    NSArray *properties = [self.entity.properties filterUsingBlock:^ BOOL (id property) {
        return [self shouldEncodePropertyInPropertyListRepresentation:property];
    }];

    return [self propertyListRepresentationIncludingProperties:properties];
}

- (BOOL)shouldEncodePropertyInPropertyListRepresentation:(id)property {
    BOOL isNotToOneRelationshipProperty = ![property isKindOfClass:[NSRelationshipDescription class]] || [property isToMany];
    return [self.entity.properties containsObject:property] && isNotToOneRelationshipProperty;
}

- (NSDictionary *)propertyListRepresentationIncludingProperties:(NSArray *)properties {
    // include an extra slot for our entity name
    NSMutableDictionary *propertyList = [NSMutableDictionary dictionaryWithCapacity:properties.count + 1];
    [propertyList setObject:self.entity.name forKey:PRONSManagedObjectEntityNameKey];

    [properties enumerateObjectsUsingBlock:^(id property, NSUInteger index, BOOL *stop){
        id value = [self propertyListRepresentationForProperty:property];
        if (value)
            [propertyList setObject:value forKey:[property name]];
    }];

    return propertyList;
}

- (id)propertyListRepresentationForProperty:(id)property {
    // Attribute
    if ([property isKindOfClass:[NSAttributeDescription class]]) {
        id value = [self valueForKey:[property name]];
        if (!value)
            return nil;

        if ([property attributeType] == NSTransformableAttributeType) {
            // gotta archive the value first
            value = [NSKeyedArchiver archivedDataWithRootObject:value];
        }

        return value;

    } else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
        // To-many relationship
        if ([property isToMany]) {
            id collection = [self valueForKey:[property name]];
            if (![collection count])
                return nil;

            NSMutableArray *array = [NSMutableArray arrayWithCapacity:[collection count]];
            for (id object in collection) {
                id value = [object propertyListRepresentation];
                if (value)
                    [array addObject:value];
            }

            return array.count ? array : nil;

        // To-one relationship
        } else {
            return [[self valueForKey:[property name]] propertyListRepresentation];
        }
    }

    // Return nil for unsupported property types
    return nil;
}

+ (id)decodePropertyListValue:(id)value forProperty:(id)property insertIntoManagedObjectContext:(NSManagedObjectContext *)context {
    if ([value isEqual:[NSNull null]])
        value = nil;

    // Attribute
    if ([property isKindOfClass:[NSAttributeDescription class]]) {
        if ([property attributeType] == NSTransformableAttributeType) {
            if (PROAssert([value isKindOfClass:[NSData class]], @"Expected an NSData for non-property list value, got: %@", value)) {
                value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
            }
        }

        return value;

    } else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
        // To-many relationship
        if ([property isToMany]) {
            NSArray *array = value;
            if (!array.count)
                return nil;

            id newCollection;
            if ([property isOrdered])
                newCollection = [NSMutableOrderedSet orderedSetWithCapacity:array.count];
            else
                newCollection = [NSMutableSet setWithCapacity:array.count];

            for (id value in array) {
                id object = [[NSManagedObject alloc] initWithPropertyListRepresentation:value insertIntoManagedObjectContext:context];
                if (object)
                    [newCollection addObject:object];
            }

            return [newCollection count] ? newCollection : nil;

        // To-one relationship
        } else {
            return [[NSManagedObject alloc] initWithPropertyListRepresentation:value insertIntoManagedObjectContext:context];
        }
    }

    // Return nil for unsupported property types
    return nil;
}

- (void)awakeFromSerializedRepresentation {
}

@end
