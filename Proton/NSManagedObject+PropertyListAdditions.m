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

    self = [super initWithEntity:entity insertIntoManagedObjectContext:context];
    if (!self)
        return nil;

    [self.entity.properties enumerateObjectsUsingBlock:^(id property, NSUInteger index, BOOL *stop){
        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            id value = [propertyList objectForKey:[property name]];
            if (value)
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
            if (value)
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

@end
