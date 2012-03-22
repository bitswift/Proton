//
//  NSManagedObject+CopyingAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 26.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSManagedObject+CopyingAdditions.h"
#import "EXTSafeCategory.h"
#import "EXTScope.h"
#import "NSOrderedSet+HigherOrderAdditions.h"
#import "NSSet+HigherOrderAdditions.h"
#import "PROAssert.h"

@safecategory (NSManagedObject, CopyingAdditions)

- (id)copyToManagedObjectContext:(NSManagedObjectContext *)context; {
    NSEntityDescription *entity = self.entity;
    if (entity.relationshipsByName.count) {
        NSSet *relationships = [NSSet setWithArray:entity.relationshipsByName.allValues];
        return [self copyToManagedObjectContext:context includingRelationships:relationships];
    } else {
        return [self copyToManagedObjectContext:context includingRelationships:nil];
    }
}

- (id)copyToManagedObjectContext:(NSManagedObjectContext *)context includingRelationships:(NSSet *)relationshipDescriptions; {
    NSMutableDictionary *copiedObjects = [NSMutableDictionary dictionary];
    return [self copyToManagedObjectContext:context includingRelationships:relationshipDescriptions copiedObjects:copiedObjects];
}

- (id)copyToManagedObjectContext:(NSManagedObjectContext *)context includingRelationships:(NSSet *)relationshipDescriptions copiedObjects:(NSMutableDictionary *)copiedObjects; {
    NSParameterAssert(context != nil);

    NSManagedObject *copiedObject = [copiedObjects objectForKey:self.objectID];
    if (copiedObject) {
        // this object has already been copied -- don't duplicate it
        return copiedObject;
    }

    NSString *entityName = self.entity.name;
    NSEntityDescription *destinationEntity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    if (!destinationEntity)
        return nil;

    copiedObject = [[[self class] alloc] initWithEntity:destinationEntity insertIntoManagedObjectContext:context];
    if (!copiedObject)
        return nil;

    [copiedObjects setObject:copiedObject forKey:self.objectID];

    [self.entity.propertiesByName enumerateKeysAndObjectsUsingBlock:^(NSString *key, id property, BOOL *stop){
        if ([property isKindOfClass:[NSRelationshipDescription class]]) {
            if (![relationshipDescriptions containsObject:property])
                return;

            id (^mappingBlock)(id) = ^(NSManagedObject *object){
                NSMutableSet *relationships = nil;
                if (object.entity.relationshipsByName.count) {
                    relationships = [NSMutableSet setWithArray:object.entity.relationshipsByName.allValues];
                }

                NSManagedObject *newObject = [object copyToManagedObjectContext:context includingRelationships:relationships copiedObjects:copiedObjects];
                PROAssert(newObject, @"Could not copy %@ in relationship %@ to new context %@", object, property, context);
                
                return newObject;
            };

            id newValue;

            if ([property isToMany]) {
                newValue = [[self valueForKey:key] mapUsingBlock:mappingBlock];
            } else {
                id value = [self valueForKey:key];
                newValue = value ? mappingBlock(value) : nil;
            }

            [copiedObject setValue:newValue forKey:key];
        } else if ([property isKindOfClass:[NSAttributeDescription class]]) {
            [copiedObject setValue:[self valueForKey:key] forKey:key];
        }
    }];

    return copiedObject;
}

@end
