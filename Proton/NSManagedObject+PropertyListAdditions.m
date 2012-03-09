//
//  NSManagedObject+PropertyListAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSManagedObject+PropertyListAdditions.h"
#import "EXTSafeCategory.h"
#import "PROAssert.h"

@safecategory (NSManagedObject, PropertyListAdditions)

- (id)initWithPropertyListRepresentation:(NSDictionary *)propertyList insertIntoManagedObjectContext:(NSManagedObjectContext *)context; {
    NSString *entityName = [propertyList objectForKey:@"entityName"];
    if (!PROAssert(entityName, @"No entity name encoded for %@", [self class]))
        return nil;

    NSEntityDescription *entity = [context.persistentStoreCoordinator.managedObjectModel.entitiesByName objectForKey:entityName];
    if (!PROAssert(entity, @"Could not find entity %@", entityName))
        return nil;

    self = [self initWithEntity:entity insertIntoManagedObjectContext:context];
    if (!self)
        return nil;
    
    [propertyList enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop){
        if ([key isEqualToString:@"entityName"])
            return;

        id property = [self.entity.propertiesByName objectForKey:key];
        if (!PROAssert(property, @"Property %@ does not exist on %@", key, self))
            return;

        if ([value isEqual:[NSNull null]])
            value = nil;

        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            if ([property attributeType] == NSTransformableAttributeType) {
                if (PROAssert([value isKindOfClass:[NSData class]], @"Expected an NSData for non-property list value, got: %@", value)) {
                    value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
                }
            }

            [self setValue:value forKey:[property name]];
        } else if ([property isKindOfClass:[NSRelationshipDescription class]] && [property isToMany]) {
            NSArray *array = [propertyList objectForKey:[property name]];
            if (!array.count)
                return;

            id newCollection;
            if ([property isOrdered])
                newCollection = [NSMutableOrderedSet orderedSetWithCapacity:array.count];
            else
                newCollection = [NSMutableSet setWithCapacity:array.count];

            for (id value in array) {
                id object = [[NSManagedObject alloc] initWithPropertyListRepresentation:value insertIntoManagedObjectContext:context];
                if (!object)
                    continue;

                [newCollection addObject:object];
            }

            if ([newCollection count])
                [self setValue:newCollection forKey:[property name]];
        }
    }];

    [self awakeFromSerializedRepresentation];

    return self;
}

- (NSDictionary *)propertyListRepresentation; {
    NSArray *properties = self.entity.properties;

    // include an extra slot for our entity name
    NSMutableDictionary *propertyList = [NSMutableDictionary dictionaryWithCapacity:properties.count + 1];
    [propertyList setObject:self.entity.name forKey:@"entityName"];

    [properties enumerateObjectsUsingBlock:^(id property, NSUInteger index, BOOL *stop){
        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            id value = [self valueForKey:[property name]];
            if (!value)
                return;
            
            if ([property attributeType] == NSTransformableAttributeType) {
                // gotta archive the value first
                value = [NSKeyedArchiver archivedDataWithRootObject:value];
            }

            [propertyList setObject:value forKey:[property name]];
        } else if ([property isKindOfClass:[NSRelationshipDescription class]] && [property isToMany]) {
            id collection = [self valueForKey:[property name]];
            if (![collection count])
                return;

            NSMutableArray *array = [NSMutableArray arrayWithCapacity:[collection count]];
            for (id object in collection) {
                id value = [object propertyListRepresentation];
                if (value)
                    [array addObject:value];
            }

            if (array.count)
                [propertyList setObject:array forKey:[property name]];
        }
    }];

    return propertyList;
}

- (void)awakeFromSerializedRepresentation {
}

@end
