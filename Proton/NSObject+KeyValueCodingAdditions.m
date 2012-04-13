//
//  NSObject+KeyValueCodingAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 02.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSObject+KeyValueCodingAdditions.h"
#import "EXTNil.h"
#import "EXTSafeCategory.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSSet+HigherOrderAdditions.h"
#import "PROAssert.h"


static id mutableCollectionForKeyPath(id obj, NSString *keyPath) {
    id currentValue = [obj valueForKeyPath:keyPath];
    if ([currentValue isKindOfClass:[NSArray class]])
        return [obj mutableArrayValueForKey:keyPath];
    else if ([currentValue isKindOfClass:[NSSet class]])
        return [obj mutableSetValueForKeyPath:keyPath];
    else if ([currentValue isKindOfClass:[NSOrderedSet class]])
        return [obj mutableOrderedSetValueForKeyPath:keyPath];

    return nil;
}


@safecategory (NSObject, KeyValueCodingAdditions)

- (void)applyKeyValueChangeDictionary:(NSDictionary *)changes toKeyPath:(NSString *)keyPath mappingNewObjectsUsingBlock:(id (^)(id))block;{ 
    NSParameterAssert(changes != nil);
    NSParameterAssert(keyPath != nil);

    /**
     * Applies `block` to the objects in the given collection, and optionally
     * converts the new collection to an `NSSet`. Returns the new collection.
     *
     * If `block` is `nil`, the collection is not mapped.
     */
    id (^mappedCollection)(NSArray *, BOOL) = ^(id collection, BOOL convertToSet){
        id newCollection = collection;

        if (block) {
            if (!PROAssert([collection respondsToSelector:@selector(mapUsingBlock:)], @"Object %@ is not a supported collection", collection))
                return [EXTNil null];

            newCollection = [collection mapUsingBlock:^(id obj){
                id newObj = block(obj);
            
                // make sure objects are never discarded from the collection
                if (!PROAssert(newObj, @"Mapping block returned nil for input object %@", obj))
                    newObj = [EXTNil null];

                return newObj;
            }];
        }

        if (convertToSet && ![newCollection isKindOfClass:[NSSet class]]) {
            return [NSSet setWithArray:newCollection];
        } else {
            return newCollection;
        }
    };

    NSKeyValueChange change = [[changes objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue];
    id newValue = [changes objectForKey:NSKeyValueChangeNewKey];
    id oldValue = [changes objectForKey:NSKeyValueChangeOldKey];
    NSIndexSet *indexes = [changes objectForKey:NSKeyValueChangeIndexesKey];

    switch (change) {
        case NSKeyValueChangeSetting:
            if ([newValue isEqual:[NSNull null]]) {
                // Attempt to empty the collection before trying setValue:forKeyPath:
                id mutableCollection = mutableCollectionForKeyPath(self, keyPath);
                if (mutableCollection) {
                    [mutableCollection removeAllObjects];
                } else {
                    [self setValue:nil forKeyPath:keyPath];
                }
            } else if ([newValue isKindOfClass:[NSSet class]]) {
                [[self mutableSetValueForKeyPath:keyPath] setSet:mappedCollection(newValue, NO)];
            } else if ([newValue isKindOfClass:[NSOrderedSet class]]) {
                NSMutableOrderedSet *orderedSet = [self mutableOrderedSetValueForKeyPath:keyPath];

                [orderedSet removeAllObjects];
                [orderedSet unionOrderedSet:mappedCollection(newValue, NO)];
            } else {
                [[self mutableArrayValueForKeyPath:keyPath] setArray:mappedCollection(newValue, NO)];
            }

            break;

        case NSKeyValueChangeInsertion:
            if (!PROAssert(newValue, @"Inserted objects not provided for an insertion"))
                return;

            if (indexes) {
                [[self mutableArrayValueForKeyPath:keyPath] insertObjects:mappedCollection(newValue, NO) atIndexes:indexes];
            } else {
                [[self mutableSetValueForKeyPath:keyPath] unionSet:mappedCollection(newValue, YES)];
            }

            break;

        case NSKeyValueChangeRemoval:
            if (indexes) {
                [[self mutableArrayValueForKeyPath:keyPath] removeObjectsAtIndexes:indexes];
            } else {
                if (!PROAssert(oldValue, @"Removed objects not provided for an unordered removal"))
                    return;

                [[self mutableSetValueForKeyPath:keyPath] minusSet:[NSSet setWithArray:oldValue]];
            }

            break;

        case NSKeyValueChangeReplacement:
            if (!PROAssert(newValue, @"Inserted objects not provided for an replacement"))
                return;

            if (indexes) {
                [[self mutableArrayValueForKeyPath:keyPath] replaceObjectsAtIndexes:indexes withObjects:mappedCollection(newValue, NO)];
            } else {
                if (!PROAssert(oldValue, @"Removed objects not provided for an unordered replacement"))
                    return;

                NSMutableSet *set = [self mutableSetValueForKeyPath:keyPath];
                [set minusSet:[NSSet setWithArray:oldValue]];
                [set unionSet:mappedCollection(newValue, YES)];
            }

            break;

        default:
            PROAssert(NO, @"Unrecognized KVO change kind %i", (int)change);
    }
}

@end
