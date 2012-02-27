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

/**
 * Creates and returns a copy of `self` in the given managed object context,
 * preserving only the given relationships. Returns `nil` if an error occurs.
 *
 * Attributes (i.e., properties that are not relationships) are always copied.
 *
 * @param context The context the receiver should be recreated in. This context
 * does not need to use the same persistent store coordinator or parent context
 * as the `managedObjectContext` of `self`.
 * @param relationshipDescriptions A set of `NSRelationshipDescription` objects
 * that describes the relationships that should be preserved in the copy. If
 * this is `nil`, no relationships are copied.
 * @param objectsCopied A dictionary that keeps track of objects which have
 * already been copied. The dictionary is keyed by object IDs from the source
 * context, with the associated values being the copied objects in the
 * destination context.
 *
 * @warning **Important:** The created copy will include any unsaved changes on
 * `self`.
 */
static NSManagedObject *copyToManagedObjectContext (NSManagedObject *self, NSManagedObjectContext *context, NSSet *relationshipDescriptions, NSMutableDictionary *objectsCopied) {
    NSCParameterAssert(context != nil);
    NSCParameterAssert(objectsCopied != nil);

    NSManagedObject *copiedObject = [objectsCopied objectForKey:self.objectID];
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

    [objectsCopied setObject:copiedObject forKey:self.objectID];

    [self.entity.propertiesByName enumerateKeysAndObjectsUsingBlock:^(NSString *key, id property, BOOL *stop){
        if ([property isKindOfClass:[NSRelationshipDescription class]]) {
            if (![relationshipDescriptions containsObject:property])
                return;

            id newCollection = [[self valueForKey:key] mapUsingBlock:^(NSManagedObject *object){
                NSMutableSet *relationships = nil;
                if (object.entity.relationshipsByName.count) {
                    relationships = [NSMutableSet setWithArray:object.entity.relationshipsByName.allValues];

                    if ([property inverseRelationship]) {
                        // ignore the inverse relationship, since that's what
                        // we're processing right now
                        [relationships removeObject:[property inverseRelationship]];
                    }
                }

                NSManagedObject *newObject = [object copyToManagedObjectContext:context includingRelationships:relationships];
                PROAssert(newObject, @"Could not copy %@ in relationship %@ to new context %@", object, property, context);
                
                return newObject;
            }];

            [copiedObject setValue:newCollection forKey:key];
        } else if ([property isKindOfClass:[NSAttributeDescription class]]) {
            [copiedObject setValue:[self valueForKey:key] forKey:key];
        }
    }];

    return copiedObject;
}

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
    __block NSManagedObject *copiedObject = nil;

    // perform this block on the context's queue, to make sure the insertion of
    // the object graph happens atomically
    [context performBlockAndWait:^{
        copiedObject = copyToManagedObjectContext(self, context, relationshipDescriptions, [NSMutableDictionary dictionary]);
    }];

    return copiedObject;
}

@end
