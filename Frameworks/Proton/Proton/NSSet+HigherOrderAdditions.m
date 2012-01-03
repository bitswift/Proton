//
//  NSSet+HigherOrderAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSSet+HigherOrderAdditions.h>
#import <Proton/EXTSafeCategory.h>
#import <Proton/EXTScope.h>
#import <libkern/OSAtomic.h>

@safecategory (NSSet, HigherOrderAdditions)

- (id)filterUsingBlock:(BOOL (^)(id obj))block; {
    return [self filterWithOptions:0 usingBlock:block];
}

- (id)filterWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL (^)(id obj))block; {
    return [self objectsWithOptions:opts passingTest:^(id obj, BOOL *stop){
        return block(obj);
    }];
}

- (id)foldWithValue:(id)startingValue usingBlock:(id (^)(id left, id right))block; {
    __block id value = startingValue;

    [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop){
        value = block(value, obj);
    }];

    return value;
}

- (id)mapUsingBlock:(id (^)(id obj))block; {
    return [self mapWithOptions:0 usingBlock:block];
}

- (id)mapWithOptions:(NSEnumerationOptions)opts usingBlock:(id (^)(id obj))block; {
    NSUInteger originalCount = [self count];
    BOOL concurrent = (opts & NSEnumerationConcurrent);

    __strong volatile id *objects = (__strong id *)calloc(originalCount, sizeof(*objects));
    if (!objects) {
        return nil;
    }

    // declare these variables way up here so that it can be used in the @onExit
    // block below (avoiding unnecessary iteration)
    volatile int64_t nextIndex = 0;
    volatile int64_t *nextIndexPtr = &nextIndex;

    @onExit {
        // nil out everything in the array to make sure ARC releases
        // everything appropriately
        NSUInteger actualCount = (NSUInteger)*nextIndexPtr;
        for (NSUInteger i = 0;i < actualCount;++i) {
            objects[i] = nil;
        }

        free((void *)objects);
    };

    [self enumerateObjectsWithOptions:opts usingBlock:^(id obj, BOOL *stop){
        id result = block(obj);
        
        if (!result) {
            // don't increment the index, go on to the next object
            return;
        }

        // find the index to store into the array -- 'nextIndex' is updated to
        // reflect the total number of elements
        int64_t indexPlusOne = OSAtomicIncrement64Barrier(nextIndexPtr);
        objects[indexPlusOne - 1] = result;
    }];

    if (concurrent) {
        // finish all assignments into the 'objects' array
        OSMemoryBarrier();
    }

    return [NSSet setWithObjects:(id *)objects count:(NSUInteger)nextIndex];
}

- (id)objectPassingTest:(BOOL (^)(id obj, BOOL *stop))predicate; {
    return [self objectWithOptions:0 passingTest:predicate];
}

- (id)objectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id obj, BOOL *stop))predicate; {
    BOOL concurrent = (opts & NSEnumerationConcurrent);

    void * volatile match = NULL;
    void * volatile * matchPtr = &match;

    [self enumerateObjectsWithOptions:opts usingBlock:^(id obj, BOOL *stop){
        BOOL passed = predicate(obj, stop);
        if (!passed)
            return;

        if (concurrent) {
            // we don't use a barrier because it doesn't really matter if we
            // overwrite a previous value, since we can match any object from
            // the set
            OSAtomicCompareAndSwapPtr(*matchPtr, (__bridge void *)obj, matchPtr);
        } else {
            *matchPtr = (__bridge void *)obj;
        }
    }];

    if (concurrent) {
        // make sure that any compare-and-swaps complete
        OSMemoryBarrier();
    }

    // call through -self to remove a bogus analyzer warning about returning
    // a stack-local object (we're not)
    return [(__bridge id)match self];
}

@end
