//
//  NSDictionary+HigherOrderAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSDictionary+HigherOrderAdditions.h>
#import <Proton/EXTSafeCategory.h>

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

@end
