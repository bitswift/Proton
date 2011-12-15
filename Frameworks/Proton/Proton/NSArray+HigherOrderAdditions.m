//
//  NSArray+HigherOrderAdditions.m
//  Proton
//
//  Created by Josh Vera on 12/7/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/EXTSafeCategory.h>

@safecategory (NSArray, HigherOrderAdditions)

- (id)filterUsingBlock:(BOOL(^)(id obj))block {
    return [self filterWithOptions:0 usingBlock:block];
}

- (id)filterWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL(^)(id obj))block {
    return [self objectsAtIndexes:
        [self indexesOfObjectsWithOptions:opts passingTest:^(id obj, NSUInteger idx, BOOL *stop) {
            return block(obj);
        }]
    ];
}
@end
