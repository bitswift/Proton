//
//  NSDictionary+HigherOrderAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSDictionary+HigherOrderAdditions.h>
#import <Proton/EXTSafeCategory.h>
#import <Proton/EXTScope.h>
#import <libkern/OSAtomic.h>

@safecategory (NSDictionary, HigherOrderAdditions)

- (NSDictionary *)filterEntriesUsingBlock:(BOOL (^)(id key, id value))block; {
    return [self filterEntriesWithOptions:0 usingBlock:block];
}

- (NSDictionary *)filterEntriesWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL (^)(id key, id value))block; {
    NSSet *matchingKeys = [self keysOfEntriesWithOptions:opts passingTest:^(id key, id value, BOOL *stop){
        return block(key, value);
    }];

    NSArray *keys = [matchingKeys allObjects];
    NSArray *values = [self objectsForKeys:keys notFoundMarker:[NSNull null]];

    return [NSDictionary dictionaryWithObjects:values forKeys:keys];
}

- (NSDictionary *)mapValuesUsingBlock:(id (^)(id key, id value))block; {
    return [self mapValuesWithOptions:0 usingBlock:block];
}

- (NSDictionary *)mapValuesWithOptions:(NSEnumerationOptions)opts usingBlock:(id (^)(id key, id value))block; {
    NSUInteger originalCount = [self count];
    BOOL concurrent = (opts & NSEnumerationConcurrent);

    // we don't need to retain the individual keys, since the original
    // dictionary is already doing so, and the keys themselves won't change
    __unsafe_unretained volatile id *keys = (__unsafe_unretained id *)calloc(originalCount, sizeof(*keys));
    if (!keys) {
        return nil;
    }

    @onExit {
        free((void *)keys);
    };

    __strong volatile id *values = (__strong id *)calloc(originalCount, sizeof(*values));
    if (!values) {
        return nil;
    }

    // declare these variables way up here so that they can be used in the
    // @onExit block below (avoiding unnecessary iteration)
    volatile int64_t nextIndex = 0;
    volatile int64_t *nextIndexPtr = &nextIndex;

    @onExit {
        // nil out everything in the 'values' array to make sure ARC releases
        // everything appropriately
        NSUInteger actualCount = (NSUInteger)*nextIndexPtr;
        for (NSUInteger i = 0;i < actualCount;++i) {
            values[i] = nil;
        }

        free((void *)values);
    };

    [self enumerateKeysAndObjectsWithOptions:opts usingBlock:^(id key, id value, BOOL *stop){
        id newValue = block(key, value);
        
        if (!newValue) {
            // don't increment the index, go on to the next object
            return;
        }

        // find the index to store into the array -- 'nextIndex' is updated to
        // reflect the total number of elements
        int64_t indexPlusOne = OSAtomicIncrement64Barrier(nextIndexPtr);

        keys[indexPlusOne - 1] = key;
        values[indexPlusOne - 1] = newValue;
    }];

    if (concurrent) {
        // finish all assignments into the 'keys' and 'values' arrays
        OSMemoryBarrier();
    }

    return [NSDictionary dictionaryWithObjects:(id *)values forKeys:(id *)keys count:(NSUInteger)nextIndex];
}

@end
