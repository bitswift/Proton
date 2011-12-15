//
//  NSSet+HigherOrderAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSSet+HigherOrderAdditions.h>
#import <Proton/EXTSafeCategory.h>

@safecategory (NSSet, HigherOrderAdditions)

- (id)filterUsingBlock:(BOOL (^)(id obj))block; {
    return [self filterWithOptions:0 usingBlock:block];
}

- (id)filterWithOptions:(NSEnumerationOptions)opts usingBlock:(BOOL (^)(id obj))block; {
    return [self objectsWithOptions:opts passingTest:^(id obj, BOOL *stop){
        return block(obj);
    }];
}

@end
