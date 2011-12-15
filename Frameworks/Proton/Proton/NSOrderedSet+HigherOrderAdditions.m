//
//  NSOrderedSet+HigherOrderAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSOrderedSet+HigherOrderAdditions.h>
#import <Proton/EXTSafeCategory.h>

@safecategory (NSOrderedSet, HigherOrderAdditions)

- (id)filterUsingBlock:(BOOL (^)(id obj))block {
    return [self filterWithOptions:0 usingBlock:block];
}

- (id)filterWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL (^)(id obj))block {
    NSArray *objects = [self objectsAtIndexes:
        [self indexesOfObjectsWithOptions:opts passingTest:^(id obj, NSUInteger index, BOOL *stop) {
            return block(obj);
        }]
    ];

    return [NSOrderedSet orderedSetWithArray:objects];
}

@end
